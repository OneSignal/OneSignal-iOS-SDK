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

class OSSubscriptionOperationExecutor: OSOperationExecutor {
    var supportedDeltas: [String] = [OS_ADD_SUBSCRIPTION_DELTA, OS_REMOVE_SUBSCRIPTION_DELTA, OS_UPDATE_SUBSCRIPTION_DELTA]
    var deltaQueue: [OSDelta] = []
    // To simplify uncaching, we maintain separate request queues for each type
    var addRequestQueue: [OSRequestCreateSubscription] = []
    var removeRequestQueue: [OSRequestDeleteSubscription] = []
    var updateRequestQueue: [OSRequestUpdateSubscription] = []
    var subscriptionModels: [String: OSSubscriptionModel] = [:]

    init() {
        // Read unfinished deltas from cache, if any...
        if var deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            // Hook each uncached Delta to the model in the store
            for (index, delta) in deltaQueue.enumerated().reversed() {
                if let modelInStore = getSubscriptionModelFromStores(modelId: delta.model.modelId) {
                    // The model exists in the subscription store, set it to be the Delta's model
                    delta.model = modelInStore
                } else {
                    // The model does not exist, drop this Delta
                    deltaQueue.remove(at: index)
                }
            }
            self.deltaQueue = deltaQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionOperationExecutor error encountered reading from cache for \(OS_SUBSCRIPTION_EXECUTOR_DELTA_QUEUE_KEY)")
        }

        // Read unfinished requests from cache, if any...

        var requestQueue: [OSRequestCreateSubscription] = []

