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
 Can execute `OSRequestCreateUser`, `OSRequestIdentifyUser`, `OSRequestFetchUser`, `OSRequestFetchIdentityBySubscription`.
 */
class OSUserExecutor {
    var userRequestQueue: [OSUserRequest] = []
    private let newRecordsState: OSNewRecordsState
    let jwtConfig: OSUserJwtConfig

    /// Delay by the "cool down" period plus a buffer of a set amount of milliseconds
    private let flushDelayMilliseconds = Int(OP_REPO_POST_CREATE_DELAY_SECONDS * 1_000 + 200) // TODO: This could come from a config, plist, method, remote params

    /// The User executor dispatch queue, serial. This synchronizes access to the request queues.
    private let dispatchQueue = DispatchQueue(label: "OneSignal.OSUserExecutor", target: .global())

    init(newRecordsState: OSNewRecordsState, jwtConfig: OSUserJwtConfig) {
        self.newRecordsState = newRecordsState
        self.jwtConfig = jwtConfig
        self.jwtConfig.subscribe(self, key: OS_USER_EXECUTOR)
        print("❌ OSUserExecutor init requiresAuth: \(jwtConfig.isRequired)")

        uncacheUserRequests()
        migrateTransferSubscriptionRequests()
        executePendingRequests()
    }

