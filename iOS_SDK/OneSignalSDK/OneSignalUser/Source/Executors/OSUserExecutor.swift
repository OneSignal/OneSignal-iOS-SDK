/*
 Modified MIT License

 Copyright 2023 OneSignal

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

import OneSignalCore
import OneSignalNotifications
import OneSignalOSCore

/**
 Involved in the login process and responsible for Identify User and Create User.
 Can execute `OSRequestCreateUser`, `OSRequestIdentifyUser`, `OSRequestTransferSubscription`, `OSRequestFetchUser`, `OSRequestFetchIdentityBySubscription`.
 */
class OSUserExecutor {
    static var userRequestQueue: [OSUserRequest] = []
    static var transferSubscriptionRequestQueue: [OSRequestTransferSubscription] = []
    static var identityModels: [String: OSIdentityModel] = [:]

    // Read in requests from the cache, do not read in FetchUser requests as this is not needed.
    static func start() {
        var userRequestQueue: [OSUserRequest] = []

        // Read unfinished Create User + Identify User + Get Identity By Subscription requests from cache, if any...
        if let cachedRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSUserRequest] {
            // Hook each uncached Request to the right model reference
            for request in cachedRequestQueue {
                if request.isKind(of: OSRequestFetchIdentityBySubscription.self), let req = request as? OSRequestFetchIdentityBySubscription {
                    if let identityModel = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(modelId: req.identityModel.modelId) {
                        // 1. The model exist in the store, set it to be the Request's model
                        req.identityModel = identityModel
                    } else if let identityModel = identityModels[req.identityModel.modelId] {
                        // 2. The model exists in the dict of identityModels already processed to use
                        req.identityModel = identityModel
                    } else {
                        // 3. The models do not exist, use the model on the request, and add to dict.
                        identityModels[req.identityModel.modelId] = req.identityModel
                    }
                    userRequestQueue.append(req)

                } else if request.isKind(of: OSRequestCreateUser.self), let req = request as? OSRequestCreateUser {
                    if let identityModel = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(modelId: req.identityModel.modelId) {
                        // 1. The model exist in the store, set it to be the Request's model
                        req.identityModel = identityModel
                    } else if let identityModel = identityModels[req.identityModel.modelId] {
                        // 2. The model exists in the dict of identityModels already processed to use
                        req.identityModel = identityModel
                    } else {
                        // 3. The models do not exist, use the model on the request, and add to dict.
                        identityModels[req.identityModel.modelId] = req.identityModel
                    }
                    userRequestQueue.append(req)

                } else if request.isKind(of: OSRequestIdentifyUser.self), let req = request as? OSRequestIdentifyUser {

                    if let identityModelToIdentify = identityModels[req.identityModelToIdentify.modelId],
                       let identityModelToUpdate = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(modelId: req.identityModelToUpdate.modelId) {
                        // 1. A model exist in the dict and a model exist in the store, set it to be the Request's models
                        req.identityModelToIdentify = identityModelToIdentify
                        req.identityModelToUpdate = identityModelToUpdate
                    } else if let identityModelToIdentify = identityModels[req.identityModelToIdentify.modelId],
                              let identityModelToUpdate = identityModels[req.identityModelToUpdate.modelId] {
                        // 2. The two models exist in the dict, set it to be the Request's models
                        req.identityModelToIdentify = identityModelToIdentify
                        req.identityModelToUpdate = identityModelToUpdate
                    } else if let identityModelToIdentify = identityModels[req.identityModelToIdentify.modelId],
                              identityModels[req.identityModelToUpdate.modelId] == nil {
                        // 3. A model is in the dict, the other model does not exist
                        req.identityModelToIdentify = identityModelToIdentify
                        identityModels[req.identityModelToUpdate.modelId] = req.identityModelToUpdate
                    } else {
                        // 4. Both models don't exist yet
                        identityModels[req.identityModelToIdentify.modelId] = req.identityModelToIdentify
                        identityModels[req.identityModelToUpdate.modelId] = req.identityModelToUpdate
                    }
                    userRequestQueue.append(req)
                }
            }
        }
        self.userRequestQueue = userRequestQueue

