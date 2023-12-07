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
