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
    var sessionCurrentUser: OSSessionUser {
        OSSessionUser(identityModelId: "model-a", onesignalId: "onesignal-a", pushSubscriptionId: "subscription-a")
    }

    func sessionOnesignalId(identityModelId: String) -> String? {
        "onesignal-a"
    }

    func sessionUserCanBeCreated(identityModelId: String) -> Bool {
        true
    }
}

/// Never answers, so every request stays queued where the test can read it.
private final class SilentBackend: OSSessionsBackend {
    func createSession(appId: String, body: OSCreateSessionRequestBody, completion: @escaping (OSSessionsApiResult<String>) -> Void) {}

    func updateSession(
        appId: String,
        sessionId: String,
        body: OSUpdateSessionRequestBody,
        completion: @escaping (OSSessionsApiResult<Void>) -> Void
    ) {}
}

private final class FakeNetworkMonitor: OSSessionNetworkMonitoring {
    func start(onAvailable: @escaping () -> Void) {}
    func stop() {}
}

final class OSSessionHeartbeatTests: XCTestCase {
    private let interval = OSSessionService.heartbeatInterval
    private let wallStart: TimeInterval = 1_700_000_000
    private let user = FakeUserProvider()
    private var flagsStore: OSFeatureFlagsStore!
    private var monotonicNow: TimeInterval = 0
    private var pending: [(fireAt: TimeInterval, block: () -> Void)] = []
    private var service: OSSessionService!
    private var queue: OSSessionRequestQueue!

    override func setUp() {
        super.setUp()
        clearStorage()
        flagsStore = OSFeatureFlagsStore()
        flagsStore.applyRemoteFlags([FeatureFlag.sdkSessionsV2ApiCutover.key], metadata: nil)
        monotonicNow = 0
        pending = []
        service = makeService()
        queue = OSSessionRequestQueue(
            backend: SilentBackend(),
            sessionService: { [unowned self] in self.service },
            appId: { "app-id" },
            networkMonitor: FakeNetworkMonitor(),
            schedule: { _, _ in },
            postCreateDelay: 0
        )
    }

    override func tearDown() {
        queue?.retireForTesting()
        clearStorage()
        super.tearDown()
    }

    private func clearStorage() {
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_REQUEST_QUEUE)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
    }

    /// Wall time moves with the monotonic clock.
    private func makeService() -> OSSessionService {
        let manager = OSFeatureManager(store: flagsStore)
        return OSSessionService(
            featureManager: { manager },
            monotonicNow: { [unowned self] in self.monotonicNow },
            wallNow: { [unowned self] in self.wallStart + self.monotonicNow },
            requestQueue: { [unowned self] in self.queue },
            schedule: { [unowned self] delay, block in self.pending.append((self.monotonicNow + delay, block)) }
        )
    }

    /// The tracker reports focus, then the session starts.
    private func startForegroundSession() -> OSSessionRecord {
        service.onFocus()
        service.startNewSession(userProvider: user)
        return service.currentRecord!
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

    /// Unsent heartbeats for a session are coalesced, so each session has at most one.
    private func heartbeats(for record: OSSessionRecord) -> [OSSessionRequest] {
        queue.waitUntilIdle()
        return queue.queuedRequests.filter { $0.localSessionId == record.sessionId && !$0.isCreate && !$0.isEnd }
    }

    func testHeartbeatReportsDurationAfterThirtyMinutesInTheForeground() {
        let record = startForegroundSession()

        advance(by: interval - 1)
        XCTAssertTrue(heartbeats(for: record).isEmpty)

        advance(by: 1)
        XCTAssertEqual(heartbeats(for: record).map(\.kind), [.update(activeDuration: interval, endTime: nil)])
        XCTAssertEqual(service.currentRecord?.lastHeartbeatDuration, interval)
        XCTAssertEqual(service.currentRecord?.lastHeartbeatTime, wallStart + interval)
    }

    func testHeartbeatRepeatsEveryThirtyMinutesInTheForeground() {
        let record = startForegroundSession()

        advance(by: 2 * interval)

        XCTAssertEqual(heartbeats(for: record).map(\.activeDuration), [2 * interval])
        XCTAssertEqual(service.currentRecord?.lastHeartbeatDuration, 2 * interval)
    }

    func testBackgroundPausesHeartbeatAndOnlyForegroundTimeCounts() {
        let record = startForegroundSession()
        advance(by: 20 * 60)
        service.onUnfocus()

        advance(by: 2 * interval)
        XCTAssertTrue(heartbeats(for: record).isEmpty)

        service.onFocus()
        advance(by: 10 * 60)
        XCTAssertEqual(heartbeats(for: record).map(\.activeDuration), [interval])
    }

    func testNewSessionRestartsTheInterval() {
        let first = startForegroundSession()
        advance(by: interval)
        service.onUnfocus()

        let second = startForegroundSession()
        advance(by: interval - 1)
        XCTAssertTrue(heartbeats(for: second).isEmpty)
        XCTAssertNil(service.currentRecord?.lastHeartbeatDuration)

        advance(by: 1)
        XCTAssertNotEqual(first.sessionId, second.sessionId)
        XCTAssertEqual(heartbeats(for: second).map(\.activeDuration), [interval])
    }

    func testNoHeartbeatWhenFlagIsOff() {
        flagsStore.applyRemoteFlags([], metadata: nil)
        service = makeService()
        _ = startForegroundSession()

        advance(by: 2 * interval)

        XCTAssertTrue(pending.isEmpty)
        queue.waitUntilIdle()
        XCTAssertTrue(queue.queuedRequests.isEmpty)
    }

    func testSessionKilledAfterAHeartbeatEndsWithItsDurationAndTime() {
        let first = startForegroundSession()
        advance(by: interval + 60)

        service = makeService()
        _ = startForegroundSession()
        queue.waitUntilIdle()

        let end = queue.queuedRequests.first { $0.localSessionId == first.sessionId && $0.isEnd }
        XCTAssertEqual(end?.kind, .update(activeDuration: interval, endTime: wallStart + interval))
    }
}
