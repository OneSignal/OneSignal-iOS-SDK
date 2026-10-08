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

/// Persisted queue of sessions API requests. A request is saved before it is sent and removed only
/// once the backend accepts it or rejects it for good, so it survives restarts and offline periods.
/// Requests for a session go out in order, one at a time across the queue.
@objc(OSSessionRequestQueue)
public final class OSSessionRequestQueue: NSObject {
    static let maxQueuedRequests = 100
    static let maxFailedAttempts = 5
    static let baseBackoffSeconds: TimeInterval = 5
    static let maxBackoffSeconds: TimeInterval = 300

    private static let lock = NSLock()
    private static var _shared: OSSessionRequestQueue?

    public static var shared: OSSessionRequestQueue {
        lock.withLock {
            if let existing = _shared {
                return existing
            }
            let created = OSSessionRequestQueue()
            _shared = created
            return created
        }
    }

    @objc public static func reset() {
        let retired = lock.withLock {
            let existing = _shared
            _shared = nil
            return existing
        }
        retired?.retire()
    }

    /// Saved requests carry the previous app's ID, so they must not outlive an app-id change.
    @objc public static func resetAndClearStoredQueue() {
        // Under the lock, so a new queue cannot load the old requests before they are removed.
        lock.withLock {
            _shared?.retire()
            _shared = nil
            OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_REQUEST_QUEUE)
        }
    }

    private let storage: OneSignalUserDefaults
    private let backend: OSSessionsBackend
    private let sessionService: () -> OSSessionService
    private let appId: () -> String?
    private let networkMonitor: OSSessionNetworkMonitoring
    private let now: () -> TimeInterval
    private let jitter: () -> Double
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    private let postCreateDelay: TimeInterval

    // Serial. Synchronizes all state below.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSSessionRequestQueue", target: .global())

    private var requests: [OSSessionRequest] = []
    private var inFlightKey: String?
    /// Lets an update enqueued while its create was in flight pick up the backend session ID.
    private var serverSessionIds: [String: String] = [:]
    private var consecutiveFailures = 0
    private var isBackingOff = false
    private var backoffGeneration = 0
    /// A backend `Retry-After` that `retryNow` must not cut short, on the `now` clock.
    private var notBefore: TimeInterval = 0
    /// Updates for a just-created session wait until this time, on the `now` clock, so the backend
    /// has replicated the session before it is patched.
    private var updatesAllowedAt: [String: TimeInterval] = [:]
    /// Set once the queue is replaced, so a late completion cannot write its requests back.
    private var isRetired = false

    init(
        storage: OneSignalUserDefaults = .initStandard(),
        backend: OSSessionsBackend = OSSessionsBackendService(),
        sessionService: @escaping () -> OSSessionService = { .shared },
        appId: @escaping () -> String? = { OneSignalIdentifiers.currentAppId },
        networkMonitor: OSSessionNetworkMonitoring = OSSessionNetworkMonitor(),
        // The same clock as `DispatchTime`, so `notBefore` agrees with the scheduled retry.
        now: @escaping () -> TimeInterval = {
            TimeInterval(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / TimeInterval(NSEC_PER_SEC)
        },
        jitter: @escaping () -> Double = { Double.random(in: 0.5...1) },
        schedule: ((TimeInterval, @escaping () -> Void) -> Void)? = nil,
        postCreateDelay: TimeInterval = TimeInterval(OP_REPO_POST_CREATE_DELAY_SECONDS)
    ) {
        self.storage = storage
        self.backend = backend
        self.sessionService = sessionService
        self.appId = appId
        self.networkMonitor = networkMonitor
        self.now = now
        self.jitter = jitter
        self.postCreateDelay = postCreateDelay
        let dispatchQueue = self.dispatchQueue
        self.schedule = schedule ?? { delay, block in
            dispatchQueue.asyncAfter(deadline: .now() + delay, execute: block)
        }
        super.init()
        dispatchQueue.async {
            self.load()
            self.updateNetworkMonitoring()
            self.processNext()
        }
    }

    private func retire() {
        dispatchQueue.sync {
            isRetired = true
            networkMonitor.stop()
        }
    }
}

// MARK: - Enqueue

extension OSSessionRequestQueue {
    func enqueueCreate(record: OSSessionRecord, directAttributionId: String? = nil) {
        guard record.usesSessionsApi, let appId = appId() else {
            return
        }
        let request = OSSessionRequest(
            appId: appId,
            localSessionId: record.sessionId,
            serverSessionId: nil,
            identityModelId: record.identityModelId,
            onesignalId: record.onesignalId,
            subscriptionId: record.subscriptionId,
            kind: .create(startTime: record.startTime, directAttributionId: directAttributionId),
            // Derived from the session, so a create enqueued again after being dropped is still deduplicated.
            idempotencyKey: record.sessionId
        )
        dispatchQueue.async {
            let isCreated = record.serverSessionId != nil || self.serverSessionIds[record.sessionId] != nil
            guard !isCreated, !self.requests.contains(where: { $0.isCreate && $0.localSessionId == record.sessionId }) else {
                return
            }
            self.append(request)
        }
    }

