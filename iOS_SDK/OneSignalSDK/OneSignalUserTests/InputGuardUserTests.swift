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

import OneSignalCore
import OneSignalCoreMocks
import OneSignalUserMocks
import XCTest
@testable import OneSignalOSCore
@_spi(OneSignalInternal) @testable import OneSignalUser

final class InputGuardUserTests: XCTestCase {
    private var previousAppId: String?

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        previousAppId = OneSignalIdentifiers.currentAppId
        OneSignalIdentifiers.currentAppId = "b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true
    }

    override func tearDownWithError() throws {
        OneSignalIdentifiers.currentAppId = previousAppId
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
    }

    func testBlankAliasLabelIsNotStoredAndEmptyRemoveLeavesIt() {
        let manager = OneSignalUserManagerImpl.sharedInstance
        manager.user.addAliases(["": "legacy-id"])
        manager.addAlias(label: "", id: "alias-id")
        manager.addAlias(label: "kept-label", id: "real-id")
        manager.addAlias(label: "kept-label", id: "")
        manager.addAliases(["blank-label": "x", "": "y"])

        XCTAssertEqual(manager.user.identityModel.aliases[""], "legacy-id")
        XCTAssertEqual(manager.user.identityModel.aliases["kept-label"], "real-id")
        XCTAssertNil(manager.user.identityModel.aliases["blank-label"])

        manager.removeAlias("")
        manager.removeAliases([""])
        XCTAssertEqual(manager.user.identityModel.aliases[""], "legacy-id")

        manager.addAlias(label: " ", id: "space-id")
        XCTAssertEqual(manager.user.identityModel.aliases[" "], "space-id")
        manager.removeAlias(" ")
        XCTAssertNil(manager.user.identityModel.aliases[" "])
    }

    func testBlankTagKeyRejectsTheBatchAndEmptyRemoveLeavesIt() {
        let manager = OneSignalUserManagerImpl.sharedInstance
        manager.user.addTags(["": "legacy"])
        manager.addTags(["": "nope", "blank-batch": "nope"])
        manager.addTag(key: "empty-value", value: "")

        XCTAssertEqual(manager.getTags()[""], "legacy")
        XCTAssertNil(manager.getTags()["blank-batch"])
        XCTAssertEqual(manager.getTags()["empty-value"], "")

        manager.removeTag("")
        manager.removeTags([""])
        XCTAssertEqual(manager.getTags()[""], "legacy")
        manager.removeTag("empty-value")
        XCTAssertNil(manager.getTags()["empty-value"])
    }

    func testEmptyEmailAndSmsAreNotStored() {
        let manager = OneSignalUserManagerImpl.sharedInstance
        manager.addEmail("")
        XCTAssertNil(manager.subscriptionModelStore.getModel(key: ""))
        manager.addSms("")
        XCTAssertNil(manager.subscriptionModelStore.getModel(key: ""))

        manager.subscriptionModelStore.add(
            id: "",
            model: OSSubscriptionModel(
                type: .email,
                address: "",
                subscriptionId: nil,
                reachable: true,
                isDisabled: false,
                changeNotifier: OSEventProducer()
            ),
            hydrating: false
        )
        manager.removeEmail("")
        XCTAssertNotNil(manager.subscriptionModelStore.getModel(key: ""))
        manager.removeSms("")
        XCTAssertNotNil(manager.subscriptionModelStore.getModel(key: ""))
    }

    func testNullByteIsNotStoredExceptAsAnEmptyTagValue() {
        let manager = OneSignalUserManagerImpl.sharedInstance
        manager.login(externalId: "\u{0000}: 1", token: nil)
        XCTAssertNil(manager.externalId)

        manager.addAlias(label: "nul-id", id: "\u{0000}: 1")
        manager.addAlias(label: "\u{0000}", id: "1")
        XCTAssertNil(manager.user.identityModel.aliases["nul-id"])
        XCTAssertNil(manager.user.identityModel.aliases["\u{0000}"])

        manager.addTag(key: "nul-value", value: "a\u{0000}b")
        XCTAssertEqual(manager.getTags()["nul-value"], "a\u{0000}b")
        manager.addTags(["\u{0000}": "nope", "sibling": "nope"])
        XCTAssertNil(manager.getTags()["sibling"])
        manager.removeTag("nul-value")
    }

    func testBlankEventNameIsNotEnqueued() {
        let manager = OneSignalUserManagerImpl.sharedInstance
        let repo = OneSignalUserManagerImpl.sharedInstance.operationRepo
        manager.trackEvent(name: "kept-event", properties: nil)
        repo.flushAndWait()
        let before = repo.deltaQueue.filter { $0.name == OS_CUSTOM_EVENT_DELTA }.count

        manager.trackEvent(name: "", properties: nil)
        repo.flushAndWait()
        let after = repo.deltaQueue.filter { $0.name == OS_CUSTOM_EVENT_DELTA }.count
        XCTAssertEqual(after, before)
        XCTAssertGreaterThan(before, 0)
    }
}
