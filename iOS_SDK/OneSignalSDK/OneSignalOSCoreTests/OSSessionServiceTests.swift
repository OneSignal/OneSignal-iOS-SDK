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
    var identityModelId: String?
    var onesignalIds: [String: String] = [:]
    var pushSubscriptionId: String?

    var sessionCurrentUser: OSSessionUser {
        OSSessionUser(
            identityModelId: identityModelId,
            onesignalId: identityModelId.flatMap { onesignalIds[$0] },
            pushSubscriptionId: pushSubscriptionId
        )
    }

    func sessionOnesignalId(identityModelId: String) -> String? {
        onesignalIds[identityModelId]
    }
}

final class OSSessionServiceTests: XCTestCase {
    private let flagKey = FeatureFlag.sdkSessionsV2ApiCutover.key
    private var flagsStore: OSFeatureFlagsStore!
    private var featureManager: OSFeatureManager!
    private var monotonicNow: TimeInterval = 1_000
    private var user: FakeUserProvider!

    override func setUp() {
        super.setUp()
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
        flagsStore = OSFeatureFlagsStore()
        featureManager = nil
        monotonicNow = 1_000
        user = FakeUserProvider()
        user.identityModelId = "model-a"
        user.onesignalIds = ["model-a": "onesignal-a"]
        user.pushSubscriptionId = "subscription-a"
    }

    override func tearDown() {
        OSSessionService.reset()
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
        super.tearDown()
    }

    private func makeService() -> OSSessionService {
        let manager = featureManager ?? OSFeatureManager(store: flagsStore)
        featureManager = manager
        return OSSessionService(
            featureManager: { manager },
            monotonicNow: { [unowned self] in self.monotonicNow },
            wallNow: { 5_000 }
        )
    }

    /// The tracker reports focus, then the session starts asynchronously on the main queue.
    private func makeForegroundSession() -> OSSessionService {
        let service = makeService()
        service.onFocus()
        service.startNewSession(userProvider: user)
        return service
    }

    // MARK: - Feature flag

    func testNewSessionUsesSessionsApiWhenFlagIsOn() {
        flagsStore.applyRemoteFlags([flagKey], metadata: nil)

        let service = makeForegroundSession()

        XCTAssertEqual(service.currentRecord?.usesSessionsApi, true)
    }

    func testNewSessionUsesLegacyPathWhenFlagIsOff() {
        let service = makeForegroundSession()

        XCTAssertEqual(service.currentRecord?.usesSessionsApi, false)
    }

    func testSessionsApiChoiceDoesNotChangeMidSession() {
        flagsStore.applyRemoteFlags([flagKey], metadata: nil)
        let service = makeForegroundSession()

        flagsStore.applyRemoteFlags([], metadata: nil)
        service.onUnfocus()
        service.onFocus()

        XCTAssertFalse(featureManager.isEnabled(featureKey: flagKey))
        XCTAssertEqual(service.currentRecord?.usesSessionsApi, true)
    }

    // MARK: - Record

    func testNewSessionPinsIdsAndHasNoServerSessionId() {
        let service = makeForegroundSession()

        let record = service.currentRecord
        XCTAssertEqual(record?.onesignalId, "onesignal-a")
        XCTAssertEqual(record?.subscriptionId, "subscription-a")
        XCTAssertEqual(record?.startTime, 5_000)
        XCTAssertEqual(record?.activeDuration, 0)
        XCTAssertNil(record?.serverSessionId)
    }

    func testEachNewSessionGetsANewSessionId() {
        let service = makeForegroundSession()
        let first = service.currentRecord?.sessionId

        service.startNewSession(userProvider: user)

        XCTAssertNotNil(first)
        XCTAssertNotEqual(service.currentRecord?.sessionId, first)
    }

    func testRecordSurvivesARestart() {
        flagsStore.applyRemoteFlags([flagKey], metadata: nil)
        let service = makeForegroundSession()
        monotonicNow += 10
        service.onUnfocus()
        let saved = service.currentRecord

        let restarted = makeService()

        XCTAssertNotNil(saved)
        XCTAssertEqual(restarted.currentRecord, saved)
    }