    /// Reports the session's cumulative duration, and ends the session when `endTime` is set.
    func enqueueUpdate(record: OSSessionRecord, endTime: TimeInterval? = nil) {
        guard record.usesSessionsApi, let appId = appId() else {
            return
        }
        var request = OSSessionRequest(
            appId: appId,
            localSessionId: record.sessionId,
            serverSessionId: record.serverSessionId,
            identityModelId: record.identityModelId,
            onesignalId: record.onesignalId,
            subscriptionId: record.subscriptionId,
            kind: .update(activeDuration: record.activeDuration, endTime: endTime),
            idempotencyKey: UUID().uuidString
        )
        dispatchQueue.async {
            guard self.admitUpdate(&request) else {
                return
            }
            self.append(request)
        }
    }

    /// Folds queued, unsent updates for the same session into `request`, which then carries the
    /// highest duration. An update that ends the session replaces them the same way.
    /// Returns false if `request` should be discarded: its session's end is already queued, or it
    /// has no backend session ID and no create remains to supply one.
    private func admitUpdate(_ request: inout OSSessionRequest) -> Bool {
        let session = requests.filter { $0.localSessionId == request.localSessionId }
        request.serverSessionId = request.serverSessionId ?? serverSessionIds[request.localSessionId]
        let hasEnd = session.contains { $0.isEnd }
        let isOrphaned = request.serverSessionId == nil && !session.contains { $0.isCreate }
        if hasEnd || isOrphaned {
            OneSignalLog.onesignalLog(
                .LL_DEBUG,
                message: "OSSessionRequestQueue discarding update for \(request.localSessionId), ended: \(hasEnd), never created: \(isOrphaned)"
            )
            return false
        }

        // An in-flight update counts toward the highest duration, so a stale snapshot cannot lower it.
        if case .update(let activeDuration, let endTime) = request.kind {
            let highest = session.compactMap(\.activeDuration).max() ?? activeDuration
            request.kind = .update(activeDuration: max(activeDuration, highest), endTime: endTime)
        }
        let queued = session.filter { !$0.isCreate && $0.idempotencyKey != inFlightKey }
        guard !queued.isEmpty else {
            return true
        }
        let removedKeys = Set(queued.map(\.idempotencyKey))
        requests.removeAll { removedKeys.contains($0.idempotencyKey) }
        // An unchanged body keeps its key, so a retry the backend may already have applied stays
        // deduplicated. Either way the attempts carry over, or a session that keeps reporting
        // would never reach the drop limit.
        let failedAttempts = queued.map(\.failedAttempts).max() ?? 0
        if let unchanged = queued.first(where: { $0.kind == request.kind }) {
            let incoming = request
            request = unchanged
            request.serverSessionId = unchanged.serverSessionId ?? incoming.serverSessionId
            request.onesignalId = unchanged.onesignalId ?? incoming.onesignalId
            request.subscriptionId = unchanged.subscriptionId ?? incoming.subscriptionId
        }
        request.failedAttempts = max(request.failedAttempts, failedAttempts)
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionRequestQueue coalesced \(queued.count) update(s) for \(request.localSessionId)")
        return true
    }

    private func append(_ request: OSSessionRequest) {
        requests.append(request)
        enforceCap()
        persist()
        updateNetworkMonitoring()
        processNext()
    }

    private func enforceCap() {
        while requests.count > Self.maxQueuedRequests,
              let oldest = requests.first(where: { $0.idempotencyKey != inFlightKey }) {
            OneSignalLog.onesignalLog(
                .LL_WARN,
                message: "OSSessionRequestQueue more than \(Self.maxQueuedRequests) requests queued, dropping oldest: \(oldest.logDescription)"
            )
            remove(oldest)
        }
    }

    /// Updates for a session whose create is removed without succeeding can never get a backend
    /// session ID, so they go with it.
    private func remove(_ request: OSSessionRequest) {
        requests.removeAll { $0.idempotencyKey == request.idempotencyKey }
        guard request.isCreate else {
            return
        }
        let orphans = requests.filter { $0.localSessionId == request.localSessionId && $0.serverSessionId == nil }
        guard !orphans.isEmpty else {
            return
        }
        OneSignalLog.onesignalLog(
            .LL_WARN,
            message: "OSSessionRequestQueue dropping \(orphans.count) update(s) for session \(request.localSessionId), which was never created"
        )
        let orphanKeys = Set(orphans.map(\.idempotencyKey))
        requests.removeAll { orphanKeys.contains($0.idempotencyKey) }
    }
}

