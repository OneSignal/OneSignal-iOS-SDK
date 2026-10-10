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
import OneSignalOSCore

/// Keys of the value an `OS_CREATE_SESSION_DELTA` or `OS_UPDATE_SESSION_DELTA` carries. The Delta's
/// `property` is the local session ID.
enum OSSessionDeltaKey {
    static let appId = "app_id"
    static let startTime = "start_time"
    static let directAttributionId = "direct_attribution_id"
    static let activeDuration = "active_duration"
    static let endTime = "end_time"
    static let onesignalId = "onesignal_id"
    static let subscriptionId = "subscription_id"
    static let serverSessionId = "server_session_id"
}

/**
 Sends sessions API Requests: a session's create, then its updates once the create returns the server
 session ID. Only the first queued Request of a session is sent, so they reach the backend in order.

 Unlike the other executors, a failed Request is retried in the same run, on a later flush once its
 backoff has passed, rather than waiting for a relaunch.
 */
class OSSessionOperationExecutor: OSOperationExecutor {
    static let maxQueuedRequests = 100
    static let maxFailedAttempts = 5
    static let baseBackoffSeconds: TimeInterval = 5
    static let maxBackoffSeconds: TimeInterval = 300
    static let defaultRetryAfterSeconds: TimeInterval = 60

    var supportedDeltas: [String] = [OS_CREATE_SESSION_DELTA, OS_UPDATE_SESSION_DELTA]
    private var deltaQueue: [OSDelta] = []
    private var requestQueue: [OSSessionRequest] = []
    /// By local session ID, for an update built after its create already succeeded.
    private var serverSessionIds: [String: String] = [:]
    private let newRecordsState: OSNewRecordsState
    private let auth: OSRequestAuthorizing
    private let nowProvider: () -> Date
    private let uptime: () -> TimeInterval
    private let jitter: () -> Double

    // The executor dispatch queue, serial. This synchronizes access to `deltaQueue` and `requestQueue`.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSSessionOperationExecutor", target: .global())

    init(
        newRecordsState: OSNewRecordsState,
        auth: OSRequestAuthorizing,
        nowProvider: @escaping () -> Date = { Date() },
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        jitter: @escaping () -> Double = { Double.random(in: 0.5...1) }
    ) {
        self.newRecordsState = newRecordsState
        self.auth = auth
        self.nowProvider = nowProvider
        self.uptime = uptime
        self.jitter = jitter
        uncacheDeltas()
        uncacheRequests()
    }

    private func uncacheDeltas() {
        guard var deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_SESSION_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: [], maxBytes: UInt(OS_USER_DEFAULTS_MAX_VALUE_BYTES)) as? [OSDelta] else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSessionOperationExecutor error encountered reading from cache for \(OS_SESSION_EXECUTOR_DELTA_QUEUE_KEY)")
            return
        }
        deltaQueue.removeAll { delta in
            guard OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId) == nil else {
                return false
            }
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor.init dropped: \(delta)")
            return true
        }
        self.deltaQueue = deltaQueue
        cacheDeltas()
    }

    private func uncacheRequests() {
        guard let cached = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_SESSION_EXECUTOR_REQUEST_QUEUE_KEY, defaultValue: [], maxBytes: UInt(OS_USER_DEFAULTS_MAX_VALUE_BYTES)) as? [Any] else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSessionOperationExecutor error encountered reading from cache for \(OS_SESSION_EXECUTOR_REQUEST_QUEUE_KEY)")
            return
        }
        // Hook each uncached Request to the model in the store
        requestQueue = cached.compactMap { $0 as? OSSessionRequest }.filter { request in
            if let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(request.identityModel.modelId) {
                request.identityModel = identityModel
                return true
            }
            if request.identityModel.onesignalId != nil {
                // Its user is no longer loaded but was created, so the Request can still be sent
                OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(request.identityModel)
                return true
            }
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor.init dropped: \(request)")
            return false
        }
        removeOrphanedUpdates()
        for case let update as OSRequestUpdateSession in requestQueue {
            serverSessionIds[update.localSessionId] = update.serverSessionId ?? serverSessionIds[update.localSessionId]
        }
        cacheRequests()
    }

    func enqueueDelta(_ delta: OSDelta) {
        self.dispatchQueue.async {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSSessionOperationExecutor enqueue delta \(delta)")
            self.deltaQueue.append(delta)
        }
    }

    func cacheDeltaQueue() {
        self.dispatchQueue.async {
            self.cacheDeltas()
        }
    }

    /// The sessions API takes no user JWT, so Identity Verification does not apply to session Requests.
    func removeOperationsWithoutExternalId() {}

    func processDeltaQueue(inBackground: Bool) {
        self.dispatchQueue.async {
            if !self.deltaQueue.isEmpty {
                OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSSessionOperationExecutor processDeltaQueue with queue: \(self.deltaQueue)")
                for delta in self.deltaQueue {
                    if let request = self.makeRequest(from: delta) {
                        self.admit(request)
                    }
                }
                self.deltaQueue.removeAll()
                self.cacheRequests()
                self.cacheDeltas()
            }
            self.processRequestQueue(inBackground: inBackground)
        }
    }

    /// The Requests waiting to be sent, for tests.
    var queuedRequests: [OSSessionRequest] {
        dispatchQueue.sync { requestQueue }
    }

    private func cacheDeltas() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SESSION_EXECUTOR_DELTA_QUEUE_KEY, withValue: deltaQueue)
    }

    private func cacheRequests() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SESSION_EXECUTOR_REQUEST_QUEUE_KEY, withValue: requestQueue)
    }
}

