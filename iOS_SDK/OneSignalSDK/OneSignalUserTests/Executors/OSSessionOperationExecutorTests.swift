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
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalOSCore
@testable import OneSignalUser

/// Holds every Request until the test answers it.
private final class FakeSessionsClient: NSObject, IOneSignalClient {
    struct Call {
        let request: OneSignalRequest
        let onSuccess: OSResultSuccessBlock
        let onFailure: OSClientFailureBlock
    }

    private let lock = NSLock()
    private var _calls: [Call] = []

    var calls: [Call] { lock.withLock { _calls } }
    var requests: [OneSignalRequest] { calls.map(\.request) }

    func execute(_ request: OneSignalRequest, onSuccess: @escaping OSResultSuccessBlock, onFailure: @escaping OSClientFailureBlock) {
        lock.withLock { _calls.append(Call(request: request, onSuccess: onSuccess, onFailure: onFailure)) }
    }

    func succeedLast(_ response: [AnyHashable: Any]? = nil) {
        calls.last?.onSuccess(response)
    }

    func failLast(code: Int, headers: [String: String]? = nil) {
        calls.last?.onFailure(OneSignalClientError(code: code, message: "failure", responseHeaders: headers, response: nil, underlyingError: nil))
    }
}

final class OSSessionOperationExecutorTests: XCTestCase {
    private let externalId = "session-external-id"
    private let onesignalId = "session-onesignal-id"
    private var client: FakeSessionsClient!
    private var newRecordsState: MockNewRecordsState!
    private var user: OSUserInternal!
    private var uptime: TimeInterval = 1000
    private var retryBackoff: OSRequestRetryBackoff!

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OSSessionService.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"
        client = FakeSessionsClient()
        OneSignalCoreImpl.setSharedClient(client)
        newRecordsState = MockNewRecordsState()
        user = OneSignalUserMocks.setUserManagerInternalUser(externalId: externalId, onesignalId: onesignalId)
        uptime = 1000
        retryBackoff = OSRequestRetryBackoff(uptime: { [unowned self] in self.uptime }, jitter: { 1 })
    }

    override func tearDownWithError() throws {
        OSPrivacyConsentController.setRequiresPrivacyConsent(false)
        OSSessionService.reset()
        OneSignalCoreMocks.clearUserDefaults()
    }

    private func makeExecutor() -> OSSessionOperationExecutor {
        OSSessionOperationExecutor(
            newRecordsState: newRecordsState,
            auth: OneSignalUserManagerImpl.sharedInstance.requestAuth,
            retryBackoff: retryBackoff
        )
    }

    private func createDelta(session: String = "session-1", directAttributionId: String? = nil, identityModel: OSIdentityModel? = nil) -> OSDelta {
        var value: [String: Any] = [
            OSSessionDeltaKey.appId: "test-app-id",
            OSSessionDeltaKey.startTime: 1_700_000_000.0
        ]
        value[OSSessionDeltaKey.directAttributionId] = directAttributionId
        return delta(OS_CREATE_SESSION_DELTA, session: session, value: value, identityModel: identityModel)
    }

    /// A `serverSessionId` stands for a session record its create already filled, so it comes with the
    /// create's IDs.
    private func updateDelta(
        session: String = "session-1",
        duration: TimeInterval,
        endTime: TimeInterval? = nil,
        serverSessionId: String? = nil,
        subscriptionId: String = testPushSubId
    ) -> OSDelta {
        var value: [String: Any] = [
            OSSessionDeltaKey.appId: "test-app-id",
            OSSessionDeltaKey.activeDuration: duration,
            OSSessionDeltaKey.onesignalId: onesignalId,
            OSSessionDeltaKey.subscriptionId: subscriptionId
        ]
        value[OSSessionDeltaKey.endTime] = endTime
        value[OSSessionDeltaKey.serverSessionId] = serverSessionId
        return delta(OS_UPDATE_SESSION_DELTA, session: session, value: value, identityModel: nil)
    }

    private func delta(_ name: String, session: String, value: [String: Any], identityModel: OSIdentityModel?) -> OSDelta {
        let identityModel = identityModel ?? user.identityModel
        return OSDelta(name: name, identityModelId: identityModel.modelId, externalId: identityModel.externalId, model: identityModel, property: session, value: value)
    }

    /// Enqueues the Deltas, runs one flush, and waits for it.
    @discardableResult
    private func flush(_ executor: OSSessionOperationExecutor, _ deltas: OSDelta...) -> [OSSessionRequest] {
        deltas.forEach(executor.enqueueDelta)
        executor.processDeltaQueue(inBackground: false)
        return executor.queuedRequests
    }

    private func createSucceeds(_ executor: OSSessionOperationExecutor, serverSessionId: String = "server-1") {
        client.succeedLast(["data": ["session_id": serverSessionId]])
        _ = executor.queuedRequests
    }

    private func fail(_ executor: OSSessionOperationExecutor, code: Int, headers: [String: String]? = nil) {
        client.failLast(code: code, headers: headers)
        _ = executor.queuedRequests
    }

    // MARK: - Requests

    func testCreateSendsSessionBodyKeyedByLocalSessionId() throws {
        let executor = makeExecutor()

        flush(executor, createDelta(directAttributionId: "notification-id"))

        let request = try XCTUnwrap(client.requests.last as? OSRequestCreateSession)
        XCTAssertEqual(request.path, "apps/test-app-id/sessions")
        XCTAssertEqual(request.method, POST)
        XCTAssertEqual(request.parameters?["onesignal_id"] as? String, onesignalId)
        XCTAssertEqual(request.parameters?["subscription_id"] as? String, testPushSubId)
        XCTAssertEqual(request.parameters?["start_time"] as? String, "2023-11-14T22:13:20.000Z")
        XCTAssertEqual(request.parameters?["idempotency_key"] as? String, "session-1")
        XCTAssertEqual(request.parameters?["direct_attribution_id"] as? String, "notification-id")
    }

    func testCreateWaitsForItsUserToBeCreated() {
        user.identityModel.removeAliases([OS_ONESIGNAL_ID])
        let executor = makeExecutor()

        flush(executor, createDelta())
        XCTAssertTrue(client.requests.isEmpty)

        user.identityModel.addAliases([OS_ONESIGNAL_ID: onesignalId])
        flush(executor)
        XCTAssertEqual((client.requests.last as? OSRequestCreateSession)?.parameters?["onesignal_id"] as? String, onesignalId)
    }

    func testUpdateWaitsForTheCreateThenUsesItsServerSessionId() throws {
        let executor = makeExecutor()
        flush(executor, createDelta(), updateDelta(duration: 42, endTime: 1_700_000_100))
        XCTAssertEqual(client.requests.count, 1)

        createSucceeds(executor)
        flush(executor)

        let update = try XCTUnwrap(client.requests.last as? OSRequestUpdateSession)
        XCTAssertEqual(update.path, "apps/test-app-id/sessions/server-1")
        XCTAssertEqual(update.method, PATCH)
        XCTAssertEqual(update.parameters?["duration_seconds"] as? Int64, 42)
        XCTAssertEqual(update.parameters?["end_time"] as? String, "2023-11-14T22:15:00.000Z")
        XCTAssertEqual(update.parameters?["idempotency_key"] as? String, update.idempotencyKey)
    }

    func testUpdateWaitsOutThePostCreateDelay() {
        newRecordsState.holdWhilePresent = true
        let executor = makeExecutor()
        flush(executor, createDelta(), updateDelta(duration: 10))

        createSucceeds(executor)
        flush(executor)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertFalse(newRecordsState.canAccess("server-1"))
    }

    func testUpdateBuiltAfterItsCreateSucceededGetsTheServerSessionId() {
        let executor = makeExecutor()
        flush(executor, createDelta())
        createSucceeds(executor)

        flush(executor, updateDelta(duration: 10))

        XCTAssertEqual((client.requests.last as? OSRequestUpdateSession)?.createdSession?.serverSessionId, "server-1")
    }

    func testUpdatesCarryTheIdsTheCreateSent() throws {
        OSSessionService.shared.startNewSession(userProvider: OneSignalUserManagerImpl.sharedInstance)
        let sessionId = try XCTUnwrap(OSSessionService.shared.currentRecord?.sessionId)
        let executor = makeExecutor()
        flush(executor, createDelta(session: sessionId), updateDelta(session: sessionId, duration: 10, subscriptionId: "other-subscription-id"))
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = "new-subscription-id"

        createSucceeds(executor)
        flush(executor, updateDelta(session: sessionId, duration: 20, subscriptionId: "other-subscription-id"))

        let update = try XCTUnwrap(client.requests.last as? OSRequestUpdateSession)
        XCTAssertEqual(update.parameters?["onesignal_id"] as? String, onesignalId)
        XCTAssertEqual(update.parameters?["subscription_id"] as? String, testPushSubId)
        let record = try XCTUnwrap(OSSessionService.shared.currentRecord)
        XCTAssertEqual(record.serverSessionId, "server-1")
        XCTAssertEqual(record.subscriptionId, testPushSubId)
    }

    func testNothingIsSentBeforePrivacyConsent() {
        OSPrivacyConsentController.setRequiresPrivacyConsent(true)
        let executor = makeExecutor()

        flush(executor, createDelta())
        let manager = OneSignalUserManagerImpl.sharedInstance
        manager.enqueueSessionCreate(OSSessionRecord(
            sessionId: "session-2",
            startTime: 1_700_000_000,
            activeDuration: 0,
            usesSessionsApi: true,
            identityModelId: user.identityModel.modelId,
            onesignalId: nil,
            subscriptionId: nil,
            serverSessionId: nil
        ))
        manager.operationRepo.dispatchQueue.sync {}

        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertFalse(manager.operationRepo.deltaQueue.contains { $0.name == OS_CREATE_SESSION_DELTA })
    }

    // MARK: - Coalescing

    func testUpdatesCoalesceToTheHighestDuration() {
        let executor = makeExecutor()

        let queued = flush(executor, createDelta(), updateDelta(duration: 10), updateDelta(duration: 5))

        let updates = queued.compactMap { $0 as? OSRequestUpdateSession }
        XCTAssertEqual(updates.map(\.activeDuration), [10])
    }

    func testUpdateAfterASentEndIsDiscarded() {
        let executor = makeExecutor()
        flush(executor, updateDelta(duration: 20, endTime: 1_700_000_100, serverSessionId: "server-1"))
        client.succeedLast()

        let queued = flush(executor, updateDelta(duration: 30, serverSessionId: "server-1"))

        XCTAssertTrue(queued.isEmpty)
        XCTAssertEqual(client.requests.count, 1)
    }

    func testEndReplacesQueuedUpdatesAndLaterUpdatesAreDiscarded() {
        let executor = makeExecutor()

        let queued = flush(executor, createDelta(), updateDelta(duration: 10), updateDelta(duration: 20, endTime: 1_700_000_100), updateDelta(duration: 30))

        let updates = queued.compactMap { $0 as? OSRequestUpdateSession }
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates.first?.activeDuration, 20)
        XCTAssertTrue(updates.first?.isEnd == true)
    }

    func testUpdateInFlightCountsTowardTheHighestDuration() {
        let executor = makeExecutor()
        flush(executor, updateDelta(duration: 30, serverSessionId: "server-1"))
        XCTAssertEqual(client.requests.count, 1)

        let queued = flush(executor, updateDelta(duration: 20))

        XCTAssertEqual(queued.compactMap { $0 as? OSRequestUpdateSession }.map(\.activeDuration), [30, 30])
    }

    func testUpdateWithoutACreateOrServerSessionIdIsDiscarded() {
        let executor = makeExecutor()

        XCTAssertTrue(flush(executor, updateDelta(duration: 10)).isEmpty)
    }

    func testCapDropsTheOldestCreateWithItsUpdates() {
        user.identityModel.removeAliases([OS_ONESIGNAL_ID])
        let executor = makeExecutor()
        flush(executor, createDelta(session: "oldest"), updateDelta(session: "oldest", duration: 10))

        let deltas = (0..<OSSessionOperationExecutor.maxQueuedRequests).map { createDelta(session: "session-\($0)") }
        deltas.forEach(executor.enqueueDelta)
        let queued = flush(executor)

        XCTAssertEqual(queued.count, OSSessionOperationExecutor.maxQueuedRequests)
        XCTAssertFalse(queued.contains { $0.localSessionId == "oldest" })
    }

    // MARK: - Retries

    func testRetryableFailureIsRetriedInTheSameRunAfterBackoff() throws {
        let executor = makeExecutor()
        flush(executor, createDelta())
        fail(executor, code: 500)

        flush(executor)
        XCTAssertEqual(client.requests.count, 1, "Sent again before the backoff passed")

        uptime += OSRequestRetryBackoff.baseDelaySeconds
        flush(executor)
        XCTAssertEqual(client.requests.count, 2)
        let retried = try XCTUnwrap(client.requests.last as? OSRequestCreateSession)
        XCTAssertEqual(retried.parameters?["idempotency_key"] as? String, "session-1")
    }

    func testRetryAfterIsHonored() {
        let executor = makeExecutor()
        flush(executor, createDelta())
        fail(executor, code: 429, headers: ["Retry-After": "120"])

        uptime += 119
        flush(executor)
        XCTAssertEqual(client.requests.count, 1)

        uptime += 1
        flush(executor)
        XCTAssertEqual(client.requests.count, 2)
    }

    func testRetryNowEndsTheBackoffEarly() {
        let executor = makeExecutor()
        flush(executor, createDelta())
        fail(executor, code: 500)

        retryBackoff.retryNow()
        flush(executor)

        XCTAssertEqual(client.requests.count, 2)
    }

    func testRetryNowStillWaitsOutRetryAfter() {
        let executor = makeExecutor()
        flush(executor, createDelta())
        fail(executor, code: 429, headers: ["Retry-After": "120"])

        retryBackoff.retryNow()
        flush(executor)
        XCTAssertEqual(client.requests.count, 1)

        uptime += 120
        flush(executor)
        XCTAssertEqual(client.requests.count, 2)
    }

    func testReplacingAnUpdateKeepsItsBackoff() {
        let executor = makeExecutor()
        flush(executor, updateDelta(duration: 10, serverSessionId: "server-1"))
        fail(executor, code: 500)

        flush(executor, updateDelta(duration: 20))
        XCTAssertEqual(client.requests.count, 1, "The replacement skipped the backoff")

        uptime += OSRequestRetryBackoff.baseDelaySeconds
        flush(executor)
        XCTAssertEqual((client.requests.last as? OSRequestUpdateSession)?.activeDuration, 20)
    }

    func testOther4xxDropsTheCreateWithItsUpdates() {
        let executor = makeExecutor()
        flush(executor, createDelta(), updateDelta(duration: 10))

        fail(executor, code: 400)

        XCTAssertTrue(executor.queuedRequests.isEmpty)
    }

    func testCreateSuccessWithoutASessionIdIsRetriedWithTheSameKey() throws {
        let executor = makeExecutor()
        flush(executor, createDelta())

        client.succeedLast(["data": [:]])
        flush(executor)
        XCTAssertEqual(client.requests.count, 1, "Sent again before the backoff passed")

        uptime += OSRequestRetryBackoff.baseDelaySeconds
        flush(executor)
        let retried = try XCTUnwrap(client.requests.last as? OSRequestCreateSession)
        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(retried.parameters?["idempotency_key"] as? String, "session-1")
    }

    func testCreateWithoutASessionIdIsDroppedWithItsUpdatesAfterTheCap() {
        let executor = makeExecutor()
        flush(executor, createDelta(), updateDelta(duration: 10))

        for _ in 0..<OSSessionOperationExecutor.maxMissingSessionIdAttempts {
            client.succeedLast(["data": [:]])
            _ = executor.queuedRequests
            uptime += OSRequestRetryBackoff.maxDelaySeconds
            flush(executor)
        }

        XCTAssertTrue(executor.queuedRequests.isEmpty)
        XCTAssertEqual(client.requests.count, OSSessionOperationExecutor.maxMissingSessionIdAttempts)
    }

    func testUpdateWithAnUnparsableSuccessBodyCompletes() {
        let executor = makeExecutor()
        flush(executor, updateDelta(duration: 10, serverSessionId: "server-1"))

        fail(executor, code: 202)

        XCTAssertTrue(executor.queuedRequests.isEmpty)
    }

}

