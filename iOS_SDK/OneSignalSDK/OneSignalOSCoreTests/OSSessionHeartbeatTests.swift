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

private final class HeartbeatRecorder: OSSessionUserProvider {
    private(set) var heartbeats: [OSSessionRecord] = []

    var sessionCurrentUser: OSSessionUser {
        OSSessionUser(identityModelId: "model-a", onesignalId: "onesignal-a", pushSubscriptionId: "subscription-a")
    }

    func sessionOnesignalId(identityModelId: String) -> String? {
        "onesignal-a"
    }

    func sessionHeartbeat(_ record: OSSessionRecord) {
        heartbeats.append(record)
    }
}

final class OSSessionHeartbeatTests: XCTestCase {
    private let interval = OSSessionService.heartbeatInterval
    private let wallStart: TimeInterval = 1_700_000_000
    private var user: HeartbeatRecorder!
    private var flagsStore: OSFeatureFlagsStore!
    private var monotonicNow: TimeInterval = 0
    /// Moves the wall clock without moving the monotonic one.
    private var wallClockJump: TimeInterval = 0
    private var pending: [(fireAt: TimeInterval, block: () -> Void)] = []
    private var service: OSSessionService!

    override func setUp() {
        super.setUp()
        clearStorage()
        user = HeartbeatRecorder()
        flagsStore = OSFeatureFlagsStore()
        flagsStore.applyRemoteFlags([FeatureFlag.sdkSessionsV2ApiCutover.key], metadata: nil)
        monotonicNow = 0
        wallClockJump = 0
        pending = []
        service = makeService()
    }

    override func tearDown() {
        clearStorage()
        super.tearDown()
    }

    private func clearStorage() {
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
    }

    /// Wall time moves with the monotonic clock.
    private func makeService() -> OSSessionService {
        let manager = OSFeatureManager(store: flagsStore)
        return OSSessionService(
            featureManager: { manager },
            monotonicNow: { [unowned self] in self.monotonicNow },
            wallNow: { [unowned self] in self.wallStart + self.monotonicNow + self.wallClockJump },
            schedule: { [unowned self] delay, block in self.pending.append((self.monotonicNow + delay, block)) }
        )
    }

    /// The tracker reports focus, then the session starts.
    @discardableResult
    private func startForegroundSession() -> OSSessionRecord {
        service.onFocus()
        return service.startNewSession(userProvider: user).started
    }

    /// Advances both clocks, running each scheduled check when it comes due.
    private func advance(by seconds: TimeInterval) {
        let target = monotonicNow + seconds
        while let next = pending.enumerated().filter({ $0.element.fireAt <= target }).min(by: { $0.element.fireAt < $1.element.fireAt }) {
            pending.remove(at: next.offset)
            monotonicNow = next.element.fireAt
            next.element.block()
        }
        monotonicNow = target
    }

    private func heartbeatDurations(for record: OSSessionRecord) -> [TimeInterval] {
        user.heartbeats.filter { $0.sessionId == record.sessionId }.map(\.reportedDuration)
    }

    func testHeartbeatReportsDurationAfterThirtyMinutesInTheForeground() {
        let record = startForegroundSession()

        advance(by: interval - 1)
        XCTAssertTrue(user.heartbeats.isEmpty)

        advance(by: 1)
        XCTAssertEqual(heartbeatDurations(for: record), [interval])
        XCTAssertEqual(service.currentRecord?.lastHeartbeatDuration, interval)
        XCTAssertEqual(service.currentRecord?.lastHeartbeatTime, wallStart + interval)
    }

    func testHeartbeatRepeatsEveryThirtyMinutesInTheForeground() {
        let record = startForegroundSession()

        advance(by: 2 * interval)

        XCTAssertEqual(heartbeatDurations(for: record), [interval, 2 * interval])
    }

    /// A return within the new-session threshold continues the session.
    func testBackgroundPausesHeartbeatAndOnlyForegroundTimeCounts() {
        let record = startForegroundSession()
        advance(by: 20 * 60)
        service.onUnfocus()
        advance(by: 20)

        service.onFocus()
        advance(by: 10 * 60 - 1)
        XCTAssertTrue(user.heartbeats.isEmpty)

        advance(by: 1)
        XCTAssertEqual(heartbeatDurations(for: record), [interval])
    }

