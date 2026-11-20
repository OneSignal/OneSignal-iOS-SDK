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

private final class SplitRecorder: OSSessionUserProvider {
    enum Event: Equatable {
        case create(sessionId: String, directAttributionId: String?)
        case heartbeat(sessionId: String, duration: TimeInterval)
        case checkpoint(sessionId: String)
        case end(sessionId: String, duration: TimeInterval, endTime: TimeInterval)
    }

    var identityModelId = "model-a"
    var onesignalId: String? = "onesignal-a"
    var externalId: String? = "external-a"
    var sessionRequiresIdentityVerification = false
    private(set) var events: [Event] = []

    var sessionCurrentUser: OSSessionUser {
        OSSessionUser(identityModelId: identityModelId, onesignalId: onesignalId, pushSubscriptionId: "subscription-a", externalId: externalId)
    }

    func switchUser(identityModelId: String, onesignalId: String?, externalId: String?) {
        self.identityModelId = identityModelId
        self.onesignalId = onesignalId
        self.externalId = externalId
    }

    func sessionOnesignalId(identityModelId: String) -> String? {
        identityModelId == self.identityModelId ? onesignalId : nil
    }

    func sessionHeartbeat(_ record: OSSessionRecord) {
        events.append(.heartbeat(sessionId: record.sessionId, duration: record.reportedDuration))
    }

    func sessionCheckpoint(_ record: OSSessionRecord) {
        events.append(.checkpoint(sessionId: record.sessionId))
    }

    func sessionCreate(_ record: OSSessionRecord) {
        events.append(.create(sessionId: record.sessionId, directAttributionId: record.directAttributionId))
    }

    func sessionEnd(_ record: OSSessionRecord) {
        events.append(.end(sessionId: record.sessionId, duration: record.reportedDuration, endTime: record.endTime))
    }
}

final class OSSessionSplitTests: XCTestCase {
    private let interval = OSSessionService.defaultHeartbeatInterval
    private let wallStart: TimeInterval = 1_700_000_000
    private var user: SplitRecorder!
    private var flagsStore: OSFeatureFlagsStore!
    private var monotonicNow: TimeInterval = 0
    private var pending: [(fireAt: TimeInterval, block: () -> Void)] = []
    private var service: OSSessionService!