// MARK: - Queueing

private extension OSSessionOperationExecutor {
    func makeRequest(from delta: OSDelta) -> OSSessionRequest? {
        guard let value = delta.value as? [String: Any],
              let appId = value[OSSessionDeltaKey.appId] as? String,
              let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId)
        else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSessionOperationExecutor.processDeltaQueue dropped: \(delta)")
            return nil
        }
        let localSessionId = delta.property
        let onesignalId = value[OSSessionDeltaKey.onesignalId] as? String
        let subscriptionId = value[OSSessionDeltaKey.subscriptionId] as? String
        if delta.name == OS_CREATE_SESSION_DELTA {
            return OSRequestCreateSession(
                appId: appId,
                localSessionId: localSessionId,
                startTime: Date(timeIntervalSince1970: value[OSSessionDeltaKey.startTime] as? TimeInterval ?? 0),
                directAttributionId: value[OSSessionDeltaKey.directAttributionId] as? String,
                identityModel: identityModel,
                ownerExternalId: delta.externalId,
                onesignalId: onesignalId,
                subscriptionId: subscriptionId
            )
        }
        return OSRequestUpdateSession(
            appId: appId,
            localSessionId: localSessionId,
            serverSessionId: value[OSSessionDeltaKey.serverSessionId] as? String ?? serverSessionIds[localSessionId],
            activeDuration: value[OSSessionDeltaKey.activeDuration] as? TimeInterval ?? 0,
            endTime: (value[OSSessionDeltaKey.endTime] as? TimeInterval).map { Date(timeIntervalSince1970: $0) },
            identityModel: identityModel,
            ownerExternalId: delta.externalId,
            onesignalId: onesignalId,
            subscriptionId: subscriptionId
        )
    }

    func admit(_ request: OSSessionRequest) {
        if let update = request as? OSRequestUpdateSession, !admitUpdate(update) {
            return
        }
        requestQueue.append(request)
        while requestQueue.count > Self.maxQueuedRequests {
            let oldest = requestQueue[0]
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor more than \(Self.maxQueuedRequests) Requests queued, dropping oldest: \(oldest)")
            drop(oldest)
        }
    }

    /**
     Folds an update into its session's queued ones, which are all cumulative. Returns false when the
     update should not be queued: its session already ended, it can never get a server session ID, or
     a queued update already has the same body.
     */
    func admitUpdate(_ update: OSRequestUpdateSession) -> Bool {
        let sessionId = update.localSessionId
        let queuedUpdates = requestQueue.compactMap { $0 as? OSRequestUpdateSession }.filter { $0.localSessionId == sessionId }
        guard !queuedUpdates.contains(where: \.isEnd) else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionOperationExecutor discarding \(update), the session already ended")
            return false
        }
        update.serverSessionId = update.serverSessionId ?? queuedUpdates.lazy.compactMap(\.serverSessionId).first
        guard update.serverSessionId != nil || hasCreate(forSession: sessionId) else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionOperationExecutor discarding \(update), its session has no create or server session ID")
            return false
        }
        // An update in flight still counts, so a later one cannot report less time.
        update.activeDuration = queuedUpdates.map(\.activeDuration).reduce(update.activeDuration, max)

        let pending = queuedUpdates.filter { !$0.sentToClient }
        update.failedAttempts = pending.map(\.failedAttempts).reduce(update.failedAttempts, max)
        update.onesignalId = update.onesignalId ?? pending.lazy.compactMap(\.onesignalId).first
        update.subscriptionId = update.subscriptionId ?? pending.lazy.compactMap(\.subscriptionId).first
        if pending.count == 1, let queued = pending.first,
           queued.activeDuration == update.activeDuration, queued.endTime == update.endTime {
            // Keep the queued update and its idempotency key, since the body did not change.
            queued.onesignalId = queued.onesignalId ?? update.onesignalId
            queued.subscriptionId = queued.subscriptionId ?? update.subscriptionId
            return false
        }
        requestQueue.removeAll { request in pending.contains { $0 === request } }
        return true
    }

    func hasCreate(forSession sessionId: String) -> Bool {
        requestQueue.contains { $0 is OSRequestCreateSession && $0.localSessionId == sessionId }
    }

    /// Removes a Request that will not be sent. A dropped create takes its session's updates with it,
    /// since they could never get a server session ID.
    func drop(_ request: OSSessionRequest) {
        requestQueue.removeAll { $0 === request }
        removeOrphanedUpdates()
    }

    func removeOrphanedUpdates() {
        let sessionsWithCreate = Set(requestQueue.filter { $0 is OSRequestCreateSession }.map(\.localSessionId))
        requestQueue.removeAll { request in
            guard let update = request as? OSRequestUpdateSession,
                  update.serverSessionId == nil,
                  !sessionsWithCreate.contains(update.localSessionId)
            else {
                return false
            }
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionOperationExecutor dropped \(update), its session has no create")
            return true
        }
    }
}

