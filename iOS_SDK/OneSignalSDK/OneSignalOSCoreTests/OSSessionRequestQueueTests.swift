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
    var identityModelId: String? = "model-a"
    var onesignalIds: [String: String] = ["model-a": "onesignal-a"]
    var pushSubscriptionId: String? = "subscription-a"
    var creatableModelIds: Set<String>?

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

    func sessionUserCanBeCreated(identityModelId: String) -> Bool {
        creatableModelIds?.contains(identityModelId) ?? true
    }
}

private final class FakeBackend: OSSessionsBackend {
    enum Call {
        case create(appId: String, body: OSCreateSessionRequestBody, completion: (OSSessionsApiResult<String>) -> Void)
        case update(appId: String, sessionId: String, body: OSUpdateSessionRequestBody, completion: (OSSessionsApiResult<Void>) -> Void)

        var idempotencyKey: String {
            switch self {
            case .create(_, let body, _): return body.idempotencyKey
            case .update(_, _, let body, _): return body.idempotencyKey
            }
        }
    }

    private let lock = NSLock()
    private var _calls: [Call] = []
    var calls: [Call] { lock.withLock { _calls } }

    func createSession(appId: String, body: OSCreateSessionRequestBody, completion: @escaping (OSSessionsApiResult<String>) -> Void) {
        lock.withLock { _calls.append(.create(appId: appId, body: body, completion: completion)) }
    }

    func updateSession(
        appId: String,
        sessionId: String,
        body: OSUpdateSessionRequestBody,
        completion: @escaping (OSSessionsApiResult<Void>) -> Void
    ) {
        lock.withLock { _calls.append(.update(appId: appId, sessionId: sessionId, body: body, completion: completion)) }
    }

    func respondToLast(createdSessionId: String) {
        guard case .create(_, _, let completion) = calls.last else {
            return XCTFail("last call is not a create")
        }
        completion(.success(createdSessionId))
    }

    func respondToLastUpdate() {
        guard case .update(_, _, _, let completion) = calls.last else {
            return XCTFail("last call is not an update")
        }
        completion(.success(()))
    }

    func failLast(_ result: OSSessionsApiResult<Void>) {
        switch calls.last {
        case .create(_, _, let completion):
            switch result {
            case .retry(let statusCode, let retryAfterSeconds):
                completion(.retry(statusCode: statusCode, retryAfterSeconds: retryAfterSeconds))
            case .drop(let statusCode):
                completion(.drop(statusCode: statusCode))
            case .success:
                XCTFail("not a failure")
            }
        case .update(_, _, _, let completion):
            completion(result)
        case nil:
            XCTFail("no call")
        }
    }
}

private final class FakeNetworkMonitor: OSSessionNetworkMonitoring {
    private(set) var onAvailable: (() -> Void)?

    func start(onAvailable: @escaping () -> Void) {
        self.onAvailable = onAvailable
    }

    func stop() {
        onAvailable = nil
    }
}

final class OSSessionRequestQueueTests: XCTestCase {
    private var user: FakeUserProvider!
    private var backend: FakeBackend!
    private var monitor: FakeNetworkMonitor!
    private var service: OSSessionService!
    private var flagsStore: OSFeatureFlagsStore!
    private var now: TimeInterval = 10_000
    private var scheduled: [(delay: TimeInterval, block: () -> Void)] = []
    private var queue: OSSessionRequestQueue!

    override func setUp() {
        super.setUp()
        clearStorage()
        user = FakeUserProvider()
        backend = FakeBackend()
        monitor = FakeNetworkMonitor()
        flagsStore = OSFeatureFlagsStore()
        flagsStore.applyRemoteFlags([FeatureFlag.sdkSessionsV2ApiCutover.key], metadata: nil)
        let manager = OSFeatureManager(store: flagsStore)
        service = OSSessionService(featureManager: { manager }, monotonicNow: { 0 }, wallNow: { 1_700_000_000 })
        now = 10_000
        scheduled = []
        queue = makeQueue()
    }

