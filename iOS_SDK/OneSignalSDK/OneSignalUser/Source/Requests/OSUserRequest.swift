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

protocol OSUserRequest: OneSignalRequest, NSCoding {
    var sentToClient: Bool { get set }
    func prepareForExecution(requiresJwt: Bool?) -> Bool
}

internal extension OneSignalRequest {

    /**
     Returns the alias pair to use to send this request for. Defaults to Onesignal Id, unless Identity Verification is on.
     */
    func getAlias(authRequired: Bool?, identityModel: OSIdentityModel) -> (label: String, id: String?) {
        var label = OS_ONESIGNAL_ID
        var id = identityModel.onesignalId
        if authRequired == true {
            label = OS_EXTERNAL_ID
            id = identityModel.externalId
        }
        return (label, id)
    }

    /**
     Adds JWT token to header if valid, regardless of requirement.
     Returns false if JWT requirement is unknown, or turned on but the token is missing or invalid.
     
     |                    |  unknown  |   on    |   off   |
     | --------------- | -------------- | ------- | ------- |
     |   hasToken  |                  |   ✔️    |   ✔️   |
     |   noToken    |                  |           |   ✔️   |
     | --------------- | -------------- | ------- | ------- |
     */
    func addJWTHeaderIsValid(required: Bool?, identityModel: OSIdentityModel) -> Bool {
        let tokenIsValid = identityModel.isJwtValid()
        let canBeSent = required == false || (required == true && tokenIsValid)
        if canBeSent, tokenIsValid {
            // Add the JWT token if it is valid, regardless of requirements
            var additionalHeaders = self.additionalHeaders ?? [String: String]()
            additionalHeaders["Authorization"] = "Bearer \(identityModel.jwtBearerToken ?? "")"
            self.additionalHeaders = additionalHeaders
        }
        return canBeSent
    }

    /** Returns if the `OneSignal-Subscription-Id` header was added successfully. */
    func addPushSubscriptionIdToAdditionalHeaders() -> Bool {
        addPushToken()
        if let pushSubscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId {
            var additionalHeaders = self.additionalHeaders ?? [String: String]()
            additionalHeaders["OneSignal-Subscription-Id"] = pushSubscriptionId
            self.additionalHeaders = additionalHeaders
            return true
        } else {
            return false
        }
    }

    func addPushToken() -> Bool {
        if let token = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.address {
            var additionalHeaders = self.additionalHeaders ?? [String: String]()
            additionalHeaders["Device-Auth-Push-Token"] = "Basic \(token)"
            return true
        } else {
            return false
        }

    }
}