// MARK: - Sending

private extension OSSessionOperationExecutor {
    /// This method is called by `processDeltaQueue` only and does not need to be added to the dispatchQueue.
    func processRequestQueue(inBackground: Bool) {
        if removeUnsendableRequests() {
            cacheRequests()
        }
        var sessionsSeen = Set<String>()
        for request in requestQueue {
            guard sessionsSeen.insert(request.localSessionId).inserted,
                  !request.sentToClient,
                  uptime() >= request.retryNotBefore ?? 0,
                  request.prepareForExecution(newRecordsState: newRecordsState, auth: auth)
            else {
                continue
            }
            executeRequest(request, inBackground: inBackground)
        }
    }

    /// Drops Requests recorded for another app, and those past their age limit (see `OSRequestAging`).
    func removeUnsendableRequests() -> Bool {
        let countBefore = requestQueue.count
        let currentAppId = OneSignalIdentifiers.currentAppId
        let now = nowProvider()
        let currentExternalId = OSRequestAging.currentExternalId
        for request in requestQueue {
            if let currentAppId, request.appId != currentAppId {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionOperationExecutor dropped \(request), it belongs to another app")
                drop(request)
            } else if let age = OSRequestAging.staleAge(timestamp: request.timestamp, owner: request.ownerExternalId, typeLimit: nil, now: now, currentExternalId: currentExternalId) {
                OSRequestAging.logDrop(of: "\(type(of: request))", owner: request.ownerExternalId, age: age, executor: "OSSessionOperationExecutor")
                drop(request)
            }
        }
        return requestQueue.count != countBefore
    }