// MARK: - Persistence and ownership

extension OSSessionOperationExecutorTests {

    func testQueuedRequestsSurviveARestartWithTheSameKeys() throws {
        let executor = makeExecutor()
        flush(executor, createDelta(), updateDelta(duration: 10))
        fail(executor, code: 500)
        let key = try XCTUnwrap(executor.queuedRequests.compactMap { $0 as? OSRequestUpdateSession }.first?.idempotencyKey)

        let restored = makeExecutor().queuedRequests

        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual((restored.last as? OSRequestUpdateSession)?.idempotencyKey, key)
    }

    func testACreateKeepsItsSentIdsAcrossAKillBeforeTheResponse() throws {
        let executor = makeExecutor()
        flush(executor, createDelta())
        XCTAssertEqual(client.requests.count, 1)
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = "new-subscription-id"

        let restored = try XCTUnwrap(makeExecutor().queuedRequests.first as? OSRequestCreateSession)

        XCTAssertEqual(restored.onesignalId, onesignalId)
        XCTAssertEqual(restored.subscriptionId, testPushSubId)
    }

    func testRequestForAnotherAppIsDropped() {
        user.identityModel.removeAliases([OS_ONESIGNAL_ID])
        let executor = makeExecutor()
        flush(executor, createDelta())

        OneSignalIdentifiers.currentAppId = "other-app-id"

        XCTAssertTrue(flush(executor).isEmpty)
    }

