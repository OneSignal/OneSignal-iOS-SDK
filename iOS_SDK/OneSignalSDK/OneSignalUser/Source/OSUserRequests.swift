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

// MARK: - User Request Classes

protocol OSUserRequest: OneSignalRequest, NSCoding {
    var sentToClient: Bool { get set }
    func prepareForExecution() -> Bool
}

// TODO: Confirm the type of the things in the parameters field
// TODO: Don't hardcode the strings?

/**
 This request will be made with the minimum information needed. The payload will contain an externalId or no identities.
 The push subscription may or may not have a token or suscriptionId already.
 There will be no properties sent.
 */
class OSRequestCreateUser: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    var identityModel: OSIdentityModel
    var pushSubscriptionModel: OSSubscriptionModel
    var originalPushToken: String?

    func prepareForExecution() -> Bool {
        guard let appId = OneSignalConfigManager.getAppId() else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the create user request due to null app ID.")
            return false
        }
        self.addJWTHeader(identityModel: identityModel)
        self.path = "apps/\(appId)/users"
        // The pushSub doesn't need to have a token.
        return true
    }

    // When reading from the cache, update the push subscription model
    func updatePushSubscriptionModel(_ pushSubscriptionModel: OSSubscriptionModel) {
        self.pushSubscriptionModel = pushSubscriptionModel
        self.parameters?["subscriptions"] = [pushSubscriptionModel.jsonRepresentation()]
        self.originalPushToken = pushSubscriptionModel.address
    }

    init(identityModel: OSIdentityModel, propertiesModel: OSPropertiesModel, pushSubscriptionModel: OSSubscriptionModel, originalPushToken: String?) {
        self.identityModel = identityModel
        self.pushSubscriptionModel = pushSubscriptionModel
        self.originalPushToken = originalPushToken
        self.stringDescription = "OSRequestCreateUser"
        super.init()

        var params: [String: Any] = [:]

        // Identity Object
        params["identity"] = [:]
        if let externalId = identityModel.externalId {
            params["identity"] = [OS_EXTERNAL_ID: externalId]
        }

        // Properties Object
        var propertiesObject: [String: Any] = [:]
        propertiesObject["language"] = propertiesModel.language
        propertiesObject["timezone_id"] = propertiesModel.timezoneId
        params["properties"] = propertiesObject

        self.parameters = params
        self.updatePushSubscriptionModel(pushSubscriptionModel)
        self.method = POST
    }

    func encode(with coder: NSCoder) {
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(pushSubscriptionModel, forKey: "pushSubscriptionModel")
        coder.encode(originalPushToken, forKey: "originalPushToken")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(path, forKey: "path")
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let pushSubscriptionModel = coder.decodeObject(forKey: "pushSubscriptionModel") as? OSSubscriptionModel,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any],
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let path = coder.decodeObject(forKey: "path") as? String,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.pushSubscriptionModel = pushSubscriptionModel
        self.originalPushToken = coder.decodeObject(forKey: "originalPushToken") as? String
        self.stringDescription = "OSRequestCreateUser"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.path = path
        self.timestamp = timestamp
    }
}

class OSRequestFetchIdentityBySubscription: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String

    override var description: String {
        return stringDescription
    }

    var identityModel: OSIdentityModel
    var pushSubscriptionModel: OSSubscriptionModel

    func prepareForExecution() -> Bool {
        guard let appId = OneSignalConfigManager.getAppId() else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the FetchIdentityBySubscription request due to null app ID.")
            return false
        }

        if let subscriptionId = pushSubscriptionModel.subscriptionId {
            self.path = "apps/\(appId)/subscriptions/\(subscriptionId)/user/identity"
            return true
        } else {
            // This is an error, and should never happen
            OneSignalLog.onesignalLog(.LL_ERROR, message: "Cannot generate the FetchIdentityBySubscription request due to null subscriptionId.")
            self.path = ""
            return false
        }
    }

    init(identityModel: OSIdentityModel, pushSubscriptionModel: OSSubscriptionModel) {
        self.identityModel = identityModel
        self.pushSubscriptionModel = pushSubscriptionModel
        self.stringDescription = "OSRequestFetchIdentityBySubscription with subscriptionId: \(pushSubscriptionModel.subscriptionId ?? "nil")"
        super.init()
        self.method = GET
    }

    func encode(with coder: NSCoder) {
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(pushSubscriptionModel, forKey: "pushSubscriptionModel")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let pushSubscriptionModel = coder.decodeObject(forKey: "pushSubscriptionModel") as? OSSubscriptionModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.pushSubscriptionModel = pushSubscriptionModel

        self.stringDescription = "OSRequestFetchIdentityBySubscription with subscriptionId: \(pushSubscriptionModel.subscriptionId ?? "nil")"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
    }
}