    /// Each stale check is left pending and runs after its heartbeat stopped.
    func testUnfocusStopsAPendingCheck() {
        startForegroundSession()
        advance(by: 20 * 60)
        service.onUnfocus()
        XCTAssertFalse(pending.isEmpty)

        advance(by: 2 * interval)

        XCTAssertTrue(user.heartbeats.isEmpty)
        XCTAssertTrue(pending.isEmpty)
    }

    /// The scheduler's clock pauses through device sleep, so a check can fire after more foreground
    /// time than it waited for.
    func testCheckThatFiresLateReportsTheFullDurationAndWaitsAFullInterval() {
        let record = startForegroundSession()

        let check = pending.removeFirst()
        monotonicNow = check.fireAt + 600
        check.block()

        XCTAssertEqual(heartbeatDurations(for: record), [interval + 600])
        XCTAssertEqual(pending.map(\.fireAt), [monotonicNow + interval])
    }

    func testNewSessionRestartsTheInterval() {
        let first = startForegroundSession()
        advance(by: interval)
        service.onUnfocus()
        advance(by: 60)

        let second = startForegroundSession()
        advance(by: interval - 1)
        XCTAssertTrue(heartbeatDurations(for: second).isEmpty)

        advance(by: 1)
        XCTAssertEqual(heartbeatDurations(for: first), [interval])
        XCTAssertEqual(heartbeatDurations(for: second), [interval])
    }

    /// The focus that starts a new session must not send a heartbeat for the session it replaces.
    func testFocusThatStartsANewSessionDoesNotStartTheHeartbeat() {
        startForegroundSession()
        advance(by: 20 * 60)
        service.onUnfocus()
        advance(by: 60)

        service.onFocus()
        advance(by: 2 * interval)

        XCTAssertTrue(user.heartbeats.isEmpty)
    }

    /// An update queued before its session's create is discarded. The visit open when the new
    /// session starts carries over to it, so its first heartbeat counts that whole visit.
    func testNewSessionStopsTheOldHeartbeatAndStartsItsOwnAfterEnqueueing() {
        let first = startForegroundSession()
        advance(by: interval - 60)

        let second = service.startNewSession(userProvider: user) { _ in
            advance(by: 2 * interval)
            XCTAssertTrue(user.heartbeats.isEmpty)
        }.started

        XCTAssertEqual(heartbeatDurations(for: first), [])
        XCTAssertEqual(heartbeatDurations(for: second), [3 * interval - 60])
    }

    func testSessionThatLeftTheForegroundAfterAHeartbeatEndsAtItsUnfocus() {
        let first = startForegroundSession()
        wallClockJump = 3_600
        advance(by: interval)
        wallClockJump = 0
        advance(by: 60)
        service.onUnfocus()

        let ended = makeService().startNewSession(userProvider: user).ended

        XCTAssertEqual(ended?.sessionId, first.sessionId)
        XCTAssertNil(ended?.lastHeartbeatTime)
        XCTAssertEqual(ended?.endTime, wallStart + interval + 60)
    }

    func testSessionKilledAfterAClockJumpedHeartbeatEndsAtItsForegroundTime() {
        let first = startForegroundSession()
        wallClockJump = 3_600
        advance(by: interval)

        let ended = makeService().startNewSession(userProvider: user).ended

        XCTAssertEqual(ended?.sessionId, first.sessionId)
        XCTAssertEqual(ended?.lastHeartbeatTime, wallStart + interval)
        XCTAssertEqual(ended?.endTime, wallStart + interval)
    }

    func testNoHeartbeatWhenFlagIsOff() {
        flagsStore.applyRemoteFlags([], metadata: nil)
        service = makeService()
        startForegroundSession()

        advance(by: 2 * interval)

        XCTAssertTrue(pending.isEmpty)
        XCTAssertTrue(user.heartbeats.isEmpty)
    }

    func testSessionKilledAfterAHeartbeatEndsWithItsDurationAndTime() {
        let first = startForegroundSession()
        advance(by: interval + 60)

        let ended = makeService().startNewSession(userProvider: user).ended

        XCTAssertEqual(ended?.sessionId, first.sessionId)
        XCTAssertEqual(ended?.activeDuration, 0)
        XCTAssertEqual(ended?.reportedDuration, interval)
        XCTAssertEqual(ended?.endTime, wallStart + interval)
    }
}
