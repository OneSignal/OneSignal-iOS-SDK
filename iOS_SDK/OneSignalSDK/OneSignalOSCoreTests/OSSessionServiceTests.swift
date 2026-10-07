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

import Foundation
import OneSignalCore
import OneSignalKMP
@testable import OneSignalOSCore
import XCTest

private final class FakeUserProvider: OSSessionUserProvider {
    var sessionIdentityModelId: String?
    var onesignalIds: [String: String] = [:]
    var sessionPushSubscriptionId: String?

    func sessionOnesignalId(identityModelId: String) -> String? {
        onesignalIds[identityModelId]
    }
}

final class OSSessionServiceTests: XCTestCase {
    private let flagKey = FeatureFlag.sdkSessionsV2ApiCutover.key
    private var flagsStore: OSFeatureFlagsStore!
    private var monotonicNow: TimeInterval = 1_000
    private var user: FakeUserProvider!

    override func setUp() {
        super.setUp()
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
        flagsStore = OSFeatureFlagsStore()
        monotonicNow = 1_000
        user = FakeUserProvider()
        user.sessionIdentityModelId = "model-a"
        user.onesignalIds = ["model-a": "onesignal-a"]
        user.sessionPushSubscriptionId = "subscription-a"
    }

    override func tearDown() {
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
        super.tearDown()
    }

    private func makeService() -> OSSessionService {
        let featureManager = OSFeatureManager(store: flagsStore)
        return OSSessionService(
            featureManager: { featureManager },
            monotonicNow: { [unowned self] in self.monotonicNow },
            wallNow: { 5_000 }
        )
    }

    func testNewSessionUsesSessionsApiWhenFlagIsOn() {
        flagsStore.applyRemoteFlags([flagKey], metadata: nil)
        let service = makeService()

        service.startNewSession(userProvider: user)

        XCTAssertEqual(service.currentRecord?.usesSessionsApi, true)
    }

    func testNewSessionUsesLegacyPathWhenFlagIsOff() {
        let service = makeService()

        service.startNewSession(userProvider: user)

        XCTAssertEqual(service.currentRecord?.usesSessionsApi, false)
    }

    func testSessionsApiChoiceDoesNotChangeMidSession() {
        flagsStore.applyRemoteFlags([flagKey], metadata: nil)
        let service = makeService()
        service.startNewSession(userProvider: user)

        flagsStore.applyRemoteFlags([], metadata: nil)
        service.onUnfocus()
        service.onFocus()

        XCTAssertEqual(service.currentRecord?.usesSessionsApi, true)
    }

    func testNewSessionPinsIdsAndHasNoServerSessionId() {
        let service = makeService()

        service.startNewSession(userProvider: user)

        let record = service.currentRecord
        XCTAssertEqual(record?.onesignalId, "onesignal-a")
        XCTAssertEqual(record?.subscriptionId, "subscription-a")
        XCTAssertEqual(record?.startTime, 5_000)
        XCTAssertEqual(record?.activeDuration, 0)
        XCTAssertNil(record?.serverSessionId)
    }

    func testEachNewSessionGetsANewSessionId() {
        let service = makeService()
        service.startNewSession(userProvider: user)
        let first = service.currentRecord?.sessionId

        service.startNewSession(userProvider: user)

        XCTAssertNotNil(first)
        XCTAssertNotEqual(service.currentRecord?.sessionId, first)
    }

    func testPinnedIdsStayTheSameAfterLogin() {
        let service = makeService()
        service.startNewSession(userProvider: user)

        user.sessionIdentityModelId = "model-b"
        user.onesignalIds["model-b"] = "onesignal-b"
        user.sessionPushSubscriptionId = "subscription-b"
        service.onUnfocus()

        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertEqual(service.currentRecord?.subscriptionId, "subscription-a")
    }

    func testIdsAreFilledInOnceTheSessionUserIsCreated() {
        user.onesignalIds = [:]
        user.sessionPushSubscriptionId = nil
        let service = makeService()
        service.startNewSession(userProvider: user)
        XCTAssertNil(service.currentRecord?.onesignalId)
        XCTAssertNil(service.currentRecord?.subscriptionId)

        user.onesignalIds["model-a"] = "onesignal-a"
        user.sessionPushSubscriptionId = "subscription-a"

        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertEqual(service.currentRecord?.subscriptionId, "subscription-a")
    }

    func testSubscriptionIdIsNotFilledInAfterLoginToAnotherUser() {
        user.onesignalIds = [:]
        user.sessionPushSubscriptionId = nil
        let service = makeService()
        service.startNewSession(userProvider: user)

        user.sessionIdentityModelId = "model-b"
        user.onesignalIds = ["model-a": "onesignal-a", "model-b": "onesignal-b"]
        user.sessionPushSubscriptionId = "subscription-b"

        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertNil(service.currentRecord?.subscriptionId)
    }

    func testActiveDurationAddsEachForegroundInterval() {
        let service = makeService()
        service.startNewSession(userProvider: user)

        monotonicNow += 10
        service.onUnfocus()
        monotonicNow += 100
        service.onFocus()
        monotonicNow += 5
        service.onUnfocus()

        XCTAssertEqual(service.currentRecord?.activeDuration, 15)
    }

    func testUnfocusWithoutFocusAddsNothing() {
        let service = makeService()
        service.startNewSession(userProvider: user)
        monotonicNow += 10
        service.onUnfocus()

        monotonicNow += 50
        service.onUnfocus()

        XCTAssertEqual(service.currentRecord?.activeDuration, 10)
    }

    func testRecordSurvivesARestart() {
        flagsStore.applyRemoteFlags([flagKey], metadata: nil)
        let service = makeService()
        service.startNewSession(userProvider: user)
        monotonicNow += 10
        service.onUnfocus()
        let saved = service.currentRecord

        let restarted = makeService()

        XCTAssertNotNil(saved)
        XCTAssertEqual(restarted.currentRecord, saved)
    }

    func testUnfocusInANewProcessDoesNotCountTimeFromThePreviousOne() {
        let service = makeService()
        service.startNewSession(userProvider: user)

        let restarted = makeService()
        monotonicNow += 10
        restarted.onUnfocus()

        XCTAssertEqual(restarted.currentRecord?.activeDuration, 0)
    }
}