    /// Read in requests from the cache, do not read in FetchUser requests as this is not needed.
    private func uncacheUserRequests() {
        var userRequestQueue: [OSUserRequest] = []
        print(" OSUserExecutor uncacheUserRequests called")
        // Read unfinished Create User + Identify User + Get Identity By Subscription requests from cache, if any...
        if let cachedRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSUserRequest] {
            print(" OSUserExecutor uncacheUserRequests cachedQueue is \(cachedRequestQueue)")

            // Hook each uncached Request to the right model reference
            for request in cachedRequestQueue {
                if request.isKind(of: OSRequestFetchIdentityBySubscription.self), let req = request as? OSRequestFetchIdentityBySubscription {
                    // Remove this request if JWT is enabled
                    guard jwtConfig.isRequired != true else {
                        print(" uncacheUserRequests dropping request \(req)")
                        continue
                    }
                    if let identityModel = getIdentityModel(req.identityModel.modelId) {
                        // 1. The model exist in the repo, set it to be the Request's model
                        // It is the current user or the model has already been processed
                        req.identityModel = identityModel
                    } else {
                        // 2. The model do not exist, use the model on the request, and add to repo.
                        addIdentityModel(req.identityModel)
                    }
                    userRequestQueue.append(req)

                } else if request.isKind(of: OSRequestCreateUser.self), let req = request as? OSRequestCreateUser {

                    if jwtConfig.isRequired == true,
                       req.identityModel.externalId == nil
                    {
                        // Remove this request if there is no EUID
                        print(" uncacheUserRequests dropping request \(req)")
                        continue
                    }

                    if let identityModel = getIdentityModel(req.identityModel.modelId) {
                        // 1. The model exist in the repo, set it to be the Request's model
                        req.identityModel = identityModel
                    } else {
                        // 2. The models do not exist, use the model on the request, and add to repo.
                        addIdentityModel(req.identityModel)
                    }
                    userRequestQueue.append(req)

                } else if request.isKind(of: OSRequestIdentifyUser.self), let req = request as? OSRequestIdentifyUser {

                    // If JWT is enabled, we migrate this request into a Create User request
                    guard jwtConfig.isRequired != true else {
                        print(" uncacheUserRequests converting \(req) to createUser")
                        convertIdentifyUserToCreateUser(req)
                        continue
                    }

                    if let identityModelToIdentify = getIdentityModel(req.identityModelToIdentify.modelId),
                       let identityModelToUpdate = getIdentityModel(req.identityModelToUpdate.modelId) {
                        // 1. Both models exist in the repo, set it to be the Request's models
                        req.identityModelToIdentify = identityModelToIdentify
                        req.identityModelToUpdate = identityModelToUpdate
                    } else if let identityModelToIdentify = getIdentityModel(req.identityModelToIdentify.modelId),
                              getIdentityModel(req.identityModelToUpdate.modelId) == nil {
                        // 2. A model is in the repo, the other model does not exist
                        req.identityModelToIdentify = identityModelToIdentify
                        addIdentityModel(req.identityModelToUpdate)
                    } else {
                        // 3. Both models don't exist yet
                        // Drop the request if the identityModelToIdentify does not already exist AND the request is missing OSID
                        // Otherwise, this request will forever fail `prepareForExecution` and block pending requests such as recovery calls to `logout` or `login`
                        guard request.prepareForExecution(newRecordsState: newRecordsState) else {
                            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor.start() dropped: \(request)")
                            continue
                        }
                        addIdentityModel(req.identityModelToIdentify)
                        addIdentityModel(req.identityModelToUpdate)
                    }
                    userRequestQueue.append(req)
                }
            }
        }
        self.userRequestQueue = userRequestQueue
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, withValue: self.userRequestQueue)
        print(" OSUserExecutor uncacheUserRequests done, now has queue: \(self.userRequestQueue)")
    }

    /**
     Read Transfer Subscription requests from cache, if any.
     As of `5.2.3`, the SDK will no longer send Transfer Subscription requests, so migrate the request into an equivalent Create User request.
     */
    private func migrateTransferSubscriptionRequests() {
        if let transferSubscriptionRequestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_USER_EXECUTOR_TRANSFER_SUBSCRIPTION_REQUEST_QUEUE_KEY, defaultValue: nil) as? [OSRequestTransferSubscription] {
            OneSignalUserDefaults.initShared().removeValue(forKey: OS_USER_EXECUTOR_TRANSFER_SUBSCRIPTION_REQUEST_QUEUE_KEY)

            // Translate the last request into a Create User request, if the current user is the same
            if let request = transferSubscriptionRequestQueue.last,
               let userInstance = OneSignalUserManagerImpl.sharedInstance._user,
               OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.aliasId) {
                createUser(userInstance)
            }
        }
    }

    private func convertIdentifyUserToCreateUser(_ request: OSRequestIdentifyUser) {
        if OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.aliasId) {
            self.createUser(OneSignalUserManagerImpl.sharedInstance.user)
        } else {
            self.createUser(aliasLabel: request.aliasLabel, aliasId: request.aliasId, identityModel: request.identityModelToUpdate)
        }
    }

    private func getIdentityModel(_ modelId: String) -> OSIdentityModel? {
        return OneSignalUserManagerImpl.sharedInstance.getIdentityModel(modelId)
    }

    private func addIdentityModel(_ model: OSIdentityModel) {
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(model)
    }

    func appendToQueue(_ request: OSUserRequest) {
        self.dispatchQueue.async {
            self.userRequestQueue.append(request)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, withValue: self.userRequestQueue)
        }
    }

    func removeFromQueue(_ request: OSUserRequest) {
        self.dispatchQueue.async {
            self.userRequestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, withValue: self.userRequestQueue)
        }
    }

    /**
     When Identity Verification is on, only `OSRequestCreateUser` and `OSRequestFetchUser` can be executed.
     Other requests should already be removed or translated into an executable type by the time this method runs.
     */
    private func executePendingRequestsWithAuth() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSUserExecutor.executePendingRequestsWithAuth called with queue \(self.userRequestQueue)")

        for request in self.userRequestQueue {
            if request.isKind(of: OSRequestCreateUser.self), let createUserRequest = request as? OSRequestCreateUser {
                self.executeCreateUserRequest(createUserRequest)
            } else if request.isKind(of: OSRequestFetchUser.self), let fetchUserRequest = request as? OSRequestFetchUser {
                self.executeFetchUserRequest(fetchUserRequest)
            } else {
                OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor met incompatible Request type that cannot be executed.")
                self.removeFromQueue(request)
            }
        }
    }

    /**
     Requests are flushed after a delay when they need to wait for the "cool down" period to access a user or subscription after its creation.
     */
    func executePendingRequests(withDelay: Bool = false) {
        guard jwtConfig.isRequired != nil else {
            print("❌ OSUserExecutor.executePendingRequests returning early due to unknown Identity Verification status.")
            return
        }

        if withDelay {
            self.dispatchQueue.asyncAfter(deadline: .now() + .milliseconds(flushDelayMilliseconds)) { [weak self] in
                self?._executePendingRequests()
            }
        } else {
            self.dispatchQueue.async {
                self._executePendingRequests()
            }
        }
    }

    private func _executePendingRequests() {
        guard let requiresAuth = jwtConfig.isRequired else {
            return
        }

        if requiresAuth {
            executePendingRequestsWithAuth()
        } else {
            executePendingRequestsWithoutAuth()
        }
    }

    private func executePendingRequestsWithoutAuth() {
        // same as executePendingRequests currently
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSUserExecutor.executePendingRequestsWithoutAuth called with queue \(self.userRequestQueue)")

        for request in self.userRequestQueue {
            // Return as soon as we reach an un-executable request
            guard request.prepareForExecution(newRecordsState: self.newRecordsState)
            else {
                OneSignalLog.onesignalLog(.LL_WARN, message: "OSUserExecutor.executePendingRequests() is blocked by unexecutable request \(request)")
                executePendingRequests(withDelay: true)
                return
            }

            if request.isKind(of: OSRequestFetchIdentityBySubscription.self), let fetchIdentityRequest = request as? OSRequestFetchIdentityBySubscription {
                self.executeFetchIdentityBySubscriptionRequest(fetchIdentityRequest)
                return
            } else if request.isKind(of: OSRequestCreateUser.self), let createUserRequest = request as? OSRequestCreateUser {
                self.executeCreateUserRequest(createUserRequest)
                return
            } else if request.isKind(of: OSRequestIdentifyUser.self), let identifyUserRequest = request as? OSRequestIdentifyUser {
                self.executeIdentifyUserRequest(identifyUserRequest)
                return
            } else if request.isKind(of: OSRequestFetchUser.self), let fetchUserRequest = request as? OSRequestFetchUser {
                self.executeFetchUserRequest(fetchUserRequest)
                return
            } else {
                OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor met incompatible Request type that cannot be executed.")
                self.removeFromQueue(request)
            }
        }
    }
}