        if let cachedAddRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestCreateSubscription] {
            // Hook each uncached Request to the model in the store
            for request in cachedAddRequestQueue {
                // 1. Hook up the subscription model
                if let subscriptionModel = getSubscriptionModelFromStores(modelId: request.subscriptionModel.modelId) {
                    // a. The model exist in the store, set it to be the Request's models
                    request.subscriptionModel = subscriptionModel
                } else if let subscriptionModel = subscriptionModels[request.subscriptionModel.modelId] {
                    // b. The model exists in the dictionary of seen models
                    request.subscriptionModel = subscriptionModel
                } else {
                    // c. The model has not been seen yet, add to dict
                    subscriptionModels[request.subscriptionModel.modelId] = request.subscriptionModel
                }
                // 2. Hook up the identity model
                if let identityModel = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(modelId: request.identityModel.modelId) {
                    // a. The model exist in the store
                    request.identityModel = identityModel
                } else if let identityModel = OSUserExecutor.identityModels[request.identityModel.modelId] {
                    // b. The model exist in the user executor
                    request.identityModel = identityModel
                } else if !request.prepareForExecution() {
                    // The model do not exist AND this request cannot be sent, drop this Request
                    continue
                }
                requestQueue.append(request)
            }
            self.addRequestQueue = requestQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionOperationExecutor error encountered reading from cache for \(OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY)")
        }

        if var removeRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestDeleteSubscription] {
            // Hook each uncached Request to the model in the store
            for (index, request) in removeRequestQueue.enumerated().reversed() {
                if let subscriptionModel = getSubscriptionModelFromStores(modelId: request.subscriptionModel.modelId) {
                    // 1. The model exists in the store, set it to be the Request's model
                    request.subscriptionModel = subscriptionModel
                } else if let subscriptionModel = subscriptionModels[request.subscriptionModel.modelId] {
                    // 2. The model exists in the dict of seen subscription models
                    request.subscriptionModel = subscriptionModel
                } else if !request.prepareForExecution() {
                    // 3. The model does not exist AND this request cannot be sent, drop this Request
                    removeRequestQueue.remove(at: index)
                }
            }
            self.removeRequestQueue = removeRequestQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionOperationExecutor error encountered reading from cache for \(OS_SUBSCRIPTION_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY)")
        }

        if var updateRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestUpdateSubscription] {
            // Hook each uncached Request to the model in the store
            for (index, request) in updateRequestQueue.enumerated().reversed() {
                if let subscriptionModel = getSubscriptionModelFromStores(modelId: request.subscriptionModel.modelId) {
                    // 1. The model exists in the store, set it to be the Request's model
                    request.subscriptionModel = subscriptionModel
                } else if let subscriptionModel = subscriptionModels[request.subscriptionModel.modelId] {
                    // 2. The model exists in the dict of seen subscription models
                    request.subscriptionModel = subscriptionModel
                } else if !request.prepareForExecution() {
                    // 3. The models do not exist AND this request cannot be sent, drop this Request
                    updateRequestQueue.remove(at: index)
                }
            }
            self.updateRequestQueue = updateRequestQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionOperationExecutor error encountered reading from cache for \(OS_SUBSCRIPTION_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY)")
        }
    }

    /**
     Since there are 2 subscription stores, we need to check both stores for the model with a particular `modelId`.
     */
    func getSubscriptionModelFromStores(modelId: String) -> OSSubscriptionModel? {
        if let modelInStore = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModelStore.getModel(modelId: modelId) {
            return modelInStore
        }
        if let modelInStore = OneSignalUserManagerImpl.sharedInstance.subscriptionModelStore.getModel(modelId: modelId) {
            return modelInStore
        }
        return nil
    }

    func enqueueDelta(_ delta: OSDelta) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSSubscriptionOperationExecutor enqueueDelta: \(delta)")
        deltaQueue.append(delta)
    }

    func cacheDeltaQueue() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
    }

    func processDeltaQueue() {
        if !deltaQueue.isEmpty {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSSubscriptionOperationExecutor processDeltaQueue with queue: \(deltaQueue)")
        }
        for delta in deltaQueue {
            guard let model = delta.model as? OSSubscriptionModel else {
                // Log error
                continue
            }

            switch delta.name {
            case OS_ADD_SUBSCRIPTION_DELTA:
                let request = OSRequestCreateSubscription(
                    subscriptionModel: model,
                    identityModel: OneSignalUserManagerImpl.sharedInstance.user.identityModel // TODO: Make sure this is ok
                )
                addRequestQueue.append(request)

            case OS_REMOVE_SUBSCRIPTION_DELTA:
                let request = OSRequestDeleteSubscription(
                    subscriptionModel: model
                )
                removeRequestQueue.append(request)

            case OS_UPDATE_SUBSCRIPTION_DELTA:
                let request = OSRequestUpdateSubscription(
                    subscriptionObject: [delta.property: delta.value],
                    subscriptionModel: model
                )
                updateRequestQueue.append(request)

            default:
                // Log error
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSubscriptionOperationExecutor met incompatible OSDelta type: \(delta).")
            }
        }

        self.deltaQueue = [] // TODO: Check that we can simply clear all the deltas in the deltaQueue

        // persist executor's requests (including new request) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)

        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue) // This should be empty, can remove instead?

        processRequestQueue()
    }

    // Bypasses the operation repo to create a push subscription request
    func createPushSubscription(subscriptionModel: OSSubscriptionModel, identityModel: OSIdentityModel) {
        let request = OSRequestCreateSubscription(subscriptionModel: subscriptionModel, identityModel: identityModel)
        addRequestQueue.append(request)
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
    }

    func processRequestQueue() {
        let requestQueue: [OneSignalRequest] = addRequestQueue + removeRequestQueue + updateRequestQueue

        if requestQueue.isEmpty {
            return
        }

        // Sort the requestQueue by timestamp
        for request in requestQueue.sorted(by: { first, second in
            return first.timestamp < second.timestamp
        }) {
            if request.isKind(of: OSRequestCreateSubscription.self), let createSubscriptionRequest = request as? OSRequestCreateSubscription {
                executeCreateSubscriptionRequest(createSubscriptionRequest)
            } else if request.isKind(of: OSRequestDeleteSubscription.self), let deleteSubscriptionRequest = request as? OSRequestDeleteSubscription {
                executeDeleteSubscriptionRequest(deleteSubscriptionRequest)
            } else if request.isKind(of: OSRequestUpdateSubscription.self), let updateSubscriptionRequest = request as? OSRequestUpdateSubscription {
                executeUpdateSubscriptionRequest(updateSubscriptionRequest)
            } else {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSubscriptionOperationExecutor.processRequestQueue met incompatible OneSignalRequest type: \(request).")
            }
        }
    }

    func executeCreateSubscriptionRequest(_ request: OSRequestCreateSubscription) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            return
        }
        request.sentToClient = true

        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSSubscriptionOperationExecutor: executeCreateSubscriptionRequest making request: \(request)")
        OneSignalClient.shared().execute(request) { result in
            // On success, remove request from cache (even if not hydrating model), and hydrate model
            self.addRequestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)

            guard let response = result?["subscription"] as? [String: Any] else {
                OneSignalLog.onesignalLog(.LL_ERROR, message: "Unabled to parse response to create subscription request")
                return
            }
            request.subscriptionModel.hydrate(response)
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionOperationExecutor create subscription request failed with error: \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType == .missing {
                    self.addRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
                    // Logout if the user in the SDK is the same
                    guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel)
                    else {
                        return
                    }
                    // The subscription has been deleted along with the user, so remove the subscription_id but keep the same push subscription model
                    OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = nil
                    OneSignalUserManagerImpl.sharedInstance._logout()
                } else if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    self.addRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
                }
            }
        }
    }

    func executeDeleteSubscriptionRequest(_ request: OSRequestDeleteSubscription) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            return
        }
        request.sentToClient = true

        // This request can be executed as-is.
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSSubscriptionOperationExecutor: executeDeleteSubscriptionRequest making request: \(request)")
        OneSignalClient.shared().execute(request) { _ in

            // On success, remove request from cache. No model hydration occurs.
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.removeRequestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)

        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionOperationExecutor delete subscription request failed with error: \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    // If this request returns a missing status, that is ok as this is a delete request
                    self.removeRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)
                }
            }
        }
    }

    func executeUpdateSubscriptionRequest(_ request: OSRequestUpdateSubscription) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            return
        }
        request.sentToClient = true

        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSSubscriptionOperationExecutor: executeUpdateSubscriptionRequest making request: \(request)")

        OneSignalClient.shared().execute(request) { _ in

            // On success, remove request from cache. No model hydration occurs.
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.updateRequestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)

        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSSubscriptionOperationExecutor update subscription request failed with error: \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    self.updateRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_SUBSCRIPTION_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, withValue: self.updateRequestQueue)
                }
            }
        }
    }
}
