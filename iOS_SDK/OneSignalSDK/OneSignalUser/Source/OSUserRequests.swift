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
 */
class OSUserExecutor {
    static var requestQueue: [OSUserRequest] = []

    static func start() {
        // Read unfinished requests from cache, if any...
        if let requestQueue = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: OS_USER_EXECUTOR_REQUEST_QUEUE_KEY, defaultValue: []) as? [OSUserRequest] {
            self.requestQueue = requestQueue
        } else {
            // log error
        }
    }

    static func executePendingRequests() {
        for request in requestQueue {
            // Return as soon as we reach an un-executable request
            if !request.prepareForExecution() {
                return
            }
            // This request is Identify User
            if request.isKind(of: OSRequestIdentifyUser.self), let identifyUserRequest = request as? OSRequestIdentifyUser {
                executeIdentifyUserRequest(identifyUserRequest)
            } else {
                // Log Error
            }
            // Remove the request from queue and cache
            requestQueue.removeAll(where: { $0 == request})
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
        }
    }
    
    static func parseFetchUserResponse(response: [AnyHashable:Any], identityModel: OSIdentityModel) {
        // On success, check if the current user is the same as the one in the request
        // If user has changed, don't hydrate, except for push subscription
        let modelInStore = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(key: OS_IDENTITY_MODEL_KEY)
        // Always hydrate the subscription id since it is transferred between users
        if let subscriptionObject = parseSubscriptionObjectResponse(response) {
            for subModel in subscriptionObject {
                if let subType = subModel["type"] as? String {
                    if subType == "iOSPush" {
                        OneSignalUserManagerImpl.sharedInstance.user.pushSubscriptionModel.hydrate(subModel)
                        if let subId = subModel["id"] as? String {
                            OSNotificationsManager.setPushSubscriptionId(subId)
                        }
                    }
                }
            }
        }
        guard modelInStore?.modelId == identityModel.modelId else {
            return
        }
        if let identityObject = parseIdentityObjectResponse(response) {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.hydrate(identityObject)
        }
        
        if let propertiesObject = parsePropertiesObjectResponse(response) {
            OneSignalUserManagerImpl.sharedInstance.user.propertiesModel.hydrate(propertiesObject)
        }
    }
    
    static func parseSubscriptionObjectResponse(_ response: [AnyHashable:Any]?) -> [[String:Any]]? {
        return response?["subscriptions"] as? [[String:Any]]
    }
    
    static func parsePropertiesObjectResponse(_ response: [AnyHashable:Any]?) -> [String:Any]? {
        return response?["properties"] as? [String:Any]
    }
    
    static func parseIdentityObjectResponse(_ response: [AnyHashable:Any]?) -> [String:Any]? {
        return response?["identity"] as? [String:Any]
    }

    // We will pass minimal properties to this request
    static func createUser(_ user: OSUserInternal) {
        let request = OSRequestCreateUser(identityModel: user.identityModel, pushSubscriptionModel: user.pushSubscriptionModel)

        // Currently there are no requirements needed before sending this request
        guard request.prepareForExecution() else {
            return
        }
        OneSignalClient.shared().execute(request) { response in
            if let response = response {
                parseFetchUserResponse(response: response, identityModel: request.identityModel)
            }
            executePendingRequests()
        } onFailure: { error in
            print("ECM test + \(error.debugDescription)")
            // Depending on error, Client is responsible for retrying.
            // executePendingRequests() ?
        }
    }

    static func identifyUser(externalId: String, identityModelToIdentify: OSIdentityModel, identityModelToUpdate: OSIdentityModel) {
        let request = OSRequestIdentifyUser(
            aliasLabel: OS_EXTERNAL_ID,
            aliasId: externalId,
            identityModelToIdentify: identityModelToIdentify,
            identityModelToUpdate: identityModelToUpdate
        )

        guard request.prepareForExecution() else {
            // Missing onesignal_id
            // This request still stays in the queue and cache
            requestQueue.append(request)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
            return
        }

        executeIdentifyUserRequest(request)
    }

    static func executeIdentifyUserRequest(_ request: OSRequestIdentifyUser) {
        OneSignalClient.shared().execute(request) { _ in
            // the anonymous user has been identified, still need to Fetch User + Transfer Push Sub
            fetchUser(aliasLabel: OS_EXTERNAL_ID, aliasId: request.aliasId, identityModel: request.identityModelToUpdate)
            // TODO: Don't need to transfer push sub, confirm.
            transferPushSubscriptionTo(aliasLabel: request.aliasLabel, aliasId: request.aliasId, retainPreviousUser: true) // update logic to determine flag
            executePendingRequests() // TODO: Here or after fetch or after transfer?

        } onFailure: { _ in
            // Returns 409 if any provided (label, id) pair exists on another User, so the SDK will switch to this user.
            // If 409:
            fetchUser(aliasLabel: OS_EXTERNAL_ID, aliasId: request.aliasId, identityModel: request.identityModelToUpdate)
            // TODO: Link ^ to the new user
            transferPushSubscriptionTo(aliasLabel: request.aliasLabel, aliasId: request.aliasId, retainPreviousUser: true) // update logic to determine flag
            executePendingRequests() // Here or after fetch or after transfer?

            // If not 409, we retry, depending on what the error is?
        }
    }

    static func transferPushSubscriptionTo(aliasLabel: String, aliasId: String, retainPreviousUser: Bool?) {
        // TODO: Where to get pushSubscriptionModel for this request
        let request = OSRequestTransferSubscription(
            subscriptionModel: OneSignalUserManagerImpl.sharedInstance.user.pushSubscriptionModel,
            aliasLabel: aliasLabel,
            aliasId: aliasId,
            identityModel: nil,
            retainPreviousUser: retainPreviousUser // Need to update logic to determine this, for now, default to true
        )

        guard request.prepareForExecution() else {
            // Missing subscriptionId. This request still stays in the queue and cache
            requestQueue.append(request)
            OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_REQUEST_QUEUE_KEY, withValue: self.requestQueue)
            return
        }

        executeTransferPushSubscriptionRequest(request)
    }

    static func executeTransferPushSubscriptionRequest(_ request: OSRequestTransferSubscription) {
        OneSignalClient.shared().execute(request) { _ in
            // ... hydrate with returned identity object?
            executePendingRequests()

        } onFailure: { _ in
            // What happened? Client responsible for retrying.
        }
    }

    static func fetchUser(aliasLabel: String, aliasId: String, identityModel: OSIdentityModel) {
        let request = OSRequestFetchUser(identityModel: identityModel, aliasLabel: aliasLabel, aliasId: aliasId)

        guard request.prepareForExecution() else {
            // This should not happen as we set the alias to use for the request path, log error
            return
        }

        OneSignalClient.shared().execute(request) { response in
            if let response = response {
                parseFetchUserResponse(response: response, identityModel: request.identityModel)
            }
        } onFailure: { _ in
            // What?
        }
    }
}