/**
 The `identityModelToIdentify` is used for the `onesignal_id` of the user we want to associate with this alias.
 This request will tell us if we should continue with the previous user who is now identitfied, or to change users to the one this alias already exists on.
 
 Note: The SDK needs an user to operate on before this request returns. However, at the time of this request's creation, the SDK does not know if there is already an user associated with this alias. So, it creates a blank new user (whose identity model is passed in as `identityModelToUpdate`,
 which is the model used to make a subsequent ``OSRequestFetchUser``).
 */
class OSRequestIdentifyUser: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    var identityModelToIdentify: OSIdentityModel
    var identityModelToUpdate: OSIdentityModel
    let aliasLabel: String
    let aliasId: String

    // requires a onesignal_id to send this request
    func prepareForExecution() -> Bool {
        if let onesignalId = identityModelToIdentify.onesignalId, let appId = OneSignalConfigManager.getAppId() {
            self.addJWTHeader(identityModel: identityModelToIdentify)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/identity"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    /**
     - Parameters:
        - aliasLabel: The alias label we want to identify this user with.
        - aliasId: The alias ID we want to identify this user with.
        - identityModelToIdentify: Belongs to the user we want to identify with this alias.
        - identityModelToUpdate: Belongs to the user we want to send in the subsequent ``OSRequestFetchUser`` that is made when this request returns.
     */
    init(aliasLabel: String, aliasId: String, identityModelToIdentify: OSIdentityModel, identityModelToUpdate: OSIdentityModel) {
        self.identityModelToIdentify = identityModelToIdentify
        self.identityModelToUpdate = identityModelToUpdate
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.stringDescription = "OSRequestIdentifyUser with aliasLabel: \(aliasLabel) aliasId: \(aliasId)"
        super.init()
        self.parameters = ["identity": [aliasLabel: aliasId]]
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(identityModelToIdentify, forKey: "identityModelToIdentify")
        coder.encode(identityModelToUpdate, forKey: "identityModelToUpdate")
        coder.encode(aliasLabel, forKey: "aliasLabel")
        coder.encode(aliasId, forKey: "aliasId")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModelToIdentify = coder.decodeObject(forKey: "identityModelToIdentify") as? OSIdentityModel,
            let identityModelToUpdate = coder.decodeObject(forKey: "identityModelToUpdate") as? OSIdentityModel,
            let aliasLabel = coder.decodeObject(forKey: "aliasLabel") as? String,
            let aliasId = coder.decodeObject(forKey: "aliasId") as? String,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: [String: String]],
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModelToIdentify = identityModelToIdentify
        self.identityModelToUpdate = identityModelToUpdate
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.stringDescription = "OSRequestIdentifyUser with aliasLabel: \(aliasLabel) aliasId: \(aliasId)"
        super.init()
        self.timestamp = timestamp
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        _ = prepareForExecution()
    }
}

/**
 If an alias is passed in, it will be used to fetch the user. If not, then by default, use the `onesignal_id` in the `identityModel` to fetch the user.
 The `identityModel` is also used to reference the user that is updated with the response.
 */