        // Read unfinished Transfer Subscription requests from cache, if any...
        if let transferSubscriptionRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_USER_EXECUTOR_TRANSFER_SUBSCRIPTION_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSRequestTransferSubscription] {
            // We only care about the last transfer subscription request
            if let request = transferSubscriptionRequestQueue.last {
                // Hook the uncached Request to the model in the store
                if request.subscriptionModel.modelId == OneSignalUserManagerImpl.sharedInstance.user.pushSubscriptionModel.modelId {
                    // The model exist, set it to be the Request's model
                    request.subscriptionModel = OneSignalUserManagerImpl.sharedInstance.user.pushSubscriptionModel
                    self.transferSubscriptionRequestQueue = [request]
                } else if !request.prepareForExecution() {
                    // The model do not exist AND this request cannot be sent, drop this Request
                    OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor.start() reading request \(request) from cache failed. Dropping request.")
                    self.transferSubscriptionRequestQueue = []
                }
            }
        } else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor error encountered reading from cache for \(OS_USER_EXECUTOR_TRANSFER_SUBSCRIPTION_REQUEST_QUEUE_KEY)")
        }

        executePendingRequests()
    }

    static func appendToQueue(_ request: OSUserRequest) {
        if request.isKind(of: OSRequestTransferSubscription.self), let req = request as? OSRequestTransferSubscription {
            self.transferSubscriptionRequestQueue.append(req)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_TRANSFER_SUBSCRIPTION_REQUEST_QUEUE_KEY, withValue: self.transferSubscriptionRequestQueue)
        } else {
            self.userRequestQueue.append(request)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, withValue: self.userRequestQueue)
        }
    }

    static func removeFromQueue(_ request: OSUserRequest) {
        if request.isKind(of: OSRequestTransferSubscription.self), let req = request as? OSRequestTransferSubscription {
            transferSubscriptionRequestQueue.removeAll(where: { $0 == req})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_TRANSFER_SUBSCRIPTION_REQUEST_QUEUE_KEY, withValue: self.transferSubscriptionRequestQueue)
        } else {
            userRequestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, withValue: self.userRequestQueue)
        }
    }

    static func executePendingRequests() {
        let requestQueue: [OSUserRequest] = userRequestQueue + transferSubscriptionRequestQueue

        if requestQueue.isEmpty {
            return
        }

        // Sort the requestQueue by timestamp
        for request in requestQueue.sorted(by: { first, second in
            return first.timestamp < second.timestamp
        }) {
            // Return as soon as we reach an un-executable request
            if !request.prepareForExecution() {
                return
            }

            if request.isKind(of: OSRequestFetchIdentityBySubscription.self), let fetchIdentityRequest = request as? OSRequestFetchIdentityBySubscription {
                executeFetchIdentityBySubscriptionRequest(fetchIdentityRequest)
                return
            } else if request.isKind(of: OSRequestCreateUser.self), let createUserRequest = request as? OSRequestCreateUser {
                executeCreateUserRequest(createUserRequest)
                return
            } else if request.isKind(of: OSRequestIdentifyUser.self), let identifyUserRequest = request as? OSRequestIdentifyUser {
                executeIdentifyUserRequest(identifyUserRequest)
                return
            } else if request.isKind(of: OSRequestTransferSubscription.self), let transferSubscriptionRequest = request as? OSRequestTransferSubscription {
                executeTransferPushSubscriptionRequest(transferSubscriptionRequest)
                return
            } else if request.isKind(of: OSRequestFetchUser.self), let fetchUserRequest = request as? OSRequestFetchUser {
                executeFetchUserRequest(fetchUserRequest)
                return
            } else {
                // Log Error
                OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor met incompatible Request type that cannot be executed.")
            }
        }
    }

    // We will pass minimal properties to this request
    static func createUser(_ user: OSUserInternal) {
        let originalPushToken = user.pushSubscriptionModel.address
        let request = OSRequestCreateUser(identityModel: user.identityModel, propertiesModel: user.propertiesModel, pushSubscriptionModel: user.pushSubscriptionModel, originalPushToken: originalPushToken)

        appendToQueue(request)

        executePendingRequests()
    }

    static func executeCreateUserRequest(_ request: OSRequestCreateUser) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            // Currently there are no requirements needed before sending this request
            return
        }
        request.sentToClient = true

        // Hook up push subscription model, it may be updated with a subscription_id, etc.
        if let pushSubscriptionModel = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModelStore.getModel(modelId: request.pushSubscriptionModel.modelId) {
            request.pushSubscriptionModel = pushSubscriptionModel
            request.updatePushSubscriptionModel(pushSubscriptionModel)
        }

        OneSignalClient.shared().execute(request) { response in
            removeFromQueue(request)

            // TODO: Differentiate if we need to fetch the user based on response code of 200, 201, 202
            // Create User's response won't send us the user's complete info if this user already exists
            if let response = response {
                // Parse the response for any data we need to update
                parseFetchUserResponse(response: response, identityModel: request.identityModel, originalPushToken: request.originalPushToken)

                // If this user already exists and we logged into an external_id, fetch the user data
                // TODO: Only do this if response code is 200 or 202
                // Fetch the user only if its the current user
                if OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel),
                   let identity = request.parameters?["identity"] as? [String: String],
                   let externalId = identity[OS_EXTERNAL_ID] {
                    fetchUser(aliasLabel: OS_EXTERNAL_ID, aliasId: externalId, identityModel: request.identityModel)
                } else {
                    executePendingRequests()
                }
            }
            OSOperationRepo.sharedInstance.paused = false
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor create user request failed with error: \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    // A failed create user request would leave the SDK in a bad state
                    // Don't remove the request from cache and pause the operation repo
                    // We will retry this request on a new session
                    OSOperationRepo.sharedInstance.paused = true
                    request.sentToClient = false
                }
            } else {
                executePendingRequests()
            }
        }
    }

    static func fetchIdentityBySubscription(_ user: OSUserInternal) {
        let request = OSRequestFetchIdentityBySubscription(identityModel: user.identityModel, pushSubscriptionModel: user.pushSubscriptionModel)

        appendToQueue(request)
        executePendingRequests()
    }

    /**
     For migrating legacy players from 3.x to 5.x. This request will fetch the identity object for a subscription ID, and we will use the returned onesignalId to fetch and hydrate the local user.
     */
    static func executeFetchIdentityBySubscriptionRequest(_ request: OSRequestFetchIdentityBySubscription) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            return
        }
        request.sentToClient = true

        OneSignalClient.shared().execute(request) { response in
            removeFromQueue(request)

            if let identityObject = parseIdentityObjectResponse(response),
               let onesignalId = identityObject[OS_ONESIGNAL_ID] {
                request.identityModel.hydrate(identityObject)

                // Fetch this user's data if it is the current user
                guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel)
                else {
                    executePendingRequests()
                    return
                }

                fetchUser(aliasLabel: OS_ONESIGNAL_ID, aliasId: onesignalId, identityModel: request.identityModel)
            }
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor executeFetchIdentityBySubscriptionRequest failed with error: \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    // Fail, no retry, remove the subscription_id but keep the same push subscription model
                    OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = nil
                    removeFromQueue(request)
                }
            }
            executePendingRequests()
        }
    }

    static func identifyUser(externalId: String, identityModelToIdentify: OSIdentityModel, identityModelToUpdate: OSIdentityModel) {
        let request = OSRequestIdentifyUser(
            aliasLabel: OS_EXTERNAL_ID,
            aliasId: externalId,
            identityModelToIdentify: identityModelToIdentify,
            identityModelToUpdate: identityModelToUpdate
        )

        appendToQueue(request)

        executePendingRequests()
    }

    static func executeIdentifyUserRequest(_ request: OSRequestIdentifyUser) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            // Missing onesignal_id
            return
        }
        request.sentToClient = true

        OneSignalClient.shared().execute(request) { _ in
            removeFromQueue(request)

            // the anonymous user has been identified, still need to Fetch User as we cleared local data
            // Fetch the user only if its the current user
            if OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModelToUpdate) {
                fetchUser(aliasLabel: OS_EXTERNAL_ID, aliasId: request.aliasId, identityModel: request.identityModelToUpdate)
            } else {
                executePendingRequests()
            }
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "executeIdentifyUserRequest failed with error \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType == .conflict {
                    // Returns 409 if any provided (label, id) pair exists on another User, so the SDK will switch to this user.
                    OneSignalLog.onesignalLog(.LL_DEBUG, message: "executeIdentifyUserRequest returned error code user-2. Now handling user-2 error response... switch to this user.")

                    removeFromQueue(request)
                    // Fetch the user only if its the current user
                    if OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModelToUpdate) {
                        fetchUser(aliasLabel: OS_EXTERNAL_ID, aliasId: request.aliasId, identityModel: request.identityModelToUpdate)
                        // TODO: Link ^ to the new user... what was this todo for?
                    }
                    transferPushSubscriptionTo(aliasLabel: request.aliasLabel, aliasId: request.aliasId)
                } else if responseType == .invalid || responseType == .unauthorized {
                    // Failed, no retry
                    removeFromQueue(request)
                    executePendingRequests()
                } else if responseType == .missing {
                    removeFromQueue(request)
                    executePendingRequests()
                    // Logout if the user in the SDK is the same
                    guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModelToUpdate)
                    else {
                        return
                    }
                    // The subscription has been deleted along with the user, so remove the subscription_id but keep the same push subscription model
                    OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = nil
                    OneSignalUserManagerImpl.sharedInstance._logout()
                }
            } else {
                executePendingRequests()
            }
        }
    }

    static func transferPushSubscriptionTo(aliasLabel: String, aliasId: String) {
        // TODO: Where to get pushSubscriptionModel for this request
        let request = OSRequestTransferSubscription(
            subscriptionModel: OneSignalUserManagerImpl.sharedInstance.user.pushSubscriptionModel,
            aliasLabel: aliasLabel,
            aliasId: aliasId
        )

        appendToQueue(request)

        executePendingRequests()
    }

    static func executeTransferPushSubscriptionRequest(_ request: OSRequestTransferSubscription) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            // Missing subscriptionId
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSUserExecutor.executeTransferPushSubscriptionRequest with request \(request) cannot be executed due to failing prepareForExecution()")
            return
        }
        request.sentToClient = true
        OneSignalClient.shared().execute(request) { _ in
            removeFromQueue(request)

            // TODO: ... hydrate with returned identity object?
            executePendingRequests()

        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor executeTransferPushSubscriptionRequest failed with error: \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType != .retryable {
                    // Fail, no retry, remove from cache and queue
                    removeFromQueue(request)
                }
            }
            executePendingRequests()
        }
    }

    static func fetchUser(aliasLabel: String, aliasId: String, identityModel: OSIdentityModel, onNewSession: Bool = false) {
        let request = OSRequestFetchUser(identityModel: identityModel, aliasLabel: aliasLabel, aliasId: aliasId, onNewSession: onNewSession)

        appendToQueue(request)

        executePendingRequests()
    }

    static func executeFetchUserRequest(_ request: OSRequestFetchUser) {
        guard !request.sentToClient else {
            return
        }
        guard request.prepareForExecution() else {
            // This should not happen as we set the alias to use for the request path
            return
        }
        request.sentToClient = true
        OneSignalClient.shared().execute(request) { response in
            removeFromQueue(request)

            if let response = response {
                // Clear local data in preparation for hydration
                OneSignalUserManagerImpl.sharedInstance.clearUserData()
                parseFetchUserResponse(response: response, identityModel: request.identityModel, originalPushToken: OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.token)

                // If this is a on-new-session's fetch user call, check that the subscription still exists
                if request.onNewSession,
                   OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel),
                   let subId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId,
                   let subscriptionObjects = parseSubscriptionObjectResponse(response) {
                    var subscriptionExists = false
                    for subModel in subscriptionObjects {
                        if subModel["id"] as? String == subId {
                            subscriptionExists = true
                            break
                        }
                    }

                    if !subscriptionExists {
                        // This subscription probably has been deleted
                        OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor.executeFetchUserRequest found this device's push subscription gone, now send the push subscription to server.")
                        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = nil
                        OneSignalUserManagerImpl.sharedInstance.createPushSubscriptionRequest()
                    }
                }
            }
            executePendingRequests()
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor executeFetchUserRequest failed with error: \(error.debugDescription)")
            if let nsError = error as? NSError {
                let responseType = OSNetworkingUtils.getResponseStatusType(nsError.code)
                if responseType == .missing {
                    removeFromQueue(request)
                    // Logout if the user in the SDK is the same
                    guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel)
                    else {
                        return
                    }
                    // The subscription has been deleted along with the user, so remove the subscription_id but keep the same push subscription model
                    OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = nil
                    OneSignalUserManagerImpl.sharedInstance._logout()
                } else if responseType != .retryable {
                    // If the error is not retryable, remove from cache and queue
                    removeFromQueue(request)
                }
            }
            executePendingRequests()
        }
    }
}