// MARK: - User Request Classes

protocol OSUserRequest: OneSignalRequest, NSCoding {
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
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let identityModel: OSIdentityModel
    let pushSubscriptionModel: OSSubscriptionModel

    func prepareForExecution() -> Bool {
        guard let appId = OneSignalConfigManager.getAppId() else {
            return false
        }
        self.addJWTHeader(identityModel:identityModel)
        self.path = "apps/\(appId)/users"
        // The pushSub doesn't need to have a token.
        return true
    }

    init(identityModel: OSIdentityModel, pushSubscriptionModel: OSSubscriptionModel) {
        self.identityModel = identityModel
        self.pushSubscriptionModel = pushSubscriptionModel
        self.stringDescription = "OSRequestCreateUser"

        super.init()

        var pushSubscriptionObject: [String: Any] = [:]
        pushSubscriptionObject["id"] = pushSubscriptionModel.subscriptionId
        pushSubscriptionObject["type"] = pushSubscriptionModel.type.rawValue
        pushSubscriptionObject["token"] = "test"//pushSubscriptionModel.address
        // ... and more ? ...

        var params: [String: Any] = [:]
        if let externalId = identityModel.externalId {
            params["identity"] = [OS_EXTERNAL_ID: externalId]
        }
        params["subscriptions"] = [pushSubscriptionObject]
        params["properties"] = nil

        self.parameters = params
        self.method = POST
        
    }