    func testAnonymousRequestsThatCanStillBeSentAreKeptUnderIdentityVerification() {
        user.identityModel.removeAliases([OS_ONESIGNAL_ID])
        let createdAnonymous = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: "anonymous-onesignal-id"], changeNotifier: OSEventProducer())
        let neverCreated = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(createdAnonymous)
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(neverCreated)
        newRecordsState.holdWhilePresent = true
        newRecordsState.add("anonymous-onesignal-id")
        let executor = makeExecutor()
        flush(
            executor,
            createDelta(session: "identified"),
            createDelta(session: "created-anonymous", identityModel: createdAnonymous),
            createDelta(session: "never-created", identityModel: neverCreated),
            updateDelta(session: "never-created", duration: 10)
        )

        executor.removeOperationsWithoutExternalId()

        XCTAssertEqual(executor.queuedRequests.map(\.localSessionId), ["identified", "created-anonymous"])
    }

}

// MARK: - Enqueueing

extension OSSessionOperationExecutorTests {

    func testEnqueueIsANoOpWhenTheSessionDoesNotUseTheSessionsApi() {
        let manager = OneSignalUserManagerImpl.sharedInstance
        let record = { (usesSessionsApi: Bool) in
            OSSessionRecord(
                sessionId: "session-1",
                startTime: 1_700_000_000,
                activeDuration: 0,
                usesSessionsApi: usesSessionsApi,
                identityModelId: self.user.identityModel.modelId,
                onesignalId: nil,
                subscriptionId: nil,
                serverSessionId: nil
            )
        }

        manager.enqueueSessionCreate(record(false))
        manager.enqueueSessionCreate(record(true))
        manager.operationRepo.dispatchQueue.sync {}

        let sessionDeltas = manager.operationRepo.deltaQueue.filter { $0.name == OS_CREATE_SESSION_DELTA }
        XCTAssertEqual(sessionDeltas.count, 1)
        XCTAssertEqual(sessionDeltas.first?.property, "session-1")
        XCTAssertEqual(sessionDeltas.first?.externalId, externalId)
    }
}