    func testIdsAreFilledInAfterARestartBeforeTheUserIsCreated() {
        user.onesignalIds = [:]
        user.pushSubscriptionId = nil
        _ = makeForegroundSession()

        let restarted = makeService()
        restarted.setUserProvider(user)
        user.onesignalIds["model-a"] = "onesignal-a"
        user.pushSubscriptionId = "subscription-a"
        restarted.refreshPinnedIds()

        XCTAssertEqual(restarted.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertEqual(restarted.currentRecord?.subscriptionId, "subscription-a")
    }

    func testClearingTheStoredRecordDropsIt() {
        _ = makeForegroundSession()

        OSSessionService.resetAndClearStoredRecord()

        XCTAssertNil(makeService().currentRecord)
    }

    // MARK: - Pinned IDs

    func testPinnedIdsStayTheSameAfterLogin() {
        let service = makeForegroundSession()

        user.identityModelId = "model-b"
        user.onesignalIds["model-b"] = "onesignal-b"
        user.pushSubscriptionId = "subscription-b"
        service.onUnfocus()

        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertEqual(service.currentRecord?.subscriptionId, "subscription-a")
    }

    func testIdsAreFilledInOnceTheSessionUserIsCreated() {
        user.onesignalIds = [:]
        user.pushSubscriptionId = nil
        let service = makeForegroundSession()
        XCTAssertNil(service.currentRecord?.onesignalId)
        XCTAssertNil(service.currentRecord?.subscriptionId)

        user.onesignalIds["model-a"] = "onesignal-a"
        user.pushSubscriptionId = "subscription-a"

        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertEqual(service.currentRecord?.subscriptionId, "subscription-a")
    }

    func testSubscriptionIdIsNotFilledInAfterLoginToAnotherUser() {
        user.onesignalIds = [:]
        user.pushSubscriptionId = nil
        let service = makeForegroundSession()

        user.identityModelId = "model-b"
        user.onesignalIds = ["model-a": "onesignal-a", "model-b": "onesignal-b"]
        user.pushSubscriptionId = "subscription-b"

        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertNil(service.currentRecord?.subscriptionId)
    }

    func testIdsRefreshedBeforeLoginToAnotherUserStayPinned() {
        user.onesignalIds = [:]
        user.pushSubscriptionId = nil
        let service = makeForegroundSession()

        user.onesignalIds["model-a"] = "onesignal-a"
        user.pushSubscriptionId = "subscription-a"
        service.refreshPinnedIds()
        user.identityModelId = "model-b"
        user.onesignalIds["model-b"] = "onesignal-b"

        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertEqual(service.currentRecord?.subscriptionId, "subscription-a")
    }

    /// Identifying the anonymous user gives the new identity model the same backend user.
    func testSubscriptionIdIsFilledInAfterLoginIdentifiesTheSameUser() {
        user.onesignalIds = [:]
        user.pushSubscriptionId = nil
        let service = makeForegroundSession()

        user.identityModelId = "model-b"
        user.onesignalIds = ["model-a": "onesignal-a", "model-b": "onesignal-a"]
        user.pushSubscriptionId = "subscription-a"

        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
        XCTAssertEqual(service.currentRecord?.subscriptionId, "subscription-a")
    }

    // MARK: - Active duration

    func testActiveDurationAddsEachForegroundInterval() {
        let service = makeForegroundSession()

        monotonicNow += 10
        service.onUnfocus()
        monotonicNow += 100
        service.onFocus()
        monotonicNow += 5
        service.onUnfocus()

        XCTAssertEqual(service.currentRecord?.activeDuration, 15)
    }

    /// Resuming past the new-session threshold: the visit that started the session counts from
    /// focus, not from when the session start ran on the main queue.
    func testNewSessionStartedAfterFocusCountsFromFocus() {
        let service = makeForegroundSession()
        monotonicNow += 10
        service.onUnfocus()
        let previousSessionId = service.currentRecord?.sessionId

        monotonicNow += 60
        service.onFocus()
        monotonicNow += 1
        service.startNewSession(userProvider: user)
        monotonicNow += 20
        service.onUnfocus()

        XCTAssertNotEqual(service.currentRecord?.sessionId, previousSessionId)
        XCTAssertEqual(service.currentRecord?.activeDuration, 21)
    }

    func testSessionStartedInTheBackgroundCountsFromFocus() {
        let service = makeService()
        service.startNewSession(userProvider: user)

        monotonicNow += 100
        service.onFocus()
        monotonicNow += 5
        service.onUnfocus()

        XCTAssertEqual(service.currentRecord?.activeDuration, 5)
    }

    func testUnfocusWithoutFocusAddsNothing() {
        let service = makeForegroundSession()
        monotonicNow += 10
        service.onUnfocus()

        monotonicNow += 50
        service.onUnfocus()

        XCTAssertEqual(service.currentRecord?.activeDuration, 10)
    }

    func testUnfocusInANewProcessDoesNotCountTimeFromThePreviousOne() {
        _ = makeForegroundSession()

        let restarted = makeService()
        monotonicNow += 10
        restarted.onUnfocus()

        XCTAssertEqual(restarted.currentRecord?.activeDuration, 0)
    }
}
