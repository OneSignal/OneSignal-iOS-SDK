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

class OSIdentityOperationExecutor: OSOperationExecutor {
    var supportedDeltas: [String] = [OS_ADD_ALIAS_DELTA, OS_REMOVE_ALIAS_DELTA]
    var deltaQueue: [OSDelta] = []
    // To simplify uncaching, we maintain separate request queues for each type
    var addRequestQueue: [OSRequestAddAliases] = []
    var removeRequestQueue: [OSRequestRemoveAlias] = []

    init() {
        // Read unfinished deltas from cache, if any...
        if var deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] {
            // Hook each uncached Delta to the model in the store
            for (index, delta) in deltaQueue.enumerated().reversed() {
                if let modelInStore = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(modelId: delta.model.modelId) {
                    // The model exists in the store, set it to be the Delta's model
                    delta.model = modelInStore
                } else {
                    // The model does not exist, drop this Delta
                    deltaQueue.remove(at: index)
                }
            }
            self.deltaQueue = deltaQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor error encountered reading from cache for \(OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY)")
        }

        // Read unfinished requests from cache, if any...

        if var addRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestAddAliases] {
            // Hook each uncached Request to the model in the store
            for (index, request) in addRequestQueue.enumerated().reversed() {
                if let identityModel = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(modelId: request.identityModel.modelId) {
                    // The model exists in the store, set it to be the Request's models
                    request.identityModel = identityModel
                } else if !request.prepareForExecution() {
                    // The models do not exist AND this request cannot be sent, drop this Request
                    addRequestQueue.remove(at: index)
                }
            }
            self.addRequestQueue = addRequestQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor error encountered reading from cache for \(OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY)")
        }

        if var removeRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestRemoveAlias] {
            // Hook each uncached Request to the model in the store
            for (index, request) in removeRequestQueue.enumerated().reversed() {
                if let identityModel = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(modelId: request.identityModel.modelId) {
                    // The model exists in the store, set it to be the Request's model
                    request.identityModel = identityModel
                } else if !request.prepareForExecution() {
                    // The model does not exist AND this request cannot be sent, drop this Request
                    removeRequestQueue.remove(at: index)
                }
            }
            self.removeRequestQueue = removeRequestQueue
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor error encountered reading from cache for \(OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY)")
        }
    }

    func enqueueDelta(_ delta: OSDelta) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityOperationExecutor enqueueDelta: \(delta)")
        deltaQueue.append(delta)
    }

    func cacheDeltaQueue() {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
    }

    func processDeltaQueue() {
        if !deltaQueue.isEmpty {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityOperationExecutor processDeltaQueue with queue: \(deltaQueue)")
        }
        for delta in deltaQueue {
            guard let model = delta.model as? OSIdentityModel,
                  let aliases = delta.value as? [String: String]
            else {
                // Log error
                continue
            }

            switch delta.name {
            case OS_ADD_ALIAS_DELTA:
                let request = OSRequestAddAliases(aliases: aliases, identityModel: model)
                addRequestQueue.append(request)

            case OS_REMOVE_ALIAS_DELTA:
                if let label = aliases.first?.key {
                    let request = OSRequestRemoveAlias(labelToRemove: label, identityModel: model)
                    removeRequestQueue.append(request)
                }

            default:
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSIdentityOperationExecutor met incompatible OSDelta type: \(delta)")
            }
        }

        self.deltaQueue = [] // TODO: Check that we can simply clear all the deltas in the deltaQueue

        // persist executor's requests (including new request) to storage
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)

        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue) // This should be empty, can remove instead?

        processRequestQueue()
    }

    func processRequestQueue() {
        let requestQueue: [OneSignalRequest] = addRequestQueue + removeRequestQueue

        if requestQueue.isEmpty {
            return
        }

        // Sort the requestQueue by timestamp
        for request in requestQueue.sorted(by: { first, second in
            return first.timestamp < second.timestamp
        }) {
            if request.isKind(of: OSRequestAddAliases.self), let addAliasesRequest = request as? OSRequestAddAliases {
                executeAddAliasesRequest(addAliasesRequest)
            } else if request.isKind(of: OSRequestRemoveAlias.self), let removeAliasRequest = request as? OSRequestRemoveAlias {
                executeRemoveAliasRequest(removeAliasRequest)
            } else {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSIdentityOperationExecutor.processRequestQueue met incompatible OneSignalRequest type: \(request).")
            }
        }
    }

    func executeAddAliasesRequest(_ request: OSRequestAddAliases) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityOperationExecutor: executeAddAliasesRequest making request: \(request)")

        OneSignalClient.shared().execute(request) { _ in
            // Mock a response
            // TODO: Is there even a response to hydrate?
            let response = ["onesignalId": UUID().uuidString, "label01": "id01"]

            // On success, remove request from cache, and hydrate model
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.addRequestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)

            // instead: modelstore.hydratewithresponse with modelid passed in.. request.modeltoupdate.modelId
                // store can determine if modelid is same, then hydrate or do nothign
            request.identityModel.hydrate(response)

        } onFailure: { error in
            self.addRequestQueue.removeAll(where: { $0 == request})
            OneSignalLog.onesignalLog(.LL_ERROR, message: error.debugDescription)
        }
    }

    func executeRemoveAliasRequest(_ request: OSRequestRemoveAlias) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityOperationExecutor: executeRemoveAliasRequest making request: \(request)")

        OneSignalClient.shared().execute(request) { _ in

            // Mock a response
            // TODO: Is there even a response to hydrate?
            let response = ["onesignalId": UUID().uuidString, "label01": "id01"]

            // On success, remove request from cache, and hydrate model
            // For example, if app restarts and we read in operations between sending this off and getting the response
            self.removeRequestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)

            request.identityModel.hydrate(response)

        } onFailure: { error in
            self.removeRequestQueue.removeAll(where: { $0 == request})
            OneSignalLog.onesignalLog(.LL_ERROR, message: error.debugDescription)
        }
    }
}
