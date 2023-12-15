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
