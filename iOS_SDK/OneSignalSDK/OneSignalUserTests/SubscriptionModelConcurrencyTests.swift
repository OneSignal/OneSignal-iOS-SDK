/*
 Modified MIT License

 Copyright 2026 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import XCTest
import OneSignalCoreMocks
@testable import OneSignalOSCore
@testable import OneSignalUser

/**
 An archiver that pauses the first time it encodes the "address" key, so a test can
 mutate the model mid-archive and prove `encode(with:)` uses a consistent snapshot.
 */
private final class PausingKeyedArchiver: NSKeyedArchiver {
    let pausedInEncode = DispatchSemaphore(value: 0)
    let resumeEncode = DispatchSemaphore(value: 0)
    private var hasPaused = false

    override func encode(_ objv: Any?, forKey key: String) {
        if key == "address" && !hasPaused {
            hasPaused = true
            pausedInEncode.signal()
            resumeEncode.wait()
        }
        super.encode(objv, forKey: key)
    }
}

/// Records model change events fired through the change notifier.
private final class ChangeRecorder: OSModelChangedHandler {
    private let lock = NSLock()
    private var changedProperties: [String] = []

    var properties: [String] {
        lock.withLock { changedProperties }
    }

    func onModelUpdated(args: OSModelChangedArgs, hydrating: Bool) {
        lock.withLock { changedProperties.append(args.property) }
    }
}

/**
 Regression tests for GitHub issue #1588: `EXC_BAD_ACCESS` in
 `OSSubscriptionModel.encode(with:)` when the model is archived on a background queue
 (operation repo delta queue, executor request caches) while another thread mutates it.
 */
final class SubscriptionModelConcurrencyTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    /// Uses an email-type model so setters skip push-only side effects (UserDefaults, user manager singleton).
    private func makeEmailModel(address: String = "initial-address", subscriptionId: String? = "initial-subscription-id") -> OSSubscriptionModel {
        return OSSubscriptionModel(
            type: .email,
            address: address,
            subscriptionId: subscriptionId,
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
    }

    func testEncodingWhileMutating_usesConsistentSnapshot() throws {
        /* Setup */
        let subscriptionModel = makeEmailModel()
        let archiver = PausingKeyedArchiver(requiringSecureCoding: false)
        let encodingFinished = expectation(description: "Encoding finished")

        /* When */
        DispatchQueue.global().async {
            archiver.encode(subscriptionModel, forKey: NSKeyedArchiveRootObjectKey)
            archiver.finishEncoding()
            encodingFinished.fulfill()
        }
        XCTAssertEqual(archiver.pausedInEncode.wait(timeout: .now() + 5), .success)

        // Mutate the model while the archiver is paused mid-encode
        subscriptionModel.address = "updated-address"
        subscriptionModel.subscriptionId = "updated-subscription-id"
        archiver.resumeEncode.signal()
        wait(for: [encodingFinished], timeout: 5)

        /* Then - the archive reflects the state at the start of encode, not a torn mix */
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        defer { unarchiver.finishDecoding() }
        let decodedModel = try XCTUnwrap(
            unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? OSSubscriptionModel
        )
        XCTAssertEqual(decodedModel.address, "initial-address")
        XCTAssertEqual(decodedModel.subscriptionId, "initial-subscription-id")
    }

    /**
     Reproduces the production crash setup: one thread archives the model repeatedly while
     others mutate its String-typed properties. Crashed with `EXC_BAD_ACCESS (objc_retain)`
     before the model's stored state was lock-protected. Not a 100% reproduction per run.
     */
    func testConcurrentEncodingAndMutation_doesNotCrash() throws {
        let subscriptionModel = makeEmailModel()

        DispatchQueue.concurrentPerform(iterations: 1_000) { iteration in
            if iteration % 2 == 0 {
                subscriptionModel.address = "address-\(iteration)"
                subscriptionModel.subscriptionId = "subscription-id-\(iteration)"
                subscriptionModel.deviceOs = "os-\(iteration)"
                subscriptionModel.appVersion = "version-\(iteration)"
                subscriptionModel.hydrate(["id": "hydrated-id-\(iteration)"])
            } else {
                let data = try? NSKeyedArchiver.archivedData(withRootObject: subscriptionModel, requiringSecureCoding: false)
                XCTAssertNotNil(data)
                _ = subscriptionModel.jsonRepresentation()
            }
        }
    }

    /**
     Guards the behavior previously implemented via assignment inside `didSet` (which does not
     re-fire the observer): while disabled, setting notificationTypes pins the value to -2
     without firing a change event.
     */
    func testNotificationTypes_whileDisabled_pinsToNegativeTwoWithoutFiringChange() throws {
        /* Setup */
        let changeNotifier = OSEventProducer<OSModelChangedHandler>()
        let pushModel = OSSubscriptionModel(
            type: .push,
            address: nil,
            subscriptionId: nil,
            reachable: false,
            isDisabled: true,
            changeNotifier: changeNotifier
        )
        let recorder = ChangeRecorder()
        changeNotifier.subscribe(recorder, key: "test-recorder")

        /* When */
        pushModel.notificationTypes = 15

        /* Then */
        XCTAssertEqual(pushModel.notificationTypes, -2)
        XCTAssertFalse(recorder.properties.contains("notificationTypes"))
    }
}