    func executeRequest(_ request: OSSessionRequest, inBackground: Bool) {
        request.sentToClient = true

        let backgroundTaskIdentifier = SESSION_EXECUTOR_BACKGROUND_TASK + UUID().uuidString
        if inBackground {
            OSBackgroundTaskManager.beginBackgroundTask(backgroundTaskIdentifier)
        }

        OneSignalCoreImpl.sharedClient().execute(request) { response in
            self.dispatchQueue.async {
                self.handleSuccess(request, response: response)
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        } onFailure: { error in
            self.dispatchQueue.async {
                self.handleFailure(request, error: error)
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        }
    }

    func handleSuccess(_ request: OSSessionRequest, response: [AnyHashable: Any]?) {
        guard let create = request as? OSRequestCreateSession else {
            requestQueue.removeAll { $0 === request }
            cacheRequests()
            return
        }
        guard let data = response?["data"] as? [String: Any],
              let serverSessionId = data["session_id"] as? String,
              !serverSessionId.isEmpty
        else {
            // Retrying with the same idempotency key returns the session the backend already created.
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor create session response is missing data.session_id")
            retry(request, statusCode: (response?["httpStatusCode"] as? NSNumber)?.intValue ?? 202, retryAfter: nil)
            return
        }
        requestQueue.removeAll { $0 === request }
        serverSessionIds[create.localSessionId] = serverSessionId
        for case let update as OSRequestUpdateSession in requestQueue where update.localSessionId == create.localSessionId {
            update.serverSessionId = update.serverSessionId ?? serverSessionId
        }
        // Updates wait out the post-create delay, so the backend has the session first.
        newRecordsState.add(serverSessionId)
        OSSessionService.shared.setServerSessionId(serverSessionId, forSessionId: create.localSessionId)
        cacheRequests()
    }

    func handleFailure(_ request: OSSessionRequest, error: OneSignalClientError) {
        OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSessionOperationExecutor \(request) failed with status \(error.code)")
        let code = error.code
        if (200..<300).contains(code) {
            // `OneSignalClient` reports a 2xx whose body failed to parse as a failure.
            if request is OSRequestCreateSession {
                retry(request, statusCode: code, retryAfter: nil)
            } else {
                requestQueue.removeAll { $0 === request }
                cacheRequests()
            }
        } else if code == 0 || code == 408 || code == 429 || code >= 500 {
            // 0 means no HTTP response: no network, timeout, or missing privacy consent.
            retry(request, statusCode: code, retryAfter: Self.retryAfterSeconds(error))
        } else {
            // Any other 4xx, or a missing app ID, which the client reports as a negative code.
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor dropping \(request) after a \(code)")
            drop(request)
            cacheRequests()
        }
    }

    /// Backs off exponentially, waiting at least `retryAfter`. Only attempts the backend answered count
    /// toward the limit, so a Request made offline keeps retrying until the network returns.
    func retry(_ request: OSSessionRequest, statusCode: Int, retryAfter: TimeInterval?) {
        request.sentToClient = false
        if statusCode != 0 {
            request.failedAttempts += 1
        }
        guard request.failedAttempts < Self.maxFailedAttempts else {
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor dropping \(request) after too many failures")
            drop(request)
            cacheRequests()
            return
        }
        request.retryAttempts += 1
        let exponential = Self.baseBackoffSeconds * pow(2, Double(request.retryAttempts - 1))
        let backoff = min(exponential, Self.maxBackoffSeconds) * jitter()
        request.retryNotBefore = uptime() + max(backoff, retryAfter ?? 0)
        cacheRequests()
    }

    /// Only the delay-seconds form is supported, not the HTTP-date form.
    static func retryAfterSeconds(_ error: OneSignalClientError) -> TimeInterval? {
        let value = error.responseHeaders?.first { key, _ in
            (key as? String)?.caseInsensitiveCompare("Retry-After") == .orderedSame
        }?.value
        if let value {
            return TimeInterval("\(value)".trimmingCharacters(in: .whitespaces)) ?? defaultRetryAfterSeconds
        }
        return error.code == 429 ? defaultRetryAfterSeconds : nil
    }
}
