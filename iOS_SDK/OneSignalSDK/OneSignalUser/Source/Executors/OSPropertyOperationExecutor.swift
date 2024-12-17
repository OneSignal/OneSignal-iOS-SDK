/*
 Modified MIT License

 Copyright 2022 OneSignal

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

/// Helper struct to process and combine OSDeltas into one payload
private struct OSCombinedProperties {
    var properties: [String: Any] = [:]
    var tags: [String: String] = [:]
    var location: OSLocationPoint?
    var refreshDeviceMetadata = false

    // Items of Properties Deltas
    var sessionTime: Int = 0
    var sessionCount: Int = 0
    var purchases: [[String: AnyObject]] = []

    func jsonRepresentation() -> [String: Any] {
        var propertiesObject = properties
        propertiesObject["tags"] = tags.isEmpty ? nil : tags
        propertiesObject["lat"] = location?.lat
        propertiesObject["long"] = location?.long

        var deltas = [String: Any]()
        deltas["session_count"] = (sessionCount > 0) ? sessionCount : nil
        deltas["session_time"] = (sessionTime > 0) ? sessionTime : nil
        deltas["purchases"] = purchases.isEmpty ? nil : purchases

        var params: [String: Any] = [:]
        params["properties"] = propertiesObject.isEmpty ? nil : propertiesObject
        params["refresh_device_metadata"] = refreshDeviceMetadata
        params["deltas"] = deltas.isEmpty ? nil : deltas

        return params
    }
}

class OSPropertyOperationExecutor: OSOperationExecutor {
    var supportedDeltas: [String] = [OS_UPDATE_PROPERTIES_DELTA]
    var deltaQueue: [OSDelta] = []
    var updateRequestQueue: [OSRequestUpdateProperties] = []
    let newRecordsState: OSNewRecordsState

    // The property executor dispatch queue, serial. This synchronizes access to `deltaQueue` and `updateRequestQueue`.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSPropertyOperationExecutor", target: .global())

    init(newRecordsState: OSNewRecordsState) {
        self.newRecordsState = newRecordsState
        // Read unfinished deltas and requests from cache, if any...
        // Note that we should only have deltas for the current user as old ones are flushed..
        uncacheDeltas()
        uncacheUpdateRequests()
    }

    private func uncacheDeltas() {
        if var deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            for (index, delta) in deltaQueue.enumerated().reversed() {
                if OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId) == nil {
                    // The identity model does not exist, drop this Delta
                    OneSignalLog.onesignalLog(.LL_WARN, message: "OSPropertyOperationExecutor.init dropped: \(delta)")
                    deltaQueue.remove(at: index)
                }
            }
            self.deltaQueue = deltaQueue
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor error encountered reading from cache for \(OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY)")
        }
    }

    private func uncacheUpdateRequests() {
        if var updateRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestUpdateProperties] {
            // Hook each uncached Request to the model in the store
            for (index, request) in updateRequestQueue.enumerated().reversed() {
                if let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(request.identityModel.modelId) {
                    // 1. The identity model exist in the repo, set it to be the Request's model
                    request.identityModel = identityModel
                } else if request.prepareForExecution(newRecordsState: newRecordsState) {
                    // 2. The request can be sent, add the model to the repo
                    OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(request.identityModel)
                } else {
                    // 3. The identitymodel do not exist AND this request cannot be sent, drop this Request
                    OneSignalLog.onesignalLog(.LL_WARN, message: "OSPropertyOperationExecutor.init dropped: \(request)")
                    updateRequestQueue.remove(at: index)
                }
            }
            self.updateRequestQueue = updateRequestQueue
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor error encountered reading from cache for \(OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY)")
        }
    }

    func enqueueDelta(_ delta: OSDelta) {
        self.dispatchQueue.async {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSPropertyOperationExecutor enqueue delta \(delta)")
            self.deltaQueue.append(delta)
        }
    }

    func cacheDeltaQueue() {
        self.dispatchQueue.async {
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
        }
    }

    /// The `deltaQueue` should only contain updates for one user.
    /// Even when login -> addTag -> login -> addTag are called in immediate succession.
    func processDeltaQueue(inBackground: Bool) {
        self.dispatchQueue.async {
            if self.deltaQueue.isEmpty {
                // Delta queue is empty but there may be pending requests
                self.processRequestQueue(inBackground: inBackground)
                return
            }
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSPropertyOperationExecutor processDeltaQueue with queue: \(self.deltaQueue)")

            // Holds mapping of identity model ID to the updates for it; there should only be one user
            var combinedProperties: [String: OSCombinedProperties] = [:]

            // 1. Combined deltas into a single OSCombinedProperties for every user
            for delta in self.deltaQueue {
                guard let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.identityModelId)
                else {
                    OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor.processDeltaQueue dropped: \(delta)")
                    continue
                }
                let combinedSoFar: OSCombinedProperties? = combinedProperties[identityModel.modelId]
                combinedProperties[identityModel.modelId] = self.combineProperties(existing: combinedSoFar, delta: delta)
            }

            if combinedProperties.count > 1 {
                OneSignalLog.onesignalLog(.LL_WARN, message: "OSPropertyOperationExecutor.combinedProperties contains \(combinedProperties.count) users")
            }

            // 2. Turn each OSCombinedProperties' data into a Request
            for (modelId, properties) in combinedProperties {
                guard let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(modelId)
                else {
                    // This should never happen as we already checked this during Deltas processing above
                    OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor.processDeltaQueue dropped: \(properties)")
                    continue
                }
                let request = OSRequestUpdateProperties(
                    params: properties.jsonRepresentation(),
                    identityModel: identityModel
                )
                self.updateRequestQueue.append(request)
            }

            self.deltaQueue.removeAll()

            // Persist executor's requests (including new request) to storage
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, withValue: [])

            self.processRequestQueue(inBackground: inBackground)
        }
    }

    /// Helper method to combine the information in an `OSDelta` to the existing `OSCombinedProperties` so far.
    private func combineProperties(existing: OSCombinedProperties?, delta: OSDelta) -> OSCombinedProperties {
        var combinedProperties = existing ?? OSCombinedProperties()

        guard let property = OSPropertiesSupportedProperty(rawValue: delta.property) else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor.combineProperties dropped unsupported property: \(delta.property)")
            return combinedProperties
        }

        switch property {
        case .tags:
            if let tags = delta.value as? [String: String] {
                for (tag, value) in tags {
                    combinedProperties.tags[tag] = value
                }
            }
        case .location:
            // Use the most recent location point
            combinedProperties.location = delta.value as? OSLocationPoint
        case .session_time:
            combinedProperties.sessionTime += (delta.value as? Int ?? 0)
        case .session_count:
            combinedProperties.refreshDeviceMetadata = true
            combinedProperties.sessionCount += (delta.value as? Int ?? 0)
        case .purchases:
            if let purchases = delta.value as? [[String: AnyObject]] {
                for purchase in purchases {
                    combinedProperties.purchases.append(purchase)
                }
            }
        default:
            // First-level, un-nested properties as "language"
            combinedProperties.properties[delta.property] = delta.value
        }
        return combinedProperties
    }

    /// This method is called by `processDeltaQueue` only and does not need to be added to the dispatchQueue.
    func processRequestQueue(inBackground: Bool) {
        if updateRequestQueue.isEmpty {
            return
        }

        for request in updateRequestQueue {
            executeUpdatePropertiesRequest(request, inBackground: inBackground)
        }
    }

    func executeUpdatePropertiesRequest(_ request: OSRequestUpdateProperties, inBackground: Bool) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution(newRecordsState: newRecordsState) else {
            return
        }
        request.sentToClient = true

        let backgroundTaskIdentifier = PROPERTIES_EXECUTOR_BACKGROUND_TASK + UUID().uuidString
        if inBackground {
            OSBackgroundTaskManager.beginBackgroundTask(backgroundTaskIdentifier)
        }

        OneSignalCoreImpl.sharedClient().execute(request) { response in
            // On success, remove request from cache, and we do need to hydrate
            // TODO: We need to hydrate after all ? What why ?
            self.dispatchQueue.async {
                self.updateRequestQueue.removeAll(where: { $0 == request})
                OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
            if let onesignalId = request.identityModel.onesignalId {
                if let rywToken = response?["ryw_token"] as? String
                {
                    let rywDelay = response?["ryw_delay"] as? NSNumber

                    OSConsistencyManager.shared.setRywTokenAndDelay(
                        id: onesignalId,
                        key: OSIamFetchOffsetKey.userUpdate,
                        value: OSReadYourWriteData(rywToken: rywToken, rywDelay: rywDelay)
                    )
                } else {
                    // handle a potential regression where ryw_token is no longer returned by API
                    OSConsistencyManager.shared.resolveConditionsWithID(id: OSIamFetchReadyCondition.CONDITIONID)
                }
            }
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor update properties request failed with error: \(error.debugDescription)")
            self.dispatchQueue.async {
                let responseType = OSNetworkingUtils.getResponseStatusType(error.code)
                if responseType == .missing {
                    // remove from cache and queue
                    self.updateRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
                    // Logout if the user in the SDK is the same
                    guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel)
                    else {
                        if inBackground {
                            OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                        }
                        return
                    }
                    // The subscription has been deleted along with the user, so remove the subscription_id but keep the same push subscription model
                    OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = nil
                    OneSignalUserManagerImpl.sharedInstance._logout()
                } else if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    self.updateRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
                }
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        }
    }
}
