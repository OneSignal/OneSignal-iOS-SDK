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