// MARK: - Sending

extension OSSessionRequestQueue {
    /// Ends the failure backoff early, but still waits out a backend `Retry-After`.
    @objc public func retryNow() {
        dispatchQueue.async {
            if self.isBackingOff {
                let remaining = self.notBefore - self.now()
                guard remaining <= 0 else {
                    self.scheduleRetry(after: remaining)
                    return
                }
                self.backoffGeneration += 1
                self.isBackingOff = false
            }
            self.processNext()
        }
    }

    /// Sends what has become ready, such as a request that was waiting on IDs. Unlike `retryNow`,
    /// it leaves a failure backoff running, since it is called far more often than the app opens.
    public func processPending() {
        dispatchQueue.async {
            self.processNext()
        }
    }

    private func processNext() {
        guard !isRetired else {
            return
        }
        dropUnsendable()
        guard inFlightKey == nil, !isBackingOff else {
            return
        }
        var startedSessions = Set<String>()
        for index in requests.indices {
            let sessionId = requests[index].localSessionId
            // Only the first request for a session may go out, which keeps create, updates, end in order.
            guard startedSessions.insert(sessionId).inserted else {
                continue
            }
            if let request = readyRequest(at: index) {
                send(request)
                return
            }
        }
    }

    /// A create still waiting on a `onesignal_id` its user will never get, which happens to an
    /// anonymous user under required Identity Verification. Its updates go with it.
    private func dropUnsendable() {
        let service = sessionService()
        let unsendable = requests.filter {
            $0.isCreate && $0.onesignalId == nil && $0.idempotencyKey != inFlightKey
                && !service.canCreateUser(identityModelId: $0.identityModelId)
        }
        guard !unsendable.isEmpty else {
            return
        }
        OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionRequestQueue dropping \(unsendable.count) create(s) for a user that is never created")
        unsendable.forEach(remove)
        persist()
        updateNetworkMonitoring()
    }

    private func readyRequest(at index: Int) -> OSSessionRequest? {
        var request = requests[index]
        if request.onesignalId == nil || request.subscriptionId == nil {
            (request.onesignalId, request.subscriptionId) = sessionService().pinnedIds(
                sessionId: request.localSessionId,
                identityModelId: request.identityModelId,
                onesignalId: request.onesignalId,
                subscriptionId: request.subscriptionId
            )
            if request != requests[index] {
                requests[index] = request
                persist()
            }
        }
        guard request.onesignalId != nil, request.subscriptionId != nil else {
            return nil
        }
        if !request.isCreate {
            guard request.serverSessionId != nil else {
                return nil
            }
            if let allowedAt = updatesAllowedAt[request.localSessionId], now() < allowedAt {
                return nil
            }
        }
        return request
    }

    private func send(_ request: OSSessionRequest) {
        guard let onesignalId = request.onesignalId, let subscriptionId = request.subscriptionId else {
            return
        }
        let backgroundTaskIdentifier = "OSSessionRequestQueue" + UUID().uuidString
        let finish: (OSSessionsApiResult<String?>) -> Void = { result in
            self.dispatchQueue.async {
                self.handle(result, for: request)
                OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
            }
        }

        switch request.kind {
        case .create(let startTime, let directAttributionId):
            let body = OSCreateSessionRequestBody(
                onesignalId: onesignalId,
                subscriptionId: subscriptionId,
                startTime: Date(timeIntervalSince1970: startTime),
                idempotencyKey: request.idempotencyKey,
                directAttributionId: directAttributionId
            )
            inFlightKey = request.idempotencyKey
            OSBackgroundTaskManager.beginBackgroundTask(backgroundTaskIdentifier)
            backend.createSession(appId: request.appId, body: body) { finish($0.map { $0 }) }
        case .update(let activeDuration, let endTime):
            guard let serverSessionId = request.serverSessionId else {
                return
            }
            let body = OSUpdateSessionRequestBody(
                onesignalId: onesignalId,
                subscriptionId: subscriptionId,
                durationSeconds: Int64(activeDuration),
                idempotencyKey: request.idempotencyKey,
                endTime: endTime.map { Date(timeIntervalSince1970: $0) }
            )
            inFlightKey = request.idempotencyKey
            OSBackgroundTaskManager.beginBackgroundTask(backgroundTaskIdentifier)
            backend.updateSession(appId: request.appId, sessionId: serverSessionId, body: body) { finish($0.map { nil }) }
        }
    }