    override func tearDown() {
        queue?.waitUntilIdle()
        clearStorage()
        super.tearDown()
    }

    private func clearStorage() {
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_REQUEST_QUEUE)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
    }

    private func makeQueue() -> OSSessionRequestQueue {
        OSSessionRequestQueue(
            backend: backend,
            sessionService: { [unowned self] in self.service },
            appId: { "app-id" },
            networkMonitor: monitor,
            now: { [unowned self] in self.now },
            jitter: { 1 },
            schedule: { [unowned self] delay, block in self.scheduled.append((delay, block)) }
        )
    }

    private func startSession() -> OSSessionRecord {
        service.startNewSession(userProvider: user)
        return service.currentRecord!
    }

    private func record(duration: TimeInterval, from base: OSSessionRecord) -> OSSessionRecord {
        var record = base
        record.activeDuration = duration
        return record
    }

    private func settle() {
        queue.waitUntilIdle()
        queue.waitUntilIdle()
    }

    private var updateDurations: [Int64] {
        backend.calls.compactMap {
            if case .update(_, _, let body, _) = $0 {
                return body.durationSeconds
            }
            return nil
        }
    }

    // MARK: - Sending

    func testCreateIsPersistedBeforeSendingAndRemovedOnSuccess() {
        let record = startSession()

        queue.enqueueCreate(record: record, directAttributionId: "notification-id")
        settle()

        XCTAssertEqual(queue.queuedRequests.count, 1)
        XCTAssertNotNil(OneSignalUserDefaults.initStandard().getSavedObject(forKey: OSUD_SESSION_REQUEST_QUEUE, defaultValue: nil))
        guard case .create(let appId, let body, _) = backend.calls.first else {
            return XCTFail("expected a create")
        }
        XCTAssertEqual(appId, "app-id")
        XCTAssertEqual(body.onesignalId, "onesignal-a")
        XCTAssertEqual(body.subscriptionId, "subscription-a")
        XCTAssertEqual(body.startTime, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(body.directAttributionId, "notification-id")

        backend.respondToLast(createdSessionId: "server-1")
        settle()

        XCTAssertTrue(queue.queuedRequests.isEmpty)
        XCTAssertEqual(service.currentRecord?.serverSessionId, "server-1")
    }

    func testCreateIdempotencyKeyIsTheSessionId() {
        let record = startSession()

        queue.enqueueCreate(record: record)
        settle()

        XCTAssertEqual(backend.calls.first?.idempotencyKey, record.sessionId)
    }

    func testRestartRemembersServerSessionIdOfQueuedUpdates() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        queue.enqueueUpdate(record: self.record(duration: 10, from: record))
        settle()
        backend.respondToLast(createdSessionId: "server-1")
        settle()
        backend.failLast(.retry(statusCode: 0, retryAfterSeconds: nil))
        settle()

        queue = makeQueue()
        // A snapshot taken before the create returned.
        queue.enqueueCreate(record: record)
        settle()

        XCTAssertFalse(queue.queuedRequests.contains { $0.isCreate })
    }

    func testAppIdChangeClearsStoredQueueAndLateCompletionDoesNotRestoreIt() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()

        let retired = queue!
        let key = OSUD_SESSION_REQUEST_QUEUE
        retired.retireForTesting()
        OneSignalUserDefaults.initStandard().removeValue(forKey: key)
        backend.failLast(.retry(statusCode: 500, retryAfterSeconds: nil))
        retired.waitUntilIdle()

        XCTAssertNil(OneSignalUserDefaults.initStandard().getSavedObject(forKey: key, defaultValue: nil))
    }

    func testCreateForUserThatIsNeverCreatedIsDroppedWithItsUpdates() {
        user.onesignalIds = [:]
        let record = startSession()
        queue.enqueueCreate(record: record)
        queue.enqueueUpdate(record: self.record(duration: 10, from: record))
        settle()
        XCTAssertEqual(queue.queuedRequests.count, 2)

        user.creatableModelIds = []
        queue.retryNow()
        settle()

        XCTAssertTrue(queue.queuedRequests.isEmpty)
        XCTAssertNil(monitor.onAvailable)
    }

    func testFlagOffEnqueuesNothing() {
        flagsStore.applyRemoteFlags([], metadata: nil)
        let record = startSession()

        queue.enqueueCreate(record: record)
        queue.enqueueUpdate(record: record)
        settle()

        XCTAssertTrue(queue.queuedRequests.isEmpty)
        XCTAssertTrue(backend.calls.isEmpty)
    }

    func testCreateWaitsForOnesignalIdAndSubscriptionId() {
        user.onesignalIds = [:]
        user.pushSubscriptionId = nil
        let record = startSession()

        queue.enqueueCreate(record: record)
        settle()
        XCTAssertTrue(backend.calls.isEmpty)

        user.onesignalIds = ["model-a": "onesignal-a"]
        queue.retryNow()
        settle()
        XCTAssertTrue(backend.calls.isEmpty)

        user.pushSubscriptionId = "subscription-a"
        queue.retryNow()
        settle()

        guard case .create(_, let body, _) = backend.calls.first else {
            return XCTFail("expected a create")
        }
        XCTAssertEqual(body.onesignalId, "onesignal-a")
        XCTAssertEqual(body.subscriptionId, "subscription-a")
        XCTAssertEqual(service.currentRecord?.onesignalId, "onesignal-a")
    }

    func testUpdateWaitsForCreateAndUsesServerSessionId() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        queue.enqueueUpdate(record: self.record(duration: 12.9, from: record))
        settle()
        XCTAssertEqual(backend.calls.count, 1)

        backend.respondToLast(createdSessionId: "server-1")
        settle()

        guard case .update(_, let sessionId, let body, _) = backend.calls.last else {
            return XCTFail("expected an update")
        }
        XCTAssertEqual(sessionId, "server-1")
        XCTAssertEqual(body.durationSeconds, 12)
        XCTAssertNil(body.endTime)

        backend.respondToLastUpdate()
        settle()
        XCTAssertTrue(queue.queuedRequests.isEmpty)
    }

    func testUpdateEnqueuedWhileCreateInFlightGetsServerSessionId() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()
        backend.respondToLast(createdSessionId: "server-1")
        settle()

        // The caller still holds the record read before the create returned.
        queue.enqueueUpdate(record: self.record(duration: 5, from: record))
        settle()

        guard case .update(_, let sessionId, _, _) = backend.calls.last else {
            return XCTFail("expected an update")
        }
        XCTAssertEqual(sessionId, "server-1")
    }

    func testCreateIsNotEnqueuedTwice() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        queue.enqueueCreate(record: record)
        settle()
        XCTAssertEqual(queue.queuedRequests.count, 1)

        backend.respondToLast(createdSessionId: "server-1")
        settle()
        queue.enqueueCreate(record: record)
        settle()

        XCTAssertEqual(backend.calls.count, 1)
    }

    // MARK: - Coalescing

    func testQueuedUpdatesCollapseToHighestDuration() {
        user.onesignalIds = [:]
        let record = startSession()
        queue.enqueueCreate(record: record)
        queue.enqueueUpdate(record: self.record(duration: 30, from: record))
        queue.enqueueUpdate(record: self.record(duration: 20, from: record))
        settle()

        let requests = queue.queuedRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.activeDuration, 30)
    }

    func testEndReplacesQueuedUpdateAndLaterUpdatesAreDiscarded() {
        user.onesignalIds = [:]
        let record = startSession()
        queue.enqueueCreate(record: record)
        queue.enqueueUpdate(record: self.record(duration: 10, from: record))
        queue.enqueueUpdate(record: self.record(duration: 15, from: record), endTime: 1_700_000_100)
        queue.enqueueUpdate(record: self.record(duration: 20, from: record))
        settle()

        let requests = queue.queuedRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.kind, .update(activeDuration: 15, endTime: 1_700_000_100))
    }

    func testCoalescingKeepsUnchangedRequestAndCarriesFailedAttempts() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()
        backend.respondToLast(createdSessionId: "server-1")
        settle()
        queue.enqueueUpdate(record: self.record(duration: 10, from: record))
        settle()
        let key = backend.calls.last?.idempotencyKey
        backend.failLast(.retry(statusCode: 500, retryAfterSeconds: nil))
        settle()

        queue.enqueueUpdate(record: self.record(duration: 10, from: record))
        settle()
        XCTAssertEqual(queue.queuedRequests.map(\.idempotencyKey), [key])
        XCTAssertEqual(queue.queuedRequests.first?.failedAttempts, 1)

        queue.enqueueUpdate(record: self.record(duration: 20, from: record))
        settle()
        XCTAssertEqual(queue.queuedRequests.count, 1)
        XCTAssertNotEqual(queue.queuedRequests.first?.idempotencyKey, key)
        XCTAssertEqual(queue.queuedRequests.first?.failedAttempts, 1)
    }

    func testInFlightUpdateIsNotCoalesced() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()
        backend.respondToLast(createdSessionId: "server-1")
        settle()
        queue.enqueueUpdate(record: self.record(duration: 10, from: record))
        settle()

        queue.enqueueUpdate(record: self.record(duration: 20, from: record))
        settle()
        XCTAssertEqual(queue.queuedRequests.count, 2)

        backend.respondToLastUpdate()
        settle()

        XCTAssertEqual(updateDurations, [10, 20])
    }

    func testUpdateWithoutCreateOrServerSessionIdIsDiscarded() {
        let record = startSession()

        queue.enqueueUpdate(record: record)
        settle()

        XCTAssertTrue(queue.queuedRequests.isEmpty)
    }

    func testSessionsAreCoalescedIndependently() {
        user.onesignalIds = [:]
        let first = startSession()
        queue.enqueueCreate(record: first)
        queue.enqueueUpdate(record: record(duration: 10, from: first))
        let second = startSession()
        queue.enqueueCreate(record: second)
        queue.enqueueUpdate(record: record(duration: 5, from: second))
        settle()

        XCTAssertEqual(queue.queuedRequests.count, 4)
    }

}

