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
    /// The user this update was made for; used to file the response's RYW token under their
    /// `onesignal_id`. `nil` drops the token. Held as the model because that ID may not exist
    /// yet when the request is built.
    var identityModel: OSIdentityModel?

    /**
     Always nil, so this Request is never signed. Its path names a subscription rather than a user and the
     endpoint ignores the token, while owning it would stall the device's push token and notification types
     behind an identified user whose token went invalid.

     The Delta it comes from is owned, which is what decides whether the update survives the anonymous purge.
     */
    var ownerExternalId: String? { return nil }

    /// The one Request Identity Verification lets through unowned, for the reason `ownerExternalId` gives.
    var sendsUnsigned: Bool { return true }

    // Need the subscription_id
    func prepareForExecution(newRecordsState: OSNewRecordsState, auth: OSRequestAuthorizing) -> Bool {
        if let subscriptionId = subscriptionModel.subscriptionId,
           newRecordsState.canAccess(subscriptionId),
           let appId = OneSignalIdentifiers.currentAppId,
           auth.authorize(self)
        {
            self.path = "apps/\(appId)/subscriptions/\(subscriptionId)"
            // Refresh so a stale snapshot queued earlier can't overwrite newer local state.
            refreshParametersFromLiveModel()
            return true
        } else {
            return false
        }
    }

    /// Rebuild the PATCH body from the current subscription model.
    func refreshParametersFromLiveModel() {
        var subscriptionParams: [String: Any] = [:]
        subscriptionParams["token"] = subscriptionModel.address
        subscriptionParams["device_os"] = subscriptionModel.deviceOs
        subscriptionParams["sdk"] = subscriptionModel.sdk
        subscriptionParams["app_version"] = subscriptionModel.appVersion

        let enablement = subscriptionModel.reportedEnablement()
        subscriptionParams["enabled"] = enablement.enabled
        if let notificationTypes = enablement.notificationTypes {
            subscriptionParams["notification_types"] = notificationTypes
        }
        self.parameters = ["subscription": subscriptionParams]
    }

    init(subscriptionModel: OSSubscriptionModel, identityModel: OSIdentityModel?) {
        self.subscriptionModel = subscriptionModel
        self.identityModel = identityModel
        self.stringDescription = "OSRequestUpdateSubscription with model: \(subscriptionModel.modelId)"
        super.init()
        refreshParametersFromLiveModel()
        self.method = PATCH
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
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.subscriptionModel = subscriptionModel
        self.identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel
        self.stringDescription = "OSRequestUpdateSubscription with parameters: \(parameters)"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
    }
}