// MARK: - Parsing
extension OSUserExecutor {
    /**
     Used to parse Create User and Fetch User responses. The `originalPushToken` is the push token when the request was created, which may be different from the push token currently in the SDK. For example, when the request was created, there may be no push token yet, but soon after, the SDK receives a push token. This is used to determine whether or not to hydrate the push subscription.
     */
    static func parseFetchUserResponse(response: [AnyHashable: Any], identityModel: OSIdentityModel, originalPushToken: String?) {

        // If this was a create user, it hydrates the onesignal_id of the request's identityModel
        // The model in the store may be different, and it may be waiting on the onesignal_id of this previous model
        if let identityObject = parseIdentityObjectResponse(response) {
            identityModel.hydrate(identityObject)
        }

        // TODO: Determine how to hydrate the push subscription, which is still faulty.
        // Hydrate by token if sub_id exists?
        // Problem: a user can have multiple iOS push subscription, and perhaps missing token
        // Ideally we only get push subscription for this device in the response, not others

        // Hydrate the push subscription if we don't already have a subscription ID AND token matches the original request
        if (OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId == nil),
           let subscriptionObject = parseSubscriptionObjectResponse(response) {
            for subModel in subscriptionObject {
                if subModel["type"] as? String == "iOSPush",
                   areTokensEqual(tokenA: originalPushToken, tokenB: subModel["token"] as? String) { // response may have "" token or no token
                    OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.hydrate(subModel)
                    if let subId = subModel["id"] as? String {
                        OSNotificationsManager.setPushSubscriptionId(subId)
                    }
                    break
                }
            }
        }

        // Check if the current user is the same as the one in the request
        // If user has changed, don't hydrate, except for push subscription above
        guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(identityModel) else {
            return
        }

        if let identityObject = parseIdentityObjectResponse(response) {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.hydrate(identityObject)
        }

        if let propertiesObject = parsePropertiesObjectResponse(response) {
            OneSignalUserManagerImpl.sharedInstance.user.propertiesModel.hydrate(propertiesObject)
        }

        // Now parse email and sms subscriptions
        if let subscriptionObject = parseSubscriptionObjectResponse(response) {
            let models = OneSignalUserManagerImpl.sharedInstance.subscriptionModelStore.getModels()
            for subModel in subscriptionObject {
                if let address = subModel["token"] as? String,
                   let rawType = subModel["type"] as? String,
                   rawType != "iOSPush",
                   let type = OSSubscriptionType(rawValue: rawType) {
                    if let model = models[address] {
                        // This subscription exists in the store, hydrate
                        model.hydrate(subModel)

                    } else {
                        // This subscription does not exist in the store, add
                        OneSignalUserManagerImpl.sharedInstance.subscriptionModelStore.add(id: address, model: OSSubscriptionModel(
                            type: type,
                            address: address,
                            subscriptionId: subModel["id"] as? String,
                            reachable: true,
                            isDisabled: false,
                            changeNotifier: OSEventProducer()), hydrating: true
                        )
                    }
                }
            }
        }
    }

    /**
     Returns if 2 tokens are equal. This is needed as a nil token is equal to the empty string "".
     */
    static func areTokensEqual(tokenA: String?, tokenB: String?) -> Bool {
        // They are both strings or both nil
        if tokenA == tokenB {
            return true
        }
        // One is nil and the other is ""
        if (tokenA == nil && tokenB == "") || (tokenA == "" && tokenB == nil) {
            return true
        }
        return false
    }

    static func parseSubscriptionObjectResponse(_ response: [AnyHashable: Any]?) -> [[String: Any]]? {
        return response?["subscriptions"] as? [[String: Any]]
    }

    static func parsePropertiesObjectResponse(_ response: [AnyHashable: Any]?) -> [String: Any]? {
        return response?["properties"] as? [String: Any]
    }

    static func parseIdentityObjectResponse(_ response: [AnyHashable: Any]?) -> [String: String]? {
        return response?["identity"] as? [String: String]
    }
}