// MARK: - Execution
extension OSUserExecutor {
    // We will pass minimal properties to this request
    func createUser(_ user: OSUserInternal) {
        let originalPushToken = user.pushSubscriptionModel.address
        let request = OSRequestCreateUser(identityModel: user.identityModel, propertiesModel: user.propertiesModel, pushSubscriptionModel: user.pushSubscriptionModel, originalPushToken: originalPushToken)

        appendToQueue(request)

        executePendingRequests()
    }

    /**
     This Create User call expects an external ID and the Identity Model to hydrate with the OneSignal ID
     */
    func createUser(aliasLabel: String, aliasId: String, identityModel: OSIdentityModel) {
        let request = OSRequestCreateUser(aliasLabel: aliasLabel, aliasId: aliasId, identityModel: identityModel)
        appendToQueue(request)
        executePendingRequests()
    }

    func executeCreateUserRequest(_ request: OSRequestCreateUser) {
        guard !request.sentToClient else {
            return
        }

        // Hook up push subscription model if exists, it may be updated with a subscription_id, etc.
        if let modelId = request.pushSubscriptionModel?.modelId,
           let pushSubscriptionModel = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModelStore.getModel(modelId: modelId) {
            request.pushSubscriptionModel = pushSubscriptionModel
            request.updatePushSubscriptionModel(pushSubscriptionModel)
        }

        guard request.prepareForExecution(newRecordsState: newRecordsState)
        else {
            executePendingRequests(withDelay: true)
            return
        }

        request.sentToClient = true

        OneSignalCoreImpl.sharedClient().execute(request) { response in
            self.removeFromQueue(request)

            // Create User's response won't send us the user's complete info if this user already exists
            if let response = response {
                let shouldAddNewRecords = request.pushSubscriptionModel != nil
                // Parse the response for any data we need to update
                self.parseFetchUserResponse(
                    response: response,
                    identityModel: request.identityModel,
                    originalPushToken: request.originalPushToken,
                    addNewRecords: shouldAddNewRecords
                )

                // If this user already exists and we logged into an external_id, fetch the user data
                // Fetch the user only if its the current user and non-anonymous
                if OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel),
                   let identity = request.parameters?["identity"] as? [String: String],
                   let onesignalId = request.identityModel.onesignalId,
                   identity[OS_EXTERNAL_ID] != nil {
                    self.fetchUser(onesignalId: onesignalId, identityModel: request.identityModel)
                } else {
                    self.executePendingRequests()
                }

                if let onesignalId = request.identityModel.onesignalId {
                    if let rywToken = response["ryw_token"] as? String
                    {
                        let rywDelay = response["ryw_delay"] as? NSNumber
                        OSConsistencyManager.shared.setRywTokenAndDelay(
                            id: onesignalId,
                            key: OSIamFetchOffsetKey.userCreate,
                            value: OSReadYourWriteData(rywToken: rywToken, rywDelay: rywDelay)
                        )
                    } else {
                        // handle a potential regression where ryw_token is no longer returned by API
                        OSConsistencyManager.shared.resolveConditionsWithID(id: OSIamFetchReadyCondition.CONDITIONID)
                    }
                }
            }
            OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = false
        } onFailure: { error in
            let responseType = OSNetworkingUtils.getResponseStatusType(error.code)
            if responseType == .unauthorized {
                    OneSignalUserManagerImpl.sharedInstance.invalidJwtConfigResponse(error: nsError)
                }
            if responseType != .retryable {
                // A failed create user request would leave the SDK in a bad state
                // Don't remove the request from cache and pause the operation repo
                // We will retry this request on a new session
                OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true
                request.sentToClient = false
            }
        }
    }

    func fetchIdentityBySubscription(_ user: OSUserInternal) {
        let request = OSRequestFetchIdentityBySubscription(identityModel: user.identityModel, pushSubscriptionModel: user.pushSubscriptionModel)

        appendToQueue(request)
        executePendingRequests()
    }

    /**
     For migrating legacy players from 3.x to 5.x. This request will fetch the identity object for a subscription ID, and we will use the returned onesignalId to fetch and hydrate the local user.
     */
    func executeFetchIdentityBySubscriptionRequest(_ request: OSRequestFetchIdentityBySubscription) {
        guard !request.sentToClient else {
            return
        }

        // newRecordsState is unused for this request
        guard request.prepareForExecution(newRecordsState: newRecordsState) else {
            executePendingRequests(withDelay: true)
            return
        }

        request.sentToClient = true

        OneSignalCoreImpl.sharedClient().execute(request) { response in
            self.removeFromQueue(request)

            if let identityObject = self.parseIdentityObjectResponse(response),
               let onesignalId = identityObject[OS_ONESIGNAL_ID] {
                request.identityModel.hydrate(identityObject)

                // Fetch this user's data if it is the current user
                guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel)
                else {
                    self.executePendingRequests()
                    return
                }

                self.fetchUser(onesignalId: onesignalId, identityModel: request.identityModel)
            }
        } onFailure: { error in
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserExecutor executeFetchIdentityBySubscriptionRequest failed with error: \(error.debugDescription)")
            let responseType = OSNetworkingUtils.getResponseStatusType(error.code)
            if responseType != .retryable {
                // Fail, no retry, remove the subscription_id but keep the same push subscription model
                OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = nil
                self.removeFromQueue(request)
            }
            self.executePendingRequests()
        }
    }

    func identifyUser(externalId: String, identityModelToIdentify: OSIdentityModel, identityModelToUpdate: OSIdentityModel) {
        let request = OSRequestIdentifyUser(
            aliasLabel: OS_EXTERNAL_ID,
            aliasId: externalId,
            identityModelToIdentify: identityModelToIdentify,
            identityModelToUpdate: identityModelToUpdate
        )

        appendToQueue(request)

        executePendingRequests()
    }

    func executeIdentifyUserRequest(_ request: OSRequestIdentifyUser) {
        guard !request.sentToClient else {
            return
        }

        guard request.prepareForExecution(newRecordsState: newRecordsState) else {
            executePendingRequests(withDelay: true)
            return
        }

        request.sentToClient = true

        OneSignalCoreImpl.sharedClient().execute(request) { _ in
            self.removeFromQueue(request)

            guard let onesignalId = request.identityModelToIdentify.onesignalId else {
                OneSignalLog.onesignalLog(.LL_ERROR, message: "executeIdentifyUserRequest succeeded but is now missing OneSignal ID!")
                self.executePendingRequests()
                return
            }

            // Need to hydrate the identity model for current user or past user with pending requests
            let aliases = [
                OS_ONESIGNAL_ID: onesignalId,
                request.aliasLabel: request.aliasId
            ]
            request.identityModelToUpdate.hydrate(aliases)

            // the anonymous user has been identified, still need to Fetch User as we cleared local data
            if OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModelToUpdate) {
                // Add onesignal ID to new records because an immediate fetch may not return the newly-applied external ID
                self.newRecordsState.add(onesignalId, true)
                self.fetchUser(onesignalId: onesignalId, identityModel: request.identityModelToUpdate)
            } else {
                self.executePendingRequests()
            }
        } onFailure: { error in
            let responseType = OSNetworkingUtils.getResponseStatusType(error.code)
            if responseType == .conflict {
                // Returns 409 if any provided (label, id) pair exists on another User, so the SDK will switch to this user.
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "executeIdentifyUserRequest returned error code user-2. Now handling user-2 error response... switch to this user.")

                self.removeFromQueue(request)

                if let userInstance = OneSignalUserManagerImpl.sharedInstance._user,
                    OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModelToUpdate) {
                    // Generate a Create User request, if it's still the current user
                    self.createUser(userInstance)
                } else {
                    // This will hydrate the OneSignal ID for any pending requests
                    self.createUser(aliasLabel: request.aliasLabel, aliasId: request.aliasId, identityModel: request.identityModelToUpdate)
                }
            } else if responseType == .invalid || responseType == .unauthorized {
                // Failed, no retry
                self.removeFromQueue(request)
                self.executePendingRequests()
            } else if responseType == .missing {
                self.removeFromQueue(request)
                self.executePendingRequests()
                // Logout if the user in the SDK is the same
                guard OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModelToUpdate)
                else {
                    return
                }
                // The subscription has been deleted along with the user, so remove the subscription_id but keep the same push subscription model
                OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId = nil
                OneSignalUserManagerImpl.sharedInstance._logout()
            }
        }
    }

    func fetchUser(onesignalId: String, identityModel: OSIdentityModel, onNewSession: Bool = false) {
        let request = OSRequestFetchUser(identityModel: identityModel, onesignalId: onesignalId, onNewSession: onNewSession)

        appendToQueue(request)

        // User fetch will always be called after a delay unless it is to refresh the user state on a new session
        executePendingRequests(withDelay: !onNewSession)
    }

    func executeFetchUserRequest(_ request: OSRequestFetchUser) {
        guard !request.sentToClient else {
            return
        }

        guard request.prepareForExecution(newRecordsState: newRecordsState) else {
            executePendingRequests(withDelay: true)
            return
        }

        request.sentToClient = true

        OneSignalCoreImpl.sharedClient().execute(request) { response in
            self.removeFromQueue(request)

            if let response = response {
                // Clear local data in preparation for hydration
                // TODO: JWT 🔐 the following line feels wrong... maybe the user's changed by now
                OneSignalUserManagerImpl.sharedInstance.clearUserData()
                self.parseFetchUserResponse(response: response, identityModel: request.identityModel, originalPushToken: OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.token)

                // If this is a on-new-session's fetch user call, check that the subscription still exists
                if request.onNewSession,
                   OneSignalUserManagerImpl.sharedInstance.isCurrentUser(request.identityModel),
                   let subId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId,
                   let subscriptionObjects = self.parseSubscriptionObjectResponse(response) {
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
            self.executePendingRequests()
        } onFailure: { error in
            let responseType = OSNetworkingUtils.getResponseStatusType(error.code)
            if responseType == .missing {
                self.removeFromQueue(request)
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
                self.removeFromQueue(request)
            }
            self.executePendingRequests()
        }
    }
}

// MARK: - Parsing
extension OSUserExecutor {
    /**
     Used to parse Create User and Fetch User responses. The `originalPushToken` is the push token when the request was created, which may be different from the push token currently in the SDK. For example, when the request was created, there may be no push token yet, but soon after, the SDK receives a push token. This is used to determine whether or not to hydrate the push subscription.
     */
    func parseFetchUserResponse(response: [AnyHashable: Any], identityModel: OSIdentityModel, originalPushToken: String?, addNewRecords: Bool = false) {

        // If this was a create user, it hydrates the onesignal_id of the request's identityModel
        // The model in the store may be different, and it may be waiting on the onesignal_id of this previous model
        if let identityObject = parseIdentityObjectResponse(response) {
            identityModel.hydrate(identityObject)
            if addNewRecords, let onesignalId = identityObject[OS_ONESIGNAL_ID] {
                newRecordsState.add(onesignalId)
            }
        }

        // TODO: Determine how to hydrate the push subscription, which is still faulty.
        // Hydrate by token if sub_id exists?
        // Problem: a user can have multiple iOS push subscription, and perhaps missing token
        // Ideally we only get push subscription for this device in the response, not others

        // Hydrate the push subscription if we don't already have a subscription ID AND token matches the original request
        if OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId == nil,
           let subscriptionObject = parseSubscriptionObjectResponse(response)
        {
            for subModel in subscriptionObject {
                if subModel["type"] as? String == "iOSPush",
                   // response may have "" token or no token
                   areTokensEqual(tokenA: originalPushToken, tokenB: subModel["token"] as? String)
                {
                    OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.hydrate(subModel)
                    if let subId = subModel["id"] as? String {
                        OSNotificationsManager.setPushSubscriptionId(subId)
                        if addNewRecords {
                            newRecordsState.add(subId)
                        }
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

        if let propertiesObject = parsePropertiesObjectResponse(response) {
            OneSignalUserManagerImpl.sharedInstance._user?.propertiesModel.hydrate(propertiesObject)
        }

        // Now parse email and sms subscriptions
        if let subscriptionObject = parseSubscriptionObjectResponse(response) {
            let models = OneSignalUserManagerImpl.sharedInstance.subscriptionModelStore.getModels()
            for subModel in subscriptionObject {
                if let address = subModel["token"] as? String,
                   let rawType = subModel["type"] as? String,
                   rawType != "iOSPush",
                   let type = OSSubscriptionType(rawValue: rawType)
                {
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
    func areTokensEqual(tokenA: String?, tokenB: String?) -> Bool {
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

    func parseSubscriptionObjectResponse(_ response: [AnyHashable: Any]?) -> [[String: Any]]? {
        return response?["subscriptions"] as? [[String: Any]]
    }

    func parsePropertiesObjectResponse(_ response: [AnyHashable: Any]?) -> [String: Any]? {
        return response?["properties"] as? [String: Any]
    }

    func parseIdentityObjectResponse(_ response: [AnyHashable: Any]?) -> [String: String]? {
        return response?["identity"] as? [String: String]
    }
}

extension OSUserExecutor: OSUserJwtConfigListener {
    func onRequiresUserAuthChanged(from: OSRequiresUserAuth, to: OSRequiresUserAuth) {
        print("❌ OSUserExecutor onUserAuthChanged from \(String(describing: from)) to \(String(describing: to))")
        // If auth changed from false or unknown to true, process requests
        if to == .on {
            removeInvalidRequests()
        }
        self.executePendingRequests()
    }

    func onJwtUpdated(externalId: String, token: String?) {
        /*
         Handle pending 401 requests again
         */
        print("❌ OSUserExecutor onJwtUpdated for \(externalId) to \(String(describing: token))")
    }

    private func removeInvalidRequests() {
        self.dispatchQueue.async {
            print("❌ OSUserExecutor.removeInvalidRequests called")

            for request in self.userRequestQueue {
                guard self.isRequestValidWithAuth(request) else {
                    print(" \(request) is Invalid, being removed")
                    self.userRequestQueue.removeAll(where: { $0 == request})
                    continue
                }

                if request.isKind(of: OSRequestIdentifyUser.self), let req = request as? OSRequestIdentifyUser {
                    print(" \(request) is IdentifyUser, being converted")
                    self.userRequestQueue.removeAll(where: { $0 == request})
                    self.convertIdentifyUserToCreateUser(req)
                }
            }

            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, withValue: self.userRequestQueue)
            print(" OSUserExecutor.removeInvalidRequests done, \(self.userRequestQueue)")
        }
    }

    /// Returns if the Request is valid when Identity Verification is on
    private func isRequestValidWithAuth(_ request: OSUserRequest) -> Bool {
        if request.isKind(of: OSRequestFetchIdentityBySubscription.self) {
            return false
        }
        if request.isKind(of: OSRequestCreateUser.self),
           let createUserRequest = request as? OSRequestCreateUser,
           createUserRequest.identityModel.externalId == nil
        {
            return false
        }
        if request.isKind(of: OSRequestFetchUser.self),
           let fetchUserRequest = request as? OSRequestFetchUser,
           fetchUserRequest.identityModel.externalId == nil {
            return false
        }
        return true
    }
}

extension OSUserExecutor: OSLoggable {
    func logSelf() {
        print(
            """
            💛 OSUserExecutor has the following queues:
                userRequestQueue: \(self.userRequestQueue)
            """
        )
    }
}