    override func setUp() {
        super.setUp()
        clearStorage()
        user = SplitRecorder()
        flagsStore = OSFeatureFlagsStore()
        flagsStore.applyRemoteFlags([FeatureFlag.sdkSessionsV2ApiCutover.key], metadata: nil)
        monotonicNow = 0
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

    private var wallNow: TimeInterval {
        wallStart + monotonicNow
    }

    private func makeService() -> OSSessionService {
        let manager = OSFeatureManager(store: flagsStore)
        return OSSessionService(
            featureManager: { manager },
            monotonicNow: { [unowned self] in self.monotonicNow },
            wallNow: { [unowned self] in self.wallNow },
            schedule: { [unowned self] delay, block in self.pending.append((self.monotonicNow + delay, block)) },
            heartbeatInterval: { [unowned self] in self.interval }
        )
    }

    @discardableResult
    private func startForegroundSession() -> OSSessionRecord {
        service.onFocus()
        return service.startNewSession(userProvider: user).started
    }

    private func advance(by seconds: TimeInterval) {
        let target = monotonicNow + seconds
        while let next = pending.enumerated().filter({ $0.element.fireAt <= target }).min(by: { $0.element.fireAt < $1.element.fireAt }) {
            pending.remove(at: next.offset)
            monotonicNow = next.element.fireAt
            next.element.block()
        }
        monotonicNow = target
    }

    private func background() {
        service.onUnfocus()
        _ = service.onEnteredBackground()
    }

    private func switchToUserB() {
        user.switchUser(identityModelId: "model-b", onesignalId: "onesignal-b", externalId: "external-b")
    }

    // MARK: - Focused

    func testFocusedSplitEndsTheSessionNowAndStartsTheNextForTheNewUser() throws {
        let first = startForegroundSession()
        advance(by: 10 * 60)
        let switchTime = wallNow
        switchToUserB()

        service.onUserSwitched()

        let next = try XCTUnwrap(service.currentRecord)
        XCTAssertNotEqual(next.sessionId, first.sessionId)
        XCTAssertEqual(user.events, [
            .end(sessionId: first.sessionId, duration: 10 * 60, endTime: switchTime),
            .create(sessionId: next.sessionId, directAttributionId: nil)
        ])
        XCTAssertEqual(next.startTime, switchTime)
        XCTAssertEqual(next.identityModelId, "model-b")
        XCTAssertEqual(next.onesignalId, "onesignal-b")
        XCTAssertEqual(next.externalId, "external-b")
        XCTAssertEqual(next.activeDuration, 0)
        XCTAssertTrue(next.usesSessionsApi)
    }

    func testSplitToAnAnonymousUserHoldsTheNextCreate() {
        let first = startForegroundSession()
        advance(by: 60)
        user.switchUser(identityModelId: "model-b", onesignalId: nil, externalId: nil)

        service.onUserSwitched()

        XCTAssertEqual(user.events, [.end(sessionId: first.sessionId, duration: 60, endTime: wallNow)])
        XCTAssertEqual(service.currentRecord?.createHeld, true)
    }

    func testHeartbeatRestartsFromTheNextSessionsStart() throws {
        startForegroundSession()
        advance(by: 20 * 60)
        switchToUserB()
        service.onUserSwitched()
        let next = try XCTUnwrap(service.currentRecord)

        advance(by: interval)

        XCTAssertEqual(user.events.last, .heartbeat(sessionId: next.sessionId, duration: interval))
        XCTAssertEqual(user.events.filter { if case .heartbeat = $0 { return true } else { return false } }.count, 1)
    }

    // MARK: - Anonymous

    func testLoginWhileTheCreateIsHeldMovesTheSessionAndQueuesItsCreate() throws {
        user.externalId = nil
        service.onNotificationOpened("notification-1")
        let first = startForegroundSession()
        advance(by: 60)
        user.switchUser(identityModelId: "model-b", onesignalId: nil, externalId: "external-b")

        service.onUserSwitched()

        let record = try XCTUnwrap(service.currentRecord)
        XCTAssertEqual(record.sessionId, first.sessionId)
        XCTAssertEqual(record.startTime, first.startTime)
        XCTAssertEqual(record.identityModelId, "model-b")
        XCTAssertEqual(record.externalId, "external-b")
        XCTAssertNil(record.createHeld)
        XCTAssertEqual(user.events, [.create(sessionId: first.sessionId, directAttributionId: "notification-1")])
    }

    func testLoginUnderIdentityVerificationMovesAHeldCreateThatCouldNotBeSent() {
        user.sessionRequiresIdentityVerification = true
        user.externalId = nil
        user.onesignalId = nil
        let first = startForegroundSession()
        background()
        XCTAssertTrue(user.events.isEmpty)
        user.switchUser(identityModelId: "model-b", onesignalId: nil, externalId: "external-b")

        service.onUserSwitched()

        XCTAssertEqual(user.events, [.create(sessionId: first.sessionId, directAttributionId: nil)])
    }

    func testSwitchToAnotherAnonymousUserWhileHeldKeepsHolding() {
        user.externalId = nil
        startForegroundSession()
        user.switchUser(identityModelId: "model-b", onesignalId: nil, externalId: nil)

        service.onUserSwitched()

        XCTAssertTrue(user.events.isEmpty)
        XCTAssertEqual(service.currentRecord?.createHeld, true)
        XCTAssertEqual(service.currentRecord?.identityModelId, "model-b")
    }

    func testLoginAfterAnAnonymousCreateWasSentKeepsTheSessionAndALaterSwitchSplits() {
        user.externalId = nil
        let first = startForegroundSession()
        background()
        service.onFocus()
        user.switchUser(identityModelId: "model-b", onesignalId: "onesignal-b", externalId: "external-b")

        service.onUserSwitched()

        XCTAssertEqual(service.currentRecord?.sessionId, first.sessionId)
        XCTAssertEqual(service.currentRecord?.identityModelId, "model-a")
        XCTAssertEqual(service.currentRecord?.externalId, "external-b")
        XCTAssertEqual(user.events, [.create(sessionId: first.sessionId, directAttributionId: nil)])

        user.switchUser(identityModelId: "model-c", onesignalId: "onesignal-c", externalId: "external-c")
        service.onUserSwitched()

        XCTAssertNotEqual(service.currentRecord?.sessionId, first.sessionId)
        XCTAssertEqual(user.events.dropFirst().first, .end(sessionId: first.sessionId, duration: 0, endTime: wallNow))
    }

    // MARK: - Background

    func testBackgroundSplitEndsTheSessionNowAndStartsTheNextOnTheNextFocus() throws {
        let first = startForegroundSession()
        advance(by: 60)
        background()
        let unfocusTime = wallNow
        advance(by: 10)
        switchToUserB()

        service.onUserSwitched()

        XCTAssertEqual(user.events.last, .end(sessionId: first.sessionId, duration: 60, endTime: unfocusTime))
        XCTAssertEqual(service.currentRecord?.splitPending, true)
        XCTAssertFalse(service.onEnteredBackground())

        advance(by: 5)
        service.onNotificationOpened("notification-1")
        service.onFocus()

        let next = try XCTUnwrap(service.currentRecord)
        XCTAssertNotEqual(next.sessionId, first.sessionId)
        XCTAssertEqual(next.startTime, wallNow)
        XCTAssertEqual(next.identityModelId, "model-b")
        XCTAssertNil(next.splitPending)
        XCTAssertEqual(user.events.last, .create(sessionId: next.sessionId, directAttributionId: "notification-1"))

        advance(by: interval)
        XCTAssertEqual(user.events.last, .heartbeat(sessionId: next.sessionId, duration: interval))
    }

    func testTimeoutAfterABackgroundSplitSendsNoSecondEnd() {
        startForegroundSession()
        background()
        switchToUserB()
        service.onUserSwitched()

        advance(by: 60)
        service.onFocus()
        let start = service.startNewSession(userProvider: user)

        XCTAssertNil(start.ended)
    }

    func testColdStartAfterABackgroundSplitSendsNoSecondEnd() {
        startForegroundSession()
        background()
        switchToUserB()
        service.onUserSwitched()

        service = makeService()
        service.onFocus()
        let start = service.startNewSession(userProvider: user)

        XCTAssertNil(start.ended)
    }

    func testSecondSplitBeforeTheNextFocusSendsNothing() {
        startForegroundSession()
        background()
        switchToUserB()
        service.onUserSwitched()
        let events = user.events

        user.switchUser(identityModelId: "model-c", onesignalId: "onesignal-c", externalId: "external-c")
        service.onUserSwitched()
        service.onFocus()

        XCTAssertEqual(user.events.count, events.count + 1)
        XCTAssertEqual(service.currentRecord?.identityModelId, "model-c")
    }

    // MARK: - Record about to be replaced

    func testSwitchAfterAFocusThatWillStartANewSessionChangesNothing() {
        let first = startForegroundSession()
        background()
        advance(by: 60)
        service.onFocus()
        switchToUserB()

        service.onUserSwitched()

        XCTAssertTrue(user.events.isEmpty)
        XCTAssertEqual(service.currentRecord?.sessionId, first.sessionId)
        XCTAssertEqual(service.startNewSession(userProvider: user).ended?.endTime, first.startTime)
    }

    func testSwitchBeforeTheFirstSessionOfALaunchChangesNothing() {
        let first = startForegroundSession()
        service = makeService()
        service.setUserProvider(user)
        switchToUserB()

        service.onUserSwitched()

        XCTAssertTrue(user.events.isEmpty)
        XCTAssertEqual(service.currentRecord?.sessionId, first.sessionId)
    }

    // MARK: - Legacy

    func testLegacySessionDoesNotSplit() {
        flagsStore.applyRemoteFlags([], metadata: nil)
        service = makeService()
        let first = startForegroundSession()
        switchToUserB()

        service.onUserSwitched()

        XCTAssertTrue(user.events.isEmpty)
        XCTAssertEqual(service.currentRecord?.sessionId, first.sessionId)
    }
}
