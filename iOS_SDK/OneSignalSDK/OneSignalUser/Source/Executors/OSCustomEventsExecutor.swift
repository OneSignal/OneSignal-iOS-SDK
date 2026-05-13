/*
 Modified MIT License

 Copyright 2025 OneSignal

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

import OneSignalOSCore
import OneSignalCore

class OSCustomEventsExecutor: OSOperationExecutor {
    private enum EventConstants {
        static let name = "name"
        static let onesignalId = "onesignal_id"
        static let timestamp = "timestamp"
        static let payload = "payload"
        static let deviceType = "device_type"
        static let sdk = "sdk"
        static let appVersion = "app_version"
        static let type = "type"
        static let deviceModel = "device_model"
        static let deviceOs = "device_os"
        static let osSdk = "os_sdk"
        static let ios = "ios"
        static let iOSPush = "iOSPush"
    }

    var supportedDeltas: [String] = [OS_CUSTOM_EVENT_DELTA]
    var deltaQueue: [OSDelta] = []
    var requestQueue: [OSRequestCustomEvents] = []
    var pendingAuthRequests: [String: [OSRequestCustomEvents]] = [String: [OSRequestCustomEvents]]()
    let newRecordsState: OSNewRecordsState
    let jwtConfig: OSUserJwtConfig

    // The executor dispatch queue, serial. This synchronizes access to `deltaQueue` and `requestQueue`.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSCustomEventsExecutor", target: .global())

    init(newRecordsState: OSNewRecordsState, jwtConfig: OSUserJwtConfig) {
        self.newRecordsState = newRecordsState
        self.jwtConfig = jwtConfig
        self.jwtConfig.subscribe(self, key: OS_CUSTOM_EVENTS_EXECUTOR)
        // Read unfinished deltas and requests from cache, if any...
        uncacheDeltas()
        uncacheRequests()
    }

    private func uncacheDeltas() {
        if var deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            for (index, delta) in deltaQueue.enumerated().reversed() {
                guard let model = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId) else {
                    // The identity model does not exist, drop this Delta
                    OneSignalLog.onesignalLog(.LL_WARN, message: "OSCustomEventsExecutor.init dropped: \(delta)")
                    deltaQueue.remove(at: index)
                    continue
                }

                // If JWT is on but the external ID does not exist, drop this Delta
                if jwtConfig.isRequired == true, model.externalId == nil {
                    OneSignalLog.onesignalLog(.LL_DEBUG, message: "Invalid with JWT: OSCustomEventsExecutor.uncacheDeltas dropped \(delta)")
                    deltaQueue.remove(at: index)
                }
            }
            self.deltaQueue = deltaQueue
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSCustomEventsExecutor error encountered reading from cache for \(OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY)")
            self.deltaQueue = []
        }
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSCustomEventsExecutor successfully uncached Deltas: \(deltaQueue)")
    }

    private func uncacheRequests() {
        var requestQueue: [OSRequestCustomEvents] = []

        if let cachedQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestCustomEvents] {
            requestQueue = cachedQueue
        }

        if let pendingRequests = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_PENDING_QUEUE_KEY, defaultValue: [:]) as? [String: [OSRequestCustomEvents]] {
            for requests in pendingRequests.values {
                for request in requests {
                    requestQueue.append(request)
                }
            }
        }

        // Hook each uncached Request to the model in the store
        for (index, request) in requestQueue.enumerated().reversed() {
            if jwtConfig.isRequired == true,
               request.identityModel.externalId == nil
            {
                // remove if jwt is on but the model does not have external ID
                requestQueue.remove(at: index)
                continue
            }

            if let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(request.identityModel.modelId) {
                // 1. The identity model exist in the repo, set it to be the Request's model
                request.identityModel = identityModel
            } else if request.prepareForExecution(newRecordsState: newRecordsState) {
                // 2. The request can be sent, add the model to the repo
                OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(request.identityModel)
            } else {
                // 3. The identitymodel do not exist AND this request cannot be sent, drop this Request
                OneSignalLog.onesignalLog(.LL_WARN, message: "OSCustomEventsExecutor.init dropped: \(request)")
                requestQueue.remove(at: index)
            }
        }
        self.requestQueue = requestQueue
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSCustomEventsExecutor successfully uncached Requests: \(requestQueue)")
    }

    func enqueueDelta(_ delta: OSDelta) {
        self.dispatchQueue.async {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSCustomEventsExecutor enqueue delta \(delta)")
            self.deltaQueue.append(delta)
        }
    }

    func cacheDeltaQueue() {
        self.dispatchQueue.async {
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
        }
    }

    /// The `deltaQueue` can contain events for multiple users. They will remain as Deltas if there is no onesignal ID yet for its user.
    /// This method will be used in an upcoming release that combine multiple events.
    func processDeltaQueueWithBatching(inBackground: Bool) {
        guard jwtConfig.isRequired != nil else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSCustomEventsExecutor processDeltaQueueWithBatching returning early due to requiresAuth: \(String(describing: jwtConfig.isRequired))")
            return
        }

        self.dispatchQueue.async {
            if self.deltaQueue.isEmpty {
                // Delta queue is empty but there may be pending requests
                self.processRequestQueue(inBackground: inBackground)
                return
            }
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSCustomEventsExecutor processDeltaQueue with queue: \(self.deltaQueue)")

            // Holds mapping of identity model ID to the events for it
            var combinedEvents: [String: [[String: Any]]] = [:]

            // 1. Combine the events for every distinct user
            for (index, delta) in self.deltaQueue.enumerated().reversed() {
                guard let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId),
                      let onesignalId = identityModel.onesignalId
                else {
                    OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSCustomEventsExecutor.processDeltaQueue skipping: \(delta)")
                    // keep this Delta in the queue, as it is not yet ready to be processed
                    continue
                }

                // If JWT is on but the external ID does not exist, drop this Delta
                if self.jwtConfig.isRequired == true, identityModel.externalId == nil {
                    OneSignalLog.onesignalLog(.LL_DEBUG, message: "Invalid with JWT: OSCustomEventsExecutor.processDeltaQueue dropped \(delta)")
                    self.deltaQueue.remove(at: index)
                    continue
                }

                guard let properties = delta.value as? [String: Any] else {
                    // This should not happen as there are preventative typing measures before this step
                    OneSignalLog.onesignalLog(.LL_ERROR, message: "OSCustomEventsExecutor.processDeltaQueue dropped due to invalid properties: \(delta)")
                    self.deltaQueue.remove(at: index)
                    continue
                }

                let event: [String: Any] = [
                    EventConstants.name: delta.property,
                    EventConstants.onesignalId: onesignalId,
                    EventConstants.timestamp: ISO8601DateFormatter().string(from: delta.timestamp),
                    EventConstants.payload: self.addSdkMetadata(properties: properties)
                ]

                combinedEvents[identityModel.modelId, default: []].append(event)
                self.deltaQueue.remove(at: index)
            }

            // 2. Turn each user's events into a Request
            for (modelId, events) in combinedEvents {
                guard let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(modelId)
                else {
                    // This should never happen as we already checked this during Deltas processing above
                    continue
                }
                let request = OSRequestCustomEvents(
                    events: events,
                    identityModel: identityModel
                )
                self.requestQueue.append(request)
            }

            // Persist executor's requests (including new request) to storage
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)

            self.processRequestQueue(inBackground: inBackground)
        }
    }

    func processDeltaQueue(inBackground: Bool) {
        guard jwtConfig.isRequired != nil else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSCustomEventsExecutor processDeltaQueue returning early due to requiresAuth: \(String(describing: jwtConfig.isRequired))")
            return
        }

        self.dispatchQueue.async {
            if self.deltaQueue.isEmpty {
                // Delta queue is empty but there may be pending requests
                self.processRequestQueue(inBackground: inBackground)
                return
            }
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSCustomEventsExecutor processDeltaQueue with queue: \(self.deltaQueue)")

            for (index, delta) in self.deltaQueue.enumerated().reversed() {
                guard let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId),
                      let onesignalId = identityModel.onesignalId
                else {
                    OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSCustomEventsExecutor.processDeltaQueue skipping: \(delta)")
                    // keep this Delta in the queue, as it is not yet ready to be processed
                    continue
                }

                // If JWT is on but the external ID does not exist, drop this Delta
                if self.jwtConfig.isRequired == true, identityModel.externalId == nil {
                    OneSignalLog.onesignalLog(.LL_DEBUG, message: "Invalid with JWT: OSCustomEventsExecutor.processDeltaQueue dropped \(delta)")
                    self.deltaQueue.remove(at: index)
                    continue
                }

                guard let properties = delta.value as? [String: Any] else {
                    // This should not happen as there are preventative typing measures before this step
                    OneSignalLog.onesignalLog(.LL_ERROR, message: "OSCustomEventsExecutor.processDeltaQueue dropped due to invalid properties: \(delta)")
                    self.deltaQueue.remove(at: index)
                    continue
                }

                let event: [String: Any] = [
                    EventConstants.name: delta.property,
                    EventConstants.onesignalId: onesignalId,
                    EventConstants.timestamp: ISO8601DateFormatter().string(from: delta.timestamp),
                    EventConstants.payload: self.addSdkMetadata(properties: properties)
                ]

                self.deltaQueue.remove(at: index)

                let request = OSRequestCustomEvents(
                    events: [event],
                    identityModel: identityModel
                )
                self.requestQueue.append(request)
            }

            // Persist executor's requests (including new request) to storage
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)

            self.processRequestQueue(inBackground: inBackground)
        }
    }

    /**
     Adds additional data about the SDK to the event payload.
     */
    private func addSdkMetadata(properties: [String: Any]) -> [String: Any] {
        // TODO: Exact information contained in payload should be confirmed before the custom events GA release
        let metadata = [
            EventConstants.deviceType: EventConstants.ios,
            EventConstants.sdk: ONESIGNAL_VERSION,
            EventConstants.appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            EventConstants.type: EventConstants.iOSPush,
            EventConstants.deviceModel: OSDeviceUtils.getDeviceVariant(),
            EventConstants.deviceOs: UIDevice.current.systemVersion
        ]
        var payload = properties
        payload[EventConstants.osSdk] = metadata
        return payload
    }

    /// This method is called by `processDeltaQueue` only and does not need to be added to the dispatchQueue.
    private func processRequestQueue(inBackground: Bool) {
        if requestQueue.isEmpty {
            return
        }

        for request in requestQueue {
            executeRequest(request, inBackground: inBackground)
        }
    }

    func handleUnauthorizedError(externalId: String, request: OSRequestCustomEvents) {
        if jwtConfig.isRequired ?? false {
            self.pendRequestUntilAuthUpdated(request, externalId: externalId)
            OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: externalId)
        }
    }

    func pendRequestUntilAuthUpdated(_ request: OSRequestCustomEvents, externalId: String?) {
        self.dispatchQueue.async {
            self.requestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
            guard let externalId = externalId else {
                return
            }
            var requests = self.pendingAuthRequests[externalId] ?? []
            let inQueue = requests.contains(where: {$0 == request})
            guard !inQueue else {
                return
            }
            requests.append(request)
            self.pendingAuthRequests[externalId] = requests
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_PENDING_QUEUE_KEY, withValue: self.pendingAuthRequests)
        }
    }

    func executeRequest(_ request: OSRequestCustomEvents, inBackground: Bool) {
        guard !request.sentToClient else {
            return
        }

        guard request.addJWTHeaderIsValid(identityModel: request.identityModel) else {
            pendRequestUntilAuthUpdated(request, externalId: request.identityModel.externalId)
            return
        }

        guard request.prepareForExecution(newRecordsState: newRecordsState) else {
            return
        }
        request.sentToClient = true

        let backgroundTaskIdentifier = CUSTOM_EVENTS_EXECUTOR_BACKGROUND_TASK + UUID().uuidString
        if inBackground {
            OSBackgroundTaskManager.beginBackgroundTask(backgroundTaskIdentifier)
        }

        OneSignalCoreImpl.sharedClient().execute(request) { _ in
            self.dispatchQueue.async {
                self.requestQueue.removeAll(where: { $0 == request})
                OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSCustomEventsExecutor request failed with error: \(error.debugDescription)")
            self.dispatchQueue.async {
                let responseType = OSNetworkingUtils.getResponseStatusType(error.code)
                if responseType == .unauthorized && (self.jwtConfig.isRequired ?? false) {
                    if let externalId = request.identityModel.externalId {
                        self.handleUnauthorizedError(externalId: externalId, request: request)
                    }
                    request.sentToClient = false
                } else if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    self.requestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
                }
                // TODO: Handle payload too large (not necessary for alpha release)
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        }
    }
}