    private func handle(_ result: OSSessionsApiResult<String?>, for sent: OSSessionRequest) {
        guard !isRetired else {
            return
        }
        inFlightKey = nil
        guard let index = requests.firstIndex(where: { $0.idempotencyKey == sent.idempotencyKey }) else {
            processNext()
            return
        }
        var request = requests[index]

        switch result {
        case .success(let serverSessionId):
            consecutiveFailures = 0
            requests.remove(at: index)
            if let serverSessionId {
                applyServerSessionId(serverSessionId, from: request)
            }
        case .drop(let statusCode):
            consecutiveFailures = 0
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionRequestQueue dropping after a \(statusCode): \(request.logDescription)")
            remove(request)
        case .retry(let statusCode, let retryAfterSeconds):
            // 0 means no response, e.g. offline, which must keep retrying until the network returns.
            if statusCode != 0 {
                request.failedAttempts += 1
            }
            if request.failedAttempts >= Self.maxFailedAttempts {
                OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionRequestQueue dropping after too many failures: \(request.logDescription)")
                remove(request)
            } else {
                requests[index] = request
            }
            persist()
            updateNetworkMonitoring()
            // A dropped request still honors `Retry-After`, which applies to the next request too.
            if request.failedAttempts < Self.maxFailedAttempts || retryAfterSeconds != nil {
                backOff(retryAfterSeconds: retryAfterSeconds)
            } else {
                processNext()
            }
            return
        }
        persist()
        updateNetworkMonitoring()
        processNext()
    }

    private func applyServerSessionId(_ serverSessionId: String, from create: OSSessionRequest) {
        serverSessionIds[create.localSessionId] = serverSessionId
        for index in requests.indices where requests[index].localSessionId == create.localSessionId {
            requests[index].serverSessionId = serverSessionId
            requests[index].onesignalId = requests[index].onesignalId ?? create.onesignalId
            requests[index].subscriptionId = requests[index].subscriptionId ?? create.subscriptionId
        }
        sessionService().setServerSessionId(serverSessionId, forSessionId: create.localSessionId)
        guard postCreateDelay > 0 else {
            return
        }
        updatesAllowedAt[create.localSessionId] = now() + postCreateDelay
        schedule(postCreateDelay) { [weak self] in
            self?.processPending()
        }
    }
}

// MARK: - Backoff

extension OSSessionRequestQueue {
    private func backOff(retryAfterSeconds: Int?) {
        consecutiveFailures += 1
        let exponential = min(Self.maxBackoffSeconds, Self.baseBackoffSeconds * pow(2, Double(consecutiveFailures - 1)))
        let retryAfter = TimeInterval(retryAfterSeconds ?? 0)
        notBefore = now() + retryAfter
        isBackingOff = true
        scheduleRetry(after: max(exponential * jitter(), retryAfter))
    }

    private func scheduleRetry(after delay: TimeInterval) {
        backoffGeneration += 1
        let generation = backoffGeneration
        schedule(delay) { [weak self] in
            guard let self else {
                return
            }
            self.dispatchQueue.async {
                guard self.backoffGeneration == generation else {
                    return
                }
                self.isBackingOff = false
                self.processNext()
            }
        }
    }
}

// MARK: - Storage

extension OSSessionRequestQueue {
    private func load() {
        guard let data = storage.getSavedObject(forKey: OSUD_SESSION_REQUEST_QUEUE, defaultValue: nil) as? Data else {
            return
        }
        do {
            requests = try JSONDecoder().decode([OSSessionRequest].self, from: data)
            for request in requests {
                if let serverSessionId = request.serverSessionId {
                    serverSessionIds[request.localSessionId] = serverSessionId
                }
            }
        } catch {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSessionRequestQueue failed to read saved requests: \(error)")
        }
    }

    private func persist() {
        guard !isRetired, let data = try? JSONEncoder().encode(requests) else {
            return
        }
        storage.saveObject(forKey: OSUD_SESSION_REQUEST_QUEUE, withValue: data)
    }

    /// Only watched while requests are pending, so with the flag off nothing changes.
    private func updateNetworkMonitoring() {
        if requests.isEmpty {
            networkMonitor.stop()
        } else {
            networkMonitor.start { [weak self] in self?.retryNow() }
        }
    }
}

// MARK: - Testing

extension OSSessionRequestQueue {
    func waitUntilIdle() {
        dispatchQueue.sync {}
    }

    func retireForTesting() {
        retire()
    }

    var queuedRequests: [OSSessionRequest] {
        dispatchQueue.sync { requests }
    }
}
