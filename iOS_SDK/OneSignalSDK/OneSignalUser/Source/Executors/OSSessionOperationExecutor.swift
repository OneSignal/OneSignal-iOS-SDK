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

/**
 Sends sessions API Requests: a session's create, then its updates once the create returns the server
 session ID. Only the first queued Request of a session is sent, so they reach the backend in order.
 Failures are retried through the shared `OSRequestRetryBackoff`.
 */
class OSSessionOperationExecutor: OSOperationExecutor {
    static let maxQueuedRequests = 100
    /// A create answered without a `session_id` is retried this many times, then dropped.
    static let maxMissingSessionIdAttempts = 3

    var supportedDeltas: [String] = [OS_CREATE_SESSION_DELTA, OS_UPDATE_SESSION_DELTA]
    private var deltaQueue: [OSDelta] = []
    private var requestQueue: [OSSessionRequest] = []
    /// By local session ID, for an update built after its create already succeeded.
    private var createdSessions: [String: OSCreatedSession] = [:]
    /// By local session ID. An end leaves the queue once sent or dropped, but its session stays ended.
    private var endedSessions: Set<String> = []
    private let newRecordsState: OSNewRecordsState
    private let auth: OSRequestAuthorizing
    private let retryBackoff: OSRequestRetryBackoff
    private let nowProvider: () -> Date

    // The executor dispatch queue, serial. This synchronizes access to `deltaQueue` and `requestQueue`.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSSessionOperationExecutor", target: .global())

    init(
        newRecordsState: OSNewRecordsState,
        auth: OSRequestAuthorizing,
        retryBackoff: OSRequestRetryBackoff = OSRequestRetryBackoff(),
        nowProvider: @escaping () -> Date = { Date() }
    ) {
        self.newRecordsState = newRecordsState
        self.auth = auth
        self.retryBackoff = retryBackoff
        self.nowProvider = nowProvider
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
            if let created = update.createdSession {
                createdSessions[update.localSessionId] = created
            }
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

    /**
     The sessions API takes no user JWT, so Identity Verification does not apply to session Requests.
     But an anonymous user is never created while it is required, so a create still waiting for that
     user's `onesignal_id` can never be sent. Drop those, with their updates.
     */
    func removeOperationsWithoutExternalId() {
        self.dispatchQueue.async {
            let countBefore = self.requestQueue.count
            self.requestQueue.removeAll { request in
                request is OSRequestCreateSession
                    && request.identityModel.externalId == nil
                    && request.identityModel.onesignalId == nil
            }
            guard self.requestQueue.count != countBefore else {
                return
            }
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionOperationExecutor dropped \(countBefore - self.requestQueue.count) creates for anonymous users that will never be created")
            self.removeOrphanedUpdates()
            self.cacheRequests()
        }
    }

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
        let update = OSRequestUpdateSession(
            appId: appId,
            localSessionId: localSessionId,
            activeDuration: value[OSSessionDeltaKey.activeDuration] as? TimeInterval ?? 0,
            endTime: (value[OSSessionDeltaKey.endTime] as? TimeInterval).map { Date(timeIntervalSince1970: $0) },
            identityModel: identityModel,
            ownerExternalId: delta.externalId
        )
        if let created = createdSessions[localSessionId] {
            update.createdSession = created
        } else if let serverSessionId = value[OSSessionDeltaKey.serverSessionId] as? String, let onesignalId, let subscriptionId {
            // The session record holds what the create sent once it succeeded, possibly in an earlier process.
            let created = OSCreatedSession(serverSessionId: serverSessionId, onesignalId: onesignalId, subscriptionId: subscriptionId)
            createdSessions[localSessionId] = created
            update.createdSession = created
        }
        return update
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
     update should not be queued: its session already ended, or it can never get a server session ID.
     */
    func admitUpdate(_ update: OSRequestUpdateSession) -> Bool {
        let sessionId = update.localSessionId
        let queuedUpdates = requestQueue.compactMap { $0 as? OSRequestUpdateSession }.filter { $0.localSessionId == sessionId }
        guard !endedSessions.contains(sessionId), !queuedUpdates.contains(where: \.isEnd) else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionOperationExecutor discarding \(update), the session already ended")
            return false
        }
        guard update.createdSession != nil || hasCreate(forSession: sessionId) else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionOperationExecutor discarding \(update), its session has no create or server session ID")
            return false
        }
        // An update in flight still counts, so a later one cannot report less time.
        update.activeDuration = queuedUpdates.map(\.activeDuration).reduce(update.activeDuration, max)

