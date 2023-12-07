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
