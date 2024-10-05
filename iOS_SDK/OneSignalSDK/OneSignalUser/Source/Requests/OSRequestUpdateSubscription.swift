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
import OneSignalOSCore

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
    func prepareForExecution(newRecordsState: OSNewRecordsState) -> Bool {
        addPushSubscriptionToAdditionalHeaders()
        if let subscriptionId = subscriptionModel.subscriptionId,
           newRecordsState.canAccess(subscriptionId),
           let appId = OneSignalConfigManager.getAppId()
        {
            self.path = "apps/\(appId)/subscriptions/\(subscriptionId)"
            return true
        } else {
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
        subscriptionParams.removeValue(forKey: OSSubscriptionModel.Constants.isDisabledInternallyKey)
        subscriptionParams["token"] = subscriptionModel.address
        subscriptionParams["device_os"] = subscriptionModel.deviceOs
        subscriptionParams["sdk"] = subscriptionModel.sdk
        subscriptionParams["app_version"] = subscriptionModel.appVersion

        if subscriptionModel._isDisabledInternally {
            subscriptionParams["enabled"] = false
            subscriptionParams["notification_types"] = -2
        } else {
            // notificationTypes defaults to -1 instead of nil, don't send if it's -1
            if subscriptionModel.notificationTypes != -1 {
                subscriptionParams["notification_types"] = subscriptionModel.notificationTypes
            }
            subscriptionParams["enabled"] = subscriptionModel.enabled
        }

        // TODO: The above is not quite right. If we hydrate, we will over-write any pending updates
        // May use subscriptionObject, but enabled and notification_types should be sent together...

        self.parameters = ["subscription": subscriptionParams]
        self.method = PATCH
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
    }
}
