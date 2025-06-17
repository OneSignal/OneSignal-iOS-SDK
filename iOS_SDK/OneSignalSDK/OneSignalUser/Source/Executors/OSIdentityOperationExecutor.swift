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
    var pendingAuthRequests: [String: [OSUserRequest]] = [String: [OSUserRequest]]()
    let newRecordsState: OSNewRecordsState
    let jwtConfig: OSUserJwtConfig

    // The Identity executor dispatch queue, serial. This synchronizes access to the delta and request queues.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSIdentityOperationExecutor", target: .global())

    init(newRecordsState: OSNewRecordsState, jwtConfig: OSUserJwtConfig) {
        self.newRecordsState = newRecordsState
        self.jwtConfig = jwtConfig
        self.jwtConfig.subscribe(self, key: OS_IDENTITY_EXECUTOR)
        print("❌ OSIdentityOperationExecutor init(\(jwtConfig.isRequired))")
        // Read unfinished deltas and requests from cache, if any...
        uncacheDeltas()
        uncacheAddAliasRequests()
        uncacheRemoveAliasRequests()
    }

    private func uncacheDeltas() {
        guard var deltaQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, defaultValue: []) as? [OSDelta] else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor error encountered reading from cache for \(OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY)")
            return
        }

        // Hook each uncached Delta to the model in the store
        for (index, delta) in deltaQueue.enumerated().reversed() {
            if jwtConfig.isRequired == true,
               (delta.model as? OSIdentityModel)?.externalId == nil
            {
                // remove if jwt is on but the model does not have external ID
                deltaQueue.remove(at: index)
                continue
            }

            if let modelInStore = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(delta.model.modelId) {
                // The model exists in the repo, set it to be the Delta's model
                delta.model = modelInStore
            } else {
                // The model does not exist, drop this Delta
                OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor.init dropped \(delta)")
                deltaQueue.remove(at: index)
            }
        }

        self.deltaQueue = deltaQueue
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
    }

    private func uncacheAddAliasRequests() {
        guard var addRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestAddAliases] else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor error encountered reading from cache for \(OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY)")
            return
        }

        // Hook each uncached Request to the model in the store
        for (index, request) in addRequestQueue.enumerated().reversed() {
            if jwtConfig.isRequired == true,
               request.identityModel.externalId == nil
            {
                // remove if jwt is on but the model does not have external ID
                addRequestQueue.remove(at: index)
                continue
            }

            if let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(request.identityModel.modelId) {
                // 1. The model exists in the repo, so set it to be the Request's models
                request.identityModel = identityModel
            } else if request.prepareForExecution(newRecordsState: newRecordsState) {
                // 2. The request can be sent, add the model to the repo
                OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(request.identityModel)
            } else {
                // 3. The model do not exist AND this request cannot be sent, drop this Request
                OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor.init dropped \(request)")
                addRequestQueue.remove(at: index)
            }
        }

        self.addRequestQueue = addRequestQueue
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
    }

    private func uncacheRemoveAliasRequests() {
        guard var removeRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestRemoveAlias] else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor error encountered reading from cache for \(OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY)")
            return
        }

        // Hook each uncached Request to the model in the store
        for (index, request) in removeRequestQueue.enumerated().reversed() {
            if jwtConfig.isRequired == true,
               request.identityModel.externalId == nil
            {
                // remove if jwt is on but the model does not have external ID
                removeRequestQueue.remove(at: index)
                continue
            }

            if let identityModel = OneSignalUserManagerImpl.sharedInstance.getIdentityModel(request.identityModel.modelId) {
                // 1. The model exists in the repo, so set it to be the Request's models
                request.identityModel = identityModel
            } else if request.prepareForExecution(newRecordsState: newRecordsState) {
                // 2. The request can be sent, add the model to the repo
                OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(request.identityModel)
            } else {
                // 3. The model do not exist AND this request cannot be sent, drop this Request
                OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor.init dropped \(request)")
                removeRequestQueue.remove(at: index)
            }
        }

        self.removeRequestQueue = removeRequestQueue
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)
    }

    func enqueueDelta(_ delta: OSDelta) {
        self.dispatchQueue.async {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityOperationExecutor enqueueDelta: \(delta)")
            self.deltaQueue.append(delta)
        }
    }

    func cacheDeltaQueue() {
        self.dispatchQueue.async {
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)
        }
    }

    func processDeltaQueue(inBackground: Bool) {
        self.dispatchQueue.async {
            if !self.deltaQueue.isEmpty {
                OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityOperationExecutor processDeltaQueue with queue: \(self.deltaQueue)")
            }
            for delta in self.deltaQueue {
                guard let model = delta.model as? OSIdentityModel,
                      let aliases = delta.value as? [String: String]
                else {
                    // Log error
                    continue
                }

                // If JWT is on but the external ID does not exist, drop this Delta
                if self.jwtConfig.isRequired == true, model.externalId == nil {
                    print("❌ \(delta) is Invalid with JWT, being dropped")
                }

                switch delta.name {
                case OS_ADD_ALIAS_DELTA:
                    let request = OSRequestAddAliases(aliases: aliases, identityModel: model)
                    self.addRequestQueue.append(request)

                case OS_REMOVE_ALIAS_DELTA:
                    for (label, _) in aliases {
                        let request = OSRequestRemoveAlias(labelToRemove: label, identityModel: model)
                        self.removeRequestQueue.append(request)
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

            self.processRequestQueue(inBackground: inBackground)
        }
    }

    /// This method is called by `processDeltaQueue` only and does not need to be added to the dispatchQueue.
    func processRequestQueue(inBackground: Bool) {
        let requestQueue: [OneSignalRequest] = addRequestQueue + removeRequestQueue

        if requestQueue.isEmpty {
            return
        }

        // Sort the requestQueue by timestamp
        for request in requestQueue.sorted(by: { first, second in
            return first.timestamp < second.timestamp
        }) {
            if request.isKind(of: OSRequestAddAliases.self), let addAliasesRequest = request as? OSRequestAddAliases {
                executeAddAliasesRequest(addAliasesRequest, inBackground: inBackground)
            } else if request.isKind(of: OSRequestRemoveAlias.self), let removeAliasRequest = request as? OSRequestRemoveAlias {
                executeRemoveAliasRequest(removeAliasRequest, inBackground: inBackground)
            } else {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSIdentityOperationExecutor.processRequestQueue met incompatible OneSignalRequest type: \(request).")
            }
        }
    }

    func handleUnauthorizedError(externalId: String, error: NSError, request: OSUserRequest) {
        if jwtConfig.isRequired ?? false {
            self.pendRequestUntilAuthUpdated(request, externalId: externalId)
            OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: externalId, error: error)
        }
    }

    func pendRequestUntilAuthUpdated(_ request: OSUserRequest, externalId: String?) {
        self.dispatchQueue.async {
            self.addRequestQueue.removeAll(where: { $0 == request})
            self.removeRequestQueue.removeAll(where: { $0 == request})
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
        }
    }

    func executeAddAliasesRequest(_ request: OSRequestAddAliases, inBackground: Bool) {
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

        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityOperationExecutor: executeAddAliasesRequest making request: \(request)")

        let backgroundTaskIdentifier = IDENTITY_EXECUTOR_BACKGROUND_TASK + UUID().uuidString
        if inBackground {
            OSBackgroundTaskManager.beginBackgroundTask(backgroundTaskIdentifier)
        }

        OneSignalCoreImpl.sharedClient().execute(request) { _ in
            // No hydration from response
            // On success, remove request from cache
            self.dispatchQueue.async {
                self.addRequestQueue.removeAll(where: { $0 == request})
                OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        } onFailure: { error in
            self.dispatchQueue.async {
                let responseType = OSNetworkingUtils.getResponseStatusType(error.code)
                if responseType == .missing {
                    // Remove from cache and queue
                    self.addRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
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
                } else if responseType == .unauthorized && (self.jwtConfig.isRequired ?? false) {
                    if let externalId = request.identityModel.externalId {
                        self.handleUnauthorizedError(externalId: externalId, error: nsError, request: request)
                    }
                    request.sentToClient = false
                } else if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    self.addRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
                }
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        }
    }

    func executeRemoveAliasRequest(_ request: OSRequestRemoveAlias, inBackground: Bool) {
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

        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityOperationExecutor: executeRemoveAliasRequest making request: \(request)")

        let backgroundTaskIdentifier = IDENTITY_EXECUTOR_BACKGROUND_TASK + UUID().uuidString
        if inBackground {
            OSBackgroundTaskManager.beginBackgroundTask(backgroundTaskIdentifier)
        }

        OneSignalCoreImpl.sharedClient().execute(request) { _ in
            // There is nothing to hydrate
            // On success, remove request from cache
            self.dispatchQueue.async {
                self.removeRequestQueue.removeAll(where: { $0 == request})
                OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityOperationExecutor remove alias request failed with error: \(error.debugDescription)")
            self.dispatchQueue.async {
                let responseType = OSNetworkingUtils.getResponseStatusType(error.code)
                if responseType == .unauthorized && (self.jwtConfig.isRequired ?? false) {
                    if let externalId = request.identityModel.externalId {
                        self.handleUnauthorizedError(externalId: externalId, error: nsError, request: request)
                    }
                    request.sentToClient = false
                } else if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    // A response of .missing could mean the alias doesn't exist on this user OR this user has been deleted
                    self.removeRequestQueue.removeAll(where: { $0 == request})
                    OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)
                }
                if inBackground {
                    OSBackgroundTaskManager.endBackgroundTask(backgroundTaskIdentifier)
                }
            }
        }
    }
}

extension OSIdentityOperationExecutor: OSUserJwtConfigListener {
    func onRequiresUserAuthChanged(from: OSRequiresUserAuth, to: OSRequiresUserAuth) {
        print("❌ OSIdentityOperationExecutor onUserAuthChanged from \(String(describing: from)) to \(String(describing: to))")
        // If auth changed from false or unknown to true, process requests
        if to == .on {
            removeInvalidDeltasAndRequests()
        }
    }

    func onJwtUpdated(externalId: String, token: String?) {
        print("❌ OSIdentityOperationExecutor onJwtUpdated for \(externalId) to \(String(describing: token))")
        reQueuePendingRequestsForExternalId(externalId: externalId)
    }

    private func reQueuePendingRequestsForExternalId(externalId: String) {
        self.dispatchQueue.async {
            guard let requests = self.pendingAuthRequests[externalId] else {
                return
            }
            for request in requests {
                if let addRequest = request as? OSRequestAddAliases {
                    self.addRequestQueue.append(addRequest)
                } else if let removeRequest = request as? OSRequestRemoveAlias {
                    self.removeRequestQueue.append(removeRequest)
                }
            }
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)
            self.pendingAuthRequests[externalId] = nil
            self.processRequestQueue(inBackground: false)
        }
    }

    private func removeInvalidDeltasAndRequests() {
        self.dispatchQueue.async {
            print("❌ OSIdentityOperationExecutor.removeInvalidDeltasAndRequests called")
            for (index, delta) in self.deltaQueue.enumerated().reversed() {
                if (delta.model as? OSIdentityModel)?.externalId == nil {
                    print(" \(delta) is Invalid, being removed")
                    self.deltaQueue.remove(at: index)
                }
            }
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_DELTA_QUEUE_KEY, withValue: self.deltaQueue)

            for (index, request) in self.addRequestQueue.enumerated().reversed() {
                if request.identityModel.externalId == nil {
                    print(" \(request) is Invalid, being removed")
                    self.addRequestQueue.remove(at: index)
                }
            }
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, withValue: self.addRequestQueue)

            for (index, request) in self.removeRequestQueue.enumerated().reversed() {
                if request.identityModel.externalId == nil {
                    print(" \(request) is Invalid, being removed")
                    self.removeRequestQueue.remove(at: index)
                }
            }
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, withValue: self.removeRequestQueue)
        }
    }
}

extension OSIdentityOperationExecutor: OSLoggable {
    func logSelf() {
        print(
            """
            💛 OSIdentityOperationExecutor has the following queues:
                addRequestQueue: \(self.addRequestQueue)
                removeRequestQueue: \(self.removeRequestQueue)
                deltaQueue: \(self.deltaQueue)
            """
        )
    }
}
