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
import OneSignalCore
import OneSignalOSCore
import OneSignalOutcomes

private final class FakeUserProvider: OSSessionUserProvider {
    var sessionCurrentUser: OSSessionUser {
        OSSessionUser(identityModelId: nil, onesignalId: nil, pushSubscriptionId: nil)
    }

    func sessionOnesignalId(identityModelId: String) -> String? { nil }
    func sessionHeartbeat(_ record: OSSessionRecord) {}
    func sessionFirstFocused(_ record: OSSessionRecord, directAttributionId: String?) {}
}

private final class RecordingTaskHandler: OSBackgroundTaskHandler {
    private(set) var begunTasks: [String] = []

    func beginBackgroundTask(_ taskIdentifier: String) { begunTasks.append(taskIdentifier) }
    func endBackgroundTask(_ taskIdentifier: String) {}
    func setTaskInvalid(_ taskIdentifier: String) {}
}

final class OneSignalTrackerTests: XCTestCase {
    private let userProvider = FakeUserProvider()
    private let taskHandler = RecordingTaskHandler()
    private var originalTaskHandler: OSBackgroundTaskHandler?

    override func setUp() {
        super.setUp()
        OneSignalTracker.reset()
        OSSessionService.resetAndClearStoredRecord()
        originalTaskHandler = OSBackgroundTaskManager.taskHandler
        OSBackgroundTaskManager.taskHandler = taskHandler
    }

    override func tearDown() {
        OneSignalTracker.reset()
        OSSessionService.resetAndClearStoredRecord()
        UIApplicationOverrider.setCurrentUIApplicationState(.active)
        OSSessionManager.shared().setLastOpenedTime(0)
        NSDateOverrider.reset()
        OSBackgroundTaskManager.taskHandler = originalTaskHandler
        OSFocusTimeProcessorFactory.cancelFocusCall()
        OSFocusTimeProcessorFactory.resetUnsentActiveTime()
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_UNSENT_ACTIVE_TIME)
        super.tearDown()
    }

    func testInitWhileActiveIsTheSessionsFirstFocus() {
        UIApplicationOverrider.setCurrentUIApplicationState(.active)

        OneSignalTracker.onInitWhileActive()
        let start = OSSessionService.shared.startNewSession(userProvider: userProvider)

        XCTAssertNil(start.started.awaitingFocus)
    }

    func testInitAfterAnAppIdChangeWhileActiveIsTheNewSessionsFirstFocus() {
        UIApplicationOverrider.setCurrentUIApplicationState(.active)
        OneSignalTracker.onInitWhileActive()
        OSSessionService.resetAndClearStoredRecord()

        OneSignalTracker.onInitWhileActive()
        let start = OSSessionService.shared.startNewSession(userProvider: userProvider)

        XCTAssertNil(start.started.awaitingFocus)
    }

    func testInitWhileInactiveHoldsTheSessionForItsFirstFocus() {
        UIApplicationOverrider.setCurrentUIApplicationState(.inactive)

        OneSignalTracker.onInitWhileActive()
        let start = OSSessionService.shared.startNewSession(userProvider: userProvider)

        XCTAssertEqual(start.started.awaitingFocus, true)
    }

    func testInitInTheBackgroundHoldsTheSessionForItsFirstFocus() {
        UIApplicationOverrider.setCurrentUIApplicationState(.background)

        OneSignalTracker.onInitWhileActive()
        let start = OSSessionService.shared.startNewSession(userProvider: userProvider)

        XCTAssertEqual(start.started.awaitingFocus, true)
    }

    /// A record from the previous process, as on a launch that ends it.
    private func storeSessionRecord(usesSessionsApi: Bool) throws {
        let record: [String: Any] = [
            "sessionId": "session-1",
            "startTime": Date().timeIntervalSince1970 - 10,
            "activeDuration": 0,
            "usesSessionsApi": usesSessionsApi
        ]
        let data = try JSONSerialization.data(withJSONObject: record)
        OneSignalUserDefaults.initStandard().saveObject(forKey: OSUD_SESSION_RECORD, withValue: data)
        OSSessionService.reset()
    }

    /// `NSDateOverrider` drives the SDK's clock in unit tests.
    private func visitForFiveSeconds() {
        NSDateOverrider.advanceSystemTime(by: 1_000)
        OSSessionManager.shared().setLastOpenedTime(NSDateOverrider.globalTimeOffset())
        NSDateOverrider.advanceSystemTime(by: 5)
    }

    private func endSessionAfterAVisit() {
        visitForFiveSeconds()
        OneSignalTracker.onSessionEnded([])
    }

    private func backgroundAfterAVisit() {
        visitForFiveSeconds()
        OneSignalTracker.applicationBackgrounded()
    }

    private func storeUnsentActiveTime(_ time: Double) {
        OneSignalUserDefaults.initShared().saveObject(forKey: OSUD_UNSENT_ACTIVE_TIME, withValue: time)
    }

    /// The processors begin this task as they send the session's time.
    private var sentSessionTime: Bool {
        taskHandler.begunTasks.contains(SESSION_OUTCOMES_TASK)
    }

    private var unsentActiveTime: Double? {
        OneSignalUserDefaults.initShared().getSavedObject(forKey: OSUD_UNSENT_ACTIVE_TIME, defaultValue: nil) as? Double
    }

    func testEndingALegacySessionReportsItsTime() throws {
        try storeSessionRecord(usesSessionsApi: false)

        endSessionAfterAVisit()

        XCTAssertGreaterThan(unsentActiveTime ?? 0, 0)
    }

    func testEndingASessionsApiSessionLeavesItsTimeToTheSessionsApi() throws {
        try storeSessionRecord(usesSessionsApi: true)

        endSessionAfterAVisit()

        XCTAssertNil(unsentActiveTime)
    }

    func testBackgroundingALegacySessionAddsTheVisitToItsUnsentTime() throws {
        try storeSessionRecord(usesSessionsApi: false)
        storeUnsentActiveTime(7)

        backgroundAfterAVisit()

        XCTAssertEqual(unsentActiveTime ?? 0, 12, accuracy: 1)
    }

    func testBackgroundingASessionsApiSessionSendsOnlyTheTimeALegacySessionLeftUnsent() throws {
        try storeSessionRecord(usesSessionsApi: true)
        storeUnsentActiveTime(7)

        backgroundAfterAVisit()

        XCTAssertTrue(sentSessionTime)
        XCTAssertEqual(unsentActiveTime, 7)
    }

    func testBackgroundingASessionsApiSessionWithNothingLeftUnsentSendsNoTime() throws {
        try storeSessionRecord(usesSessionsApi: true)

        backgroundAfterAVisit()

        XCTAssertFalse(sentSessionTime)
        XCTAssertNil(unsentActiveTime)
    }

    func testEndingASessionsApiSessionSendsOnlyTheTimeALegacySessionLeftUnsent() throws {
        try storeSessionRecord(usesSessionsApi: true)
        storeUnsentActiveTime(7)

        endSessionAfterAVisit()

        XCTAssertTrue(sentSessionTime)
        XCTAssertNotEqual(unsentActiveTime, 12)
    }
}
