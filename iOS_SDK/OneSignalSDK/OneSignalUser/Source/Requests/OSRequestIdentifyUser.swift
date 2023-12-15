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