extension OSCustomEventsExecutor: OSUserJwtConfigListener {
    func onRequiresUserAuthChanged(from: OSRequiresUserAuth, to: OSRequiresUserAuth) {
        // If auth changed from false or unknown to true, drop invalid items
        if to == .on {
            removeInvalidDeltasAndRequests()
        }
    }

    func onJwtUpdated(externalId: String, token: String?) {
        reQueuePendingRequestsForExternalId(externalId: externalId)
    }

    private func reQueuePendingRequestsForExternalId(externalId: String) {
        self.dispatchQueue.async {
            guard let requests = self.pendingAuthRequests[externalId] else {
                return
            }
            for request in requests {
                self.requestQueue.append(request)
            }
            self.pendingAuthRequests[externalId] = nil
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_PENDING_QUEUE_KEY, withValue: self.pendingAuthRequests)
            self.processRequestQueue(inBackground: false)
        }
    }

    private func removeInvalidDeltasAndRequests() {
        self.dispatchQueue.async {
            for (index, delta) in self.deltaQueue.enumerated().reversed() {
                if let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId),
                   identityModel.externalId == nil
                {
                    OneSignalLog.onesignalLog(.LL_DEBUG, message: "Invalid with JWT: OSCustomEventsExecutor.removeInvalidDeltasAndRequests dropped \(delta)")
                    self.deltaQueue.remove(at: index)
                }
            }
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)

            for (index, request) in self.requestQueue.enumerated().reversed() {
                if request.identityModel.externalId == nil {
                    OneSignalLog.onesignalLog(.LL_DEBUG, message: "Invalid with JWT: OSCustomEventsExecutor.removeInvalidDeltasAndRequests dropped \(request)")
                    self.requestQueue.remove(at: index)
                }
            }
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
        }
    }
}

extension OSCustomEventsExecutor: OSLoggable {
    func logSelf() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message:
            """
            OSCustomEventsExecutor has the following queues:
                requestQueue: \(self.requestQueue)
                deltaQueue: \(self.deltaQueue)
                pendingAuthRequests: \(self.pendingAuthRequests)

            """
        )
    }
}