        let pending = queuedUpdates.filter { !$0.sentToClient }
        requestQueue.removeAll { request in pending.contains { $0 === request } }
        // Carry a backoff over, or the replacement would skip it.
        pending.last.map { retryBackoff.transferWait(from: $0, to: update) }
        return true
    }

    func hasCreate(forSession sessionId: String) -> Bool {
        requestQueue.contains { $0 is OSRequestCreateSession && $0.localSessionId == sessionId }
    }

    /// Removes a Request that will not be sent. A dropped create takes its session's updates with it,
    /// since they could never get a server session ID.
    func drop(_ request: OSSessionRequest) {
        markEndedIfEnd(request)
        requestQueue.removeAll { $0 === request }
        removeOrphanedUpdates()
    }

    func markEndedIfEnd(_ request: OSSessionRequest) {
        if let update = request as? OSRequestUpdateSession, update.isEnd {
            endedSessions.insert(update.localSessionId)
        }
    }

    func removeOrphanedUpdates() {
        let sessionsWithCreate = Set(requestQueue.filter { $0 is OSRequestCreateSession }.map(\.localSessionId))
        requestQueue.removeAll { request in
            guard let update = request as? OSRequestUpdateSession,
                  update.createdSession == nil,
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
        // Without consent the client fails every send with status 0, which would retry forever.
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil) else {
            return
        }
        if removeUnsendableRequests() {
            cacheRequests()
        }
        var sessionsSeen = Set<String>()
        var sentCreate = false
        for request in requestQueue {
            guard sessionsSeen.insert(request.localSessionId).inserted,
                  !request.sentToClient,
                  !retryBackoff.isWaiting(request),
                  request.prepareForExecution(newRecordsState: newRecordsState, auth: auth)
            else {
                continue
            }
            sentCreate = sentCreate || request is OSRequestCreateSession
            executeRequest(request, inBackground: inBackground)
        }
        if sentCreate {
            // Persists the IDs the create was just sent with, so a replay after a kill cannot change them.
            cacheRequests()
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
            markEndedIfEnd(request)
            requestQueue.removeAll { $0 === request }
            cacheRequests()
            return
        }
        guard let data = response?["data"] as? [String: Any],
              let serverSessionId = data["session_id"] as? String,
              !serverSessionId.isEmpty,
              let onesignalId = create.onesignalId,
              let subscriptionId = create.subscriptionId
        else {
            retryMissingSessionId(create, response: response)
            return
        }
        requestQueue.removeAll { $0 === request }
        let created = OSCreatedSession(serverSessionId: serverSessionId, onesignalId: onesignalId, subscriptionId: subscriptionId)
        createdSessions[create.localSessionId] = created
        for case let update as OSRequestUpdateSession in requestQueue where update.localSessionId == create.localSessionId {
            update.createdSession = created
        }
        // Updates wait out the post-create delay, so the backend has the session first.
        newRecordsState.add(serverSessionId)
        OSSessionService.shared.setCreatedSession(
            forSessionId: create.localSessionId,
            serverSessionId: serverSessionId,
            onesignalId: onesignalId,
            subscriptionId: subscriptionId
        )
        cacheRequests()
    }

    /// Retrying with the same idempotency key should return the session the backend already created.
    func retryMissingSessionId(_ create: OSRequestCreateSession, response: [AnyHashable: Any]?) {
        create.missingSessionIdAttempts += 1
        guard create.missingSessionIdAttempts < Self.maxMissingSessionIdAttempts else {
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor dropping \(create), its responses never had a session_id")
            drop(create)
            cacheRequests()
            return
        }
        OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor create session response is missing data.session_id")
        retry(create, error: OneSignalClientError(code: 202, message: "Missing data.session_id", responseHeaders: nil, response: response, underlyingError: nil))
        cacheRequests()
    }

    func handleFailure(_ request: OSSessionRequest, error: OneSignalClientError) {
        OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSessionOperationExecutor \(request) failed with status \(error.code)")
        let code = error.code
        if (200..<300).contains(code) {
            // `OneSignalClient` reports a 2xx whose body failed to parse as a failure.
            handleSuccess(request, response: nil)
        } else if code == 0 || code == 408 || code == 429 || code >= 500 {
            // 0 means no HTTP response: no network or a timeout.
            retry(request, error: error)
        } else {
            // Any other 4xx, or a missing app ID, which the client reports as a negative code.
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionOperationExecutor dropping \(request) after a \(code)")
            drop(request)
            cacheRequests()
        }
    }

    func retry(_ request: OSSessionRequest, error: OneSignalClientError) {
        retryBackoff.recordFailure(request, error: error)
        request.sentToClient = false
    }
}