    func encode(with coder: NSCoder) {
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(pushSubscriptionModel, forKey: "pushSubscriptionModel")
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
        self.stringDescription = "OSRequestCreateUser"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.path = path
        self.timestamp = timestamp
    }
}

/**
 The `identityModelToIdentify` is used for the `onesignal_id` of the user we want to associate with this alias.
 This request will tell us if we should continue with the previous user who is now identitfied, or to change users to the one this alias already exists on.
 
 Note: The SDK needs an user to operate on before this request returns. However, at the time of this request's creation, the SDK does not know if there is already
 an user associated with this alias. So, it creates a blank new user (whose identity model is passed in as `identityModelToUpdate`,
 which is the model used to make a subsequent ``OSRequestFetchUser``).
 */
class OSRequestIdentifyUser: OneSignalRequest, OSUserRequest {
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let identityModelToIdentify: OSIdentityModel
    let identityModelToUpdate: OSIdentityModel
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
        self.method = POST
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
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let identityModel: OSIdentityModel
    let aliasLabel: String?
    let aliasId: String?

    func prepareForExecution() -> Bool {
        // If there is an alias, use that
        if let aliasLabelToUse = aliasLabel,
           let appId = OneSignalConfigManager.getAppId(),
           let aliasIdToUse = aliasId {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(aliasLabelToUse)/\(aliasIdToUse)"
            return true
        }
        // Otherwise, use the onesignal_id
        if let onesignalId = identityModel.onesignalId, let appId = OneSignalConfigManager.getAppId() {
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(identityModel: OSIdentityModel, aliasLabel: String?, aliasId: String?) {
        self.identityModel = identityModel
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.stringDescription = "OSRequestFetchUser with aliasLabel: \(aliasLabel) aliasId: \(aliasId)"
        super.init()
        self.method = GET
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(aliasLabel, forKey: "aliasLabel")
        coder.encode(aliasId, forKey: "aliasId")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.aliasLabel = coder.decodeObject(forKey: "aliasLabel") as? String
        self.aliasId = coder.decodeObject(forKey: "aliasId") as? String
        self.stringDescription = "OSRequestFetchUser with aliasLabel: \(aliasLabel) aliasId: \(aliasId)"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

class OSRequestAddAliases: OneSignalRequest, OSUserRequest {
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let identityModel: OSIdentityModel

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
        self.stringDescription = "OSRequestAddAliases with aliases: \(aliases)"
        super.init()
        self.parameters = ["identity": aliases]
        self.method = POST
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: [String: String]],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.stringDescription = "OSRequestAddAliases with parameters: \(parameters)"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

class OSRequestRemoveAlias: OneSignalRequest, OSUserRequest {
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let labelToRemove: String
    let identityModel: OSIdentityModel

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
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let modelToUpdate: OSPropertiesModel
    let identityModel: OSIdentityModel

    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId, let appId = OneSignalConfigManager.getAppId() {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(properties: [String: Any], deltas: [String: Any]?, refreshDeviceMetadata: Bool?, modelToUpdate: OSPropertiesModel, identityModel: OSIdentityModel) {
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        self.stringDescription = "OSRequestUpdateProperties with properties: \(properties) deltas: \(deltas) refreshDeviceMetadata: \(refreshDeviceMetadata)"
        super.init()

        var params: [String: Any] = [:]
        params["properties"] = properties
        params["deltas"] = deltas
        params["refresh_device_metadata"] = refreshDeviceMetadata

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
 Current uses of this request are for adding Email and SMS subscriptions. Push subscriptions won't be created using
 this request because they will be created with ``OSRequestCreateUser``.
 */
class OSRequestCreateSubscription: OneSignalRequest, OSUserRequest {
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let subscriptionModel: OSSubscriptionModel
    let identityModel: OSIdentityModel

    // Need the onesignal_id of the user
    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId, let appId = OneSignalConfigManager.getAppId() {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/subscription"
            return true
        } else {
            self.path = "" // self.path is non-nil, so set to empty string
            return false
        }
    }

    init(subscriptionModel: OSSubscriptionModel, identityModel: OSIdentityModel) {
        self.subscriptionModel = subscriptionModel
        self.identityModel = identityModel
        self.stringDescription = "OSRequestCreateSubscription with subscriptionModel: \(subscriptionModel.address)"
        super.init()

        var subscriptionParams: [String: Any] = [:]
        subscriptionParams["type"] = subscriptionModel.type.rawValue
        subscriptionParams["token"] = subscriptionModel.address
        subscriptionParams["enabled"] = subscriptionModel.enabled

        // TODO: Add more to `subscriptionParams`?

        self.parameters = ["subscription": subscriptionParams]
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
        self.stringDescription = "OSRequestCreateSubscription with subscriptionModel: \(subscriptionModel.address)"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

/**
 Transfers the Subscription specified by the subscriptionId to the User identified by the identity in the payload.
 Only one entry is allowed, `onesignal_id` or an Alias. We will not use the identityModel at all if there is an alias specified.
 The anticipated usage of this request is only for push subscriptions.
 */
class OSRequestTransferSubscription: OneSignalRequest, OSUserRequest {
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let subscriptionModel: OSSubscriptionModel
    let identityModel: OSIdentityModel?
    let aliasLabel: String?
    let aliasId: String?

    // Need an alias and subscription_id
    func prepareForExecution() -> Bool {
        if let subscriptionId = subscriptionModel.subscriptionId, let appId = OneSignalConfigManager.getAppId() {
            self.path = "apps/\(appId)/subscriptions/\(subscriptionId)/owner"
            // Check alias pair
            if let label = aliasLabel,
               let id = aliasId {
                // parameters should be set in init(), so not optional
                self.parameters?["identity"] = [label: id]
                return true
            }
            if let identityModel = identityModel, let onesignalId = identityModel.onesignalId {
                self.parameters?["identity"] = [OS_ONESIGNAL_ID: onesignalId]
                self.addJWTHeader(identityModel: identityModel)
                return true
            } else {
                return false
            }
        } else {
            self.path = "" // self.path is non-nil, so set to empty string
            return false
        }
    }

    /**
     Must pass either an `identityModel` or an Alias pair to identify the User.
     If `retainPreviousUser` flag is not passed in, it defaults to `true`.
     */
    init(
        subscriptionModel: OSSubscriptionModel,
        aliasLabel: String?,
        aliasId: String?,
        identityModel: OSIdentityModel?,
        retainPreviousUser: Bool?
    ) {
        self.subscriptionModel = subscriptionModel
        self.identityModel = identityModel
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.stringDescription = "OSRequestTransferSubscription"
        super.init()
        self.parameters = [OS_RETAIN_PREVIOUS_USER: retainPreviousUser ?? true]
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(subscriptionModel, forKey: "subscriptionModel")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(aliasLabel, forKey: "aliasLabel")
        coder.encode(aliasId, forKey: "aliasId")
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
        self.identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel
        self.aliasLabel = coder.decodeObject(forKey: "aliasLabel") as? String
        self.aliasId = coder.decodeObject(forKey: "aliasId") as? String
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
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let subscriptionModel: OSSubscriptionModel

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
    init(subscriptionObject: [String: Any], subscriptionModel: OSSubscriptionModel) {
        self.subscriptionModel = subscriptionModel
        self.stringDescription = "OSRequestUpdateSubscription with subscriptionObject: \(subscriptionObject)"
        super.init()

        // Rename "address" key as "token", if it exists
        var subscriptionParams = subscriptionObject
        subscriptionParams.removeValue(forKey: "address")
        subscriptionParams.removeValue(forKey: "notificationTypes")
        subscriptionParams["token"] = subscriptionObject["address"]
        subscriptionParams["notification_types"] = subscriptionObject["notificationTypes"]

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
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let subscriptionModel: OSSubscriptionModel

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
        self.stringDescription = "OSRequestDeleteSubscription with subscriptionModel: \(subscriptionModel.address)"
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
        self.stringDescription = "OSRequestDeleteSubscription with subscriptionModel: \(subscriptionModel.address)"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}

internal extension OneSignalRequest {
    func addJWTHeader(identityModel: OSIdentityModel) {
        guard let token = identityModel.jwtBearerToken else {
            return
        }
        var additionalHeaders = self.additionalHeaders ?? [String:String]()
        additionalHeaders["Authorization"] = "Bearer \(token)"
        self.additionalHeaders = additionalHeaders
    }
}
