/*
 Modified MIT License

 Copyright 2025 OneSignal

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

import Foundation
import XCTest
import OneSignalCore
@testable import OneSignalOSCore

/**
 Builds an Operation Repo per test. Clear the cache before constructing one (`init` uncachees);
 seed the cache first when the test starts from a restored queue.
 */
enum OSOperationRepoTestEnvironment {
    static func clearCache() {
        OneSignalUserDefaults.initShared().removeValue(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_USE_IDENTITY_VERIFICATION)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_FEATURE_FLAGS)
    }

    static func seedCachedDeltaQueue(_ deltas: [OSDelta]) {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_OPERATION_REPO_DELTA_QUEUE_KEY, withValue: deltas)
    }

    static func cachedDeltaQueue() -> [OSDelta]? {
        let key = OS_OPERATION_REPO_DELTA_QUEUE_KEY
        return OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: key, defaultValue: []) as? [OSDelta]
    }

    // Pin the poller out of reach: DEBUG uses 100ms and would flush underneath expectations.
    static func makeRepo(jwtConfig: OSUserJwtConfig, featureManager: OSFeatureManager = OSFeatureManager(enabledKeys: [])) -> OSOperationRepo {
        let service = OSIdentityVerificationService(featureManager: featureManager, jwtConfig: jwtConfig)
        let repo = OSOperationRepo(identityVerificationService: service)
        repo.pollIntervalMilliseconds = 60_000
        return repo
    }

    static func makeDelta(name: String, externalId: String?, property: String) -> OSDelta {
        return OSDelta(
            name: name,
            identityModelId: UUID().uuidString,
            externalId: externalId,
            model: OSModel(changeNotifier: OSEventProducer()),
            property: property,
            value: property
        )
    }
}

extension OSOperationRepo {
    /**
     The queue as of right now. Tests poll it while the repo appends on its own queue, so reading
     `deltaQueue` directly is a data race even when only the count is wanted.
     */
    func snapshotDeltaQueue() -> [OSDelta] {
        return dispatchQueue.sync { deltaQueue }
    }
}

/// Records what the Operation Repo hands it, so tests can assert on routing rather than on requests.
final class MockOperationExecutor: OSOperationExecutor {
    let supportedDeltas: [String]
    private(set) var enqueued: [OSDelta] = []
    private(set) var removeOperationsWithoutExternalIdCallCount = 0
    var onProcessDeltaQueue: (() -> Void)?

    init(supportedDeltas: [String]) {
        self.supportedDeltas = supportedDeltas
    }

    func enqueueDelta(_ delta: OSDelta) {
        enqueued.append(delta)
    }

    func cacheDeltaQueue() {}

    func processDeltaQueue(inBackground: Bool) {
        onProcessDeltaQueue?()
    }

    func removeOperationsWithoutExternalId() {
        removeOperationsWithoutExternalIdCallCount += 1
    }
}

extension XCTestCase {
    /// Polls: the repo works on a private queue with no completion to hook.
    func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) {
        let exp = expectation(description: description)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                exp.fulfill()
            }
        }
        let result = XCTWaiter.wait(for: [exp], timeout: timeout)
        timer.invalidate()
        XCTAssertEqual(result, .completed, "Timed out waiting for: \(description)", file: file, line: line)
    }
}
