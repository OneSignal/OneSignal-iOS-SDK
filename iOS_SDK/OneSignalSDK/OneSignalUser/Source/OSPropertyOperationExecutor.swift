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

class OSPropertyOperationExecutor: OSOperationExecutor {
    var supportedDeltas: [String] = [OS_UPDATE_PROPERTIES_DELTA]
    var deltaQueue: [OSDelta] = []
    var updateRequestQueue: [OSRequestUpdateProperties] = []

    init() {
        // Read unfinished deltas from cache, if any...
        // Note that we should only have deltas for the current user as old ones are flushed..
        if var deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            // Hook each uncached Delta to the model in the store
            for (index, delta) in deltaQueue.enumerated().reversed() {
                if let modelInStore = OneSignalUserManagerImpl.sharedInstance.propertiesModelStore.getModel(modelId: delta.model.modelId) {
                    // 1. The model exists in the properties model store, set it to be the Delta's model
                    delta.model = modelInStore
                } else {
                    // 2. The model does not exist, drop this Delta
                    deltaQueue.remove(at: index)
                }
            }
            self.deltaQueue = deltaQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor error encountered reading from cache for \(OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY)")
        }

        // Read unfinished requests from cache, if any...
        if var updateRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestUpdateProperties] {
            // Hook each uncached Request to the model in the store
            for (index, request) in updateRequestQueue.enumerated().reversed() {
                // 0. Hook up the properties model if its the current user's so it can hydrate
                if let propertiesModel = OneSignalUserManagerImpl.sharedInstance.propertiesModelStore.getModel(modelId: request.modelToUpdate.modelId) {
                    request.modelToUpdate = propertiesModel
                }
                if let identityModel = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(modelId: request.identityModel.modelId) {
                    // 1. The identity model exist in the store, set it to be the Request's models
                    request.identityModel = identityModel
                } else if let identityModel = OSUserExecutor.identityModels[request.identityModel.modelId] {
                    // 2. The model exists in the user executor
                    request.identityModel = identityModel
                } else if !request.prepareForExecution() {
                    // 3. The identitymodel do not exist AND this request cannot be sent, drop this Request
                    updateRequestQueue.remove(at: index)
                }
            }
            self.updateRequestQueue = updateRequestQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor error encountered reading from cache for \(OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY)")
        }
    }

    func enqueueDelta(_ delta: OSDelta) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSPropertyOperationExecutor enqueue delta\(delta)")
        deltaQueue.append(delta)
    }

    func cacheDeltaQueue() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
    }

    func processDeltaQueue() {
        if !deltaQueue.isEmpty {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSPropertyOperationExecutor processDeltaQueue with queue: \(deltaQueue)")
        }
        for delta in deltaQueue {
            guard let model = delta.model as? OSPropertiesModel else {
                // Log error
                continue
            }

            let request = OSRequestUpdateProperties(
                properties: [delta.property: delta.value],
                deltas: nil,
                refreshDeviceMetadata: false, // Sort this out.
                modelToUpdate: model,
                identityModel: OneSignalUserManagerImpl.sharedInstance.user.identityModel // TODO: Make sure this is ok
            )
            updateRequestQueue.append(request)
        }
        self.deltaQueue = [] // TODO: Check that we can simply clear all the deltas in the deltaQueue

        // persist executor's requests (including new request) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)

        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue) // This should be empty, can remove instead?
        processRequestQueue()
    }

    func processRequestQueue() {
        if updateRequestQueue.isEmpty {
            return
        }

        for request in updateRequestQueue {
            executeUpdatePropertiesRequest(request)
        }
    }

    func executeUpdatePropertiesRequest(_ request: OSRequestUpdateProperties) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            return
        }
        request.sentToClient = true

        OneSignalClient.shared().execute(request) { _ in
            // On success, remove request from cache, and we do need to hydrate
            // TODO: We need to hydrate after all ? What why ?
            self.updateRequestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSPropertyOperationExecutor update properties request failed with error: \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType == .missing {
                    // remove from cache and queue
                    self.updateRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
                    // Logout if the user in the SDK is the same
                    guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel)
                    else {
                        return
                    }
                    // The subscription has been deleted along with the user, so remove the subscription_id but keep the same push subscription model
                    OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModelStore.getModels()[OS_PUSH_SUBSCRIPTION_MODEL_KEY]?.subscriptionId = nil
                    OneSignalUserManagerImpl.sharedInstance._logout()
                } else if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    self.updateRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
                }
            }
        }
    }
}

extension OSPropertyOperationExecutor {
    // TODO: We can make this go through the operation repo
    func updateProperties(propertiesDeltas: OSPropertiesDeltas, refreshDeviceMetadata: Bool?, propertiesModel: OSPropertiesModel, identityModel: OSIdentityModel) {

        let request = OSRequestUpdateProperties(
            properties: [:],
            deltas: propertiesDeltas.jsonRepresentation(),
            refreshDeviceMetadata: refreshDeviceMetadata,
            modelToUpdate: propertiesModel,
            identityModel: identityModel)

        updateRequestQueue.append(request)
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
    }
}
