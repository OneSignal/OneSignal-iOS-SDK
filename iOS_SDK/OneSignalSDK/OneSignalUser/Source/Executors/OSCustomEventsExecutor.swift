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
    private var deltaQueue: [OSDelta] = []
    private var requestQueue: [OSRequestCustomEvents] = []
    private let newRecordsState: OSNewRecordsState

    // The executor dispatch queue, serial. This synchronizes access to `deltaQueue` and `requestQueue`.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSCustomEventsExecutor", target: .global())

    init(newRecordsState: OSNewRecordsState) {
        self.newRecordsState = newRecordsState
        // Read unfinished deltas and requests from cache, if any...
        uncacheDeltas()
        uncacheRequests()
    }

    private func uncacheDeltas() {
        if var deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            for (index, delta) in deltaQueue.enumerated().reversed() {
                if OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId) == nil {
                    // The identity model does not exist, drop this Delta
                    OneSignalLog.onesignalLog(.LL_WARN, message: "OSCustomEventsExecutor.init dropped: \(delta)")
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
        if var requestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestCustomEvents] {
            // Hook each uncached Request to the model in the store
            for (index, request) in requestQueue.enumerated().reversed() {
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
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSCustomEventsExecutor error encountered reading from cache for \(OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY)")
            self.requestQueue = []
        }
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
    func processDeltaQueue(inBackground: Bool) {
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

    private func executeRequest(_ request: OSRequestCustomEvents, inBackground: Bool) {
        guard !request.sentToClient else {
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
                if responseType != .retryable {
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
