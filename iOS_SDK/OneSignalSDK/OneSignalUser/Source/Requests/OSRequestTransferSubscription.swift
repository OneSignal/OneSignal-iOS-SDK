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