// MARK: - Cap

extension OSSessionRequestQueueTests {

    func testCapDropsOldestAndItsUpdates() {
        user.onesignalIds = [:]
        let first = startSession()
        queue.enqueueCreate(record: first)
        queue.enqueueUpdate(record: record(duration: 10, from: first))
        for _ in 0..<OSSessionRequestQueue.maxQueuedRequests - 1 {
            queue.enqueueCreate(record: startSession())
        }
        settle()

        let requests = queue.queuedRequests
        XCTAssertEqual(requests.count, OSSessionRequestQueue.maxQueuedRequests - 1)
        XCTAssertFalse(requests.contains { $0.localSessionId == first.sessionId })
    }

}

// MARK: - Retry

extension OSSessionRequestQueueTests {

    func testRetryKeepsIdempotencyKeyAcrossRestart() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()
        let key = backend.calls.first?.idempotencyKey
        backend.failLast(.retry(statusCode: 0, retryAfterSeconds: nil))
        settle()
        XCTAssertEqual(queue.queuedRequests.count, 1)

        queue = makeQueue()
        queue.retryNow()
        settle()

        XCTAssertEqual(backend.calls.count, 2)
        XCTAssertEqual(backend.calls.last?.idempotencyKey, key)
    }

    func testFailureBacksOffExponentiallyAndRetryNowEndsBackoff() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()

        backend.failLast(.retry(statusCode: 503, retryAfterSeconds: nil))
        settle()
        XCTAssertEqual(scheduled.last?.delay, OSSessionRequestQueue.baseBackoffSeconds)
        queue.enqueueCreate(record: startSession())
        settle()
        XCTAssertEqual(backend.calls.count, 1, "nothing is sent while backing off")

        queue.retryNow()
        settle()
        XCTAssertEqual(backend.calls.count, 2)

        backend.failLast(.retry(statusCode: 503, retryAfterSeconds: nil))
        settle()
        XCTAssertEqual(scheduled.last?.delay, OSSessionRequestQueue.baseBackoffSeconds * 2)

        scheduled.last?.block()
        settle()
        XCTAssertEqual(backend.calls.count, 3)
    }

    func testRetryAfterIsHonoredByRetryNow() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()

        backend.failLast(.retry(statusCode: 429, retryAfterSeconds: 60))
        settle()
        XCTAssertEqual(scheduled.last?.delay, 60)

        now += 30
        queue.retryNow()
        settle()
        XCTAssertEqual(backend.calls.count, 1)
        XCTAssertEqual(scheduled.last?.delay, 30)

        now += 30
        queue.retryNow()
        settle()
        XCTAssertEqual(backend.calls.count, 2)
    }

    func testNetworkReturnRetries() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()
        backend.failLast(.retry(statusCode: 0, retryAfterSeconds: nil))
        settle()

        monitor.onAvailable?()
        settle()

        XCTAssertEqual(backend.calls.count, 2)
    }

    func testNetworkIsWatchedOnlyWhileRequestsArePending() {
        settle()
        XCTAssertNil(monitor.onAvailable)

        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()
        XCTAssertNotNil(monitor.onAvailable)

        backend.respondToLast(createdSessionId: "server-1")
        settle()
        XCTAssertNil(monitor.onAvailable)
    }

    func testDroppedAfterMaxAnsweredFailuresButNotForNoResponse() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        settle()

        for _ in 0..<10 {
            backend.failLast(.retry(statusCode: 0, retryAfterSeconds: nil))
            queue.retryNow()
            settle()
        }
        XCTAssertEqual(queue.queuedRequests.first?.failedAttempts, 0)

        for attempt in 1...OSSessionRequestQueue.maxFailedAttempts {
            backend.failLast(.retry(statusCode: 500, retryAfterSeconds: nil))
            queue.retryNow()
            settle()
            if attempt < OSSessionRequestQueue.maxFailedAttempts {
                XCTAssertEqual(queue.queuedRequests.first?.failedAttempts, attempt)
            }
        }
        XCTAssertTrue(queue.queuedRequests.isEmpty)
    }

    func testDropAtAttemptLimitStillHonorsRetryAfter() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        queue.enqueueCreate(record: startSession())
        settle()
        for _ in 1..<OSSessionRequestQueue.maxFailedAttempts {
            backend.failLast(.retry(statusCode: 500, retryAfterSeconds: nil))
            queue.retryNow()
            settle()
        }
        let calls = backend.calls.count

        backend.failLast(.retry(statusCode: 429, retryAfterSeconds: 60))
        settle()

        XCTAssertEqual(queue.queuedRequests.count, 1)
        XCTAssertEqual(backend.calls.count, calls)
        XCTAssertGreaterThanOrEqual(scheduled.last?.delay ?? 0, 60)

        now += 30
        queue.retryNow()
        settle()
        XCTAssertEqual(backend.calls.count, calls)

        now += 30
        queue.retryNow()
        settle()
        XCTAssertEqual(backend.calls.count, calls + 1)
    }

    func testNonRetryableFailureDropsCreateAndItsUpdates() {
        let record = startSession()
        queue.enqueueCreate(record: record)
        queue.enqueueUpdate(record: self.record(duration: 10, from: record))
        settle()

        backend.failLast(.drop(statusCode: 400))
        settle()

        XCTAssertTrue(queue.queuedRequests.isEmpty)
        XCTAssertEqual(backend.calls.count, 1)
    }

    func testEarlierSessionCreateDoesNotSetCurrentServerSessionId() {
        let first = startSession()
        queue.enqueueCreate(record: first)
        settle()
        _ = startSession()

        backend.respondToLast(createdSessionId: "server-1")
        settle()

        XCTAssertNil(service.currentRecord?.serverSessionId)
    }
}