class OSRequestFetchUser: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let identityModel: OSIdentityModel
    let aliasLabel: String
    let aliasId: String
    let onNewSession: Bool

    func prepareForExecution() -> Bool {
        guard let appId = OneSignalConfigManager.getAppId() else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the fetch user request due to null app ID.")
            return false
        }
        self.addJWTHeader(identityModel: identityModel)
        self.path = "apps/\(appId)/users/by/\(aliasLabel)/\(aliasId)"
        return true
    }

    init(identityModel: OSIdentityModel, aliasLabel: String, aliasId: String, onNewSession: Bool) {
        self.identityModel = identityModel
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.onNewSession = onNewSession
        self.stringDescription = "OSRequestFetchUser with aliasLabel: \(aliasLabel) aliasId: \(aliasId)"
        super.init()
        self.method = GET
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(aliasLabel, forKey: "aliasLabel")
        coder.encode(aliasId, forKey: "aliasId")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(onNewSession, forKey: "onNewSession")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let aliasLabel = coder.decodeObject(forKey: "aliasLabel") as? String,
            let aliasId = coder.decodeObject(forKey: "aliasId") as? String,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.onNewSession = coder.decodeBool(forKey: "onNewSession")
        self.stringDescription = "OSRequestFetchUser with aliasLabel: \(aliasLabel) aliasId: \(aliasId)"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

class OSRequestAddAliases: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    var identityModel: OSIdentityModel
    let aliases: [String: String]

    // requires a `onesignal_id` to send this request
    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId, let appId = OneSignalConfigManager.getAppId() {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/identity"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(aliases: [String: String], identityModel: OSIdentityModel) {
        self.identityModel = identityModel
        self.aliases = aliases
        self.stringDescription = "OSRequestAddAliases with aliases: \(aliases)"
        super.init()
        self.parameters = ["identity": aliases]
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(aliases, forKey: "aliases")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let aliases = coder.decodeObject(forKey: "aliases") as? [String: String],
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: [String: String]],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.aliases = aliases
        self.stringDescription = "OSRequestAddAliases with parameters: \(parameters)"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

class OSRequestRemoveAlias: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let labelToRemove: String
    var identityModel: OSIdentityModel

    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId, let appId = OneSignalConfigManager.getAppId() {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/identity/\(labelToRemove)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(labelToRemove: String, identityModel: OSIdentityModel) {
        self.labelToRemove = labelToRemove
        self.identityModel = identityModel
        self.stringDescription = "OSRequestRemoveAlias with aliasLabel: \(labelToRemove)"
        super.init()
        self.method = DELETE
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(labelToRemove, forKey: "labelToRemove")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let labelToRemove = coder.decodeObject(forKey: "labelToRemove") as? String,
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.labelToRemove = labelToRemove
        self.identityModel = identityModel
        self.stringDescription = "OSRequestRemoveAlias with aliasLabel: \(labelToRemove)"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

class OSRequestUpdateProperties: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    // TODO: does updating properties even have a response in which we need to hydrate from? Then we can get rid of modelToUpdate
    // Yes we may, if we cleared local state
    var modelToUpdate: OSPropertiesModel
    var identityModel: OSIdentityModel

    // TODO: Decide if addPushSubscriptionIdToAdditionalHeadersIfNeeded should block.
    // Note Android adds it to requests, if the push sub ID exists
    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId,
            let appId = OneSignalConfigManager.getAppId(),
           addPushSubscriptionIdToAdditionalHeadersIfNeeded() {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    func addPushSubscriptionIdToAdditionalHeadersIfNeeded() -> Bool {
        guard let parameters = self.parameters else {
            return true
        }
        if parameters["deltas"] != nil { // , !parameters["deltas"].isEmpty
            if let pushSubscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId {
                var additionalHeaders = self.additionalHeaders ?? [String: String]()
                additionalHeaders["OneSignal-Subscription-Id"] = pushSubscriptionId
                self.additionalHeaders = additionalHeaders
                return true
            } else {
                return false
            }
        }
        return true
    }

    init(properties: [String: Any], deltas: [String: Any]?, refreshDeviceMetadata: Bool?, modelToUpdate: OSPropertiesModel, identityModel: OSIdentityModel) {
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        self.stringDescription = "OSRequestUpdateProperties with properties: \(properties) deltas: \(String(describing: deltas)) refreshDeviceMetadata: \(String(describing: refreshDeviceMetadata))"
        super.init()

        var propertiesObject = properties
        if let location = propertiesObject["location"] as? OSLocationPoint {
            propertiesObject["lat"] = location.lat
            propertiesObject["long"] = location.long
            propertiesObject.removeValue(forKey: "location")
        }
        var params: [String: Any] = [:]
        params["properties"] = propertiesObject
        params["refresh_device_metadata"] = refreshDeviceMetadata
        if let deltas = deltas {
            params["deltas"] = deltas
        }
        self.parameters = params
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(modelToUpdate, forKey: "modelToUpdate")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let modelToUpdate = coder.decodeObject(forKey: "modelToUpdate") as? OSPropertiesModel,
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        self.stringDescription = "OSRequestUpdateProperties with parameters: \(parameters)"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

/**
 Primary uses of this request are for adding Email and SMS subscriptions. Push subscriptions typically won't be created using
 this request because they will be created with ``OSRequestCreateUser``. However, if we detect that this device's
 push subscription is ever deleted, we will make a request to create it again.
 */
class OSRequestCreateSubscription: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    var subscriptionModel: OSSubscriptionModel
    var identityModel: OSIdentityModel

    // Need the onesignal_id of the user
    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId, let appId = OneSignalConfigManager.getAppId() {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/subscriptions"
            return true
        } else {
            self.path = "" // self.path is non-nil, so set to empty string
            return false
        }
    }

    init(subscriptionModel: OSSubscriptionModel, identityModel: OSIdentityModel) {
        self.subscriptionModel = subscriptionModel
        self.identityModel = identityModel
        self.stringDescription = "OSRequestCreateSubscription with subscriptionModel: \(subscriptionModel.address ?? "nil")"
        super.init()
        self.parameters = ["subscription": subscriptionModel.jsonRepresentation()]
        self.method = POST
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(subscriptionModel, forKey: "subscriptionModel")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let subscriptionModel = coder.decodeObject(forKey: "subscriptionModel") as? OSSubscriptionModel,
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.subscriptionModel = subscriptionModel
        self.identityModel = identityModel
        self.stringDescription = "OSRequestCreateSubscription with subscriptionModel: \(subscriptionModel.address ?? "nil")"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

/**
 Transfers the Subscription specified by the subscriptionId to the User identified by the identity in the payload.
 Only one entry is allowed, `onesignal_id` or an Alias. We will use the alias specified.
 The anticipated usage of this request is only for push subscriptions.
 */
class OSRequestTransferSubscription: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    var subscriptionModel: OSSubscriptionModel
    let aliasLabel: String
    let aliasId: String

    // Need an alias and subscription_id
    func prepareForExecution() -> Bool {
        if let subscriptionId = subscriptionModel.subscriptionId, let appId = OneSignalConfigManager.getAppId() {
            self.path = "apps/\(appId)/subscriptions/\(subscriptionId)/owner"
            // TODO: self.addJWTHeader(identityModel: identityModel) ??
            return true
        } else {
            self.path = "" // self.path is non-nil, so set to empty string
            return false
        }
    }

    /**
     Must pass an Alias pair to identify the User.
     */
    init(
        subscriptionModel: OSSubscriptionModel,
        aliasLabel: String,
        aliasId: String
    ) {
        self.subscriptionModel = subscriptionModel
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.stringDescription = "OSRequestTransferSubscription"
        super.init()
        self.parameters = ["identity": [aliasLabel: aliasId]]
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(subscriptionModel, forKey: "subscriptionModel")
        coder.encode(aliasLabel, forKey: "aliasLabel")
        coder.encode(aliasId, forKey: "aliasId")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let subscriptionModel = coder.decodeObject(forKey: "subscriptionModel") as? OSSubscriptionModel,
            let aliasLabel = coder.decodeObject(forKey: "aliasLabel") as? String,
            let aliasId = coder.decodeObject(forKey: "aliasId") as? String,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.subscriptionModel = subscriptionModel
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.stringDescription = "OSRequestTransferSubscription"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

/**
 Currently, only the Push Subscription will make this Update Request.
 */
class OSRequestUpdateSubscription: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    var subscriptionModel: OSSubscriptionModel

    // Need the subscription_id
    func prepareForExecution() -> Bool {
        if let subscriptionId = subscriptionModel.subscriptionId, let appId = OneSignalConfigManager.getAppId() {
            self.path = "apps/\(appId)/subscriptions/\(subscriptionId)"
            return true
        } else {
            self.path = "" // self.path is non-nil, so set to empty string
            return false
        }
    }

    // TODO: just need the sub model and send it
    // But the model may be outdated or not sync with the subscriptionObject
    init(subscriptionObject: [String: Any], subscriptionModel: OSSubscriptionModel) {
        self.subscriptionModel = subscriptionModel
        self.stringDescription = "OSRequestUpdateSubscription with subscriptionObject: \(subscriptionObject)"
        super.init()

        // Rename "address" key as "token", if it exists
        var subscriptionParams = subscriptionObject
        subscriptionParams.removeValue(forKey: "address")
        subscriptionParams.removeValue(forKey: "notificationTypes")
        subscriptionParams["token"] = subscriptionModel.address
        subscriptionParams["device_os"] = subscriptionModel.deviceOs
        subscriptionParams["sdk"] = subscriptionModel.sdk
        subscriptionParams["app_version"] = subscriptionModel.appVersion

        // notificationTypes defaults to -1 instead of nil, don't send if it's -1
        if subscriptionModel.notificationTypes != -1 {
            subscriptionParams["notification_types"] = subscriptionModel.notificationTypes
        }

        subscriptionParams["enabled"] = subscriptionModel.enabled
        // TODO: The above is not quite right. If we hydrate, we will over-write any pending updates
        // May use subscriptionObject, but enabled and notification_types should be sent together...

        self.parameters = ["subscription": subscriptionParams]
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(subscriptionModel, forKey: "subscriptionModel")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let subscriptionModel = coder.decodeObject(forKey: "subscriptionModel") as? OSSubscriptionModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.subscriptionModel = subscriptionModel
        self.stringDescription = "OSRequestUpdateSubscription with parameters: \(parameters)"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

/**
 Delete the subscription specified by the `subscriptionId` in the `subscriptionModel`.
 Prior to the creation of this request, this model has already been removed from the model store.
 - Remark: If this model did not already exist in the store, no request is created.
 */
class OSRequestDeleteSubscription: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    var subscriptionModel: OSSubscriptionModel

    // Need the subscription_id
    func prepareForExecution() -> Bool {
        if let subscriptionId = subscriptionModel.subscriptionId, let appId = OneSignalConfigManager.getAppId() {
            self.path = "apps/\(appId)/subscriptions/\(subscriptionId)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(subscriptionModel: OSSubscriptionModel) {
        self.subscriptionModel = subscriptionModel
        self.stringDescription = "OSRequestDeleteSubscription with subscriptionModel: \(subscriptionModel.address ?? "nil")"
        super.init()
        self.method = DELETE
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(subscriptionModel, forKey: "subscriptionModel")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let subscriptionModel = coder.decodeObject(forKey: "subscriptionModel") as? OSSubscriptionModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.subscriptionModel =  subscriptionModel
        self.stringDescription = "OSRequestDeleteSubscription with subscriptionModel: \(subscriptionModel.address ?? "nil")"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

internal extension OneSignalRequest {
    func addJWTHeader(identityModel: OSIdentityModel) {
//        guard let token = identityModel.jwtBearerToken else {
//            return
//        }
//        var additionalHeaders = self.additionalHeaders ?? [String:String]()
//        additionalHeaders["Authorization"] = "Bearer \(token)"
//        self.additionalHeaders = additionalHeaders
    }
}
