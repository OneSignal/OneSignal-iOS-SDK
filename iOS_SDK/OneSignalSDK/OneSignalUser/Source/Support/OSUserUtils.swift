/*
 Modified MIT License

 Copyright 2024 OneSignal

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

class OSUserUtils {
    /**
     Returns the alias pair to use to send a request for.
     When Identity Verification is unknown, or IDs are missing, this will be null.
     When Identity Verification is disabled, this should be the onesignal ID.
     When Identity Verification is enabled, this should be the external ID.
     */
    static func getAlias(identityModel: OSIdentityModel, jwtConfig: OSUserJwtConfig) -> OSAliasPair? {
        guard let jwtRequired = jwtConfig.isRequired else {
            return nil
        }

        if jwtRequired, let externalId = identityModel.externalId
        {
            // JWT is on and external ID exists
            return OSAliasPair(OS_EXTERNAL_ID, externalId)
        } else if !jwtRequired, let onesignalId = identityModel.onesignalId {
            // JWT is off and onesignal ID exists
            return OSAliasPair(OS_ONESIGNAL_ID, onesignalId)
        }

        // Missing onesignal ID or external ID, when expected
        return nil
    }

    /**
     The `OneSignal-Subscription-Id` header supports improved `last_active` tracking for subscriptions that were actually active.
     The `Device-Auth-Push-Token` header includes the push token if available.
     */
    static func getFullPushHeader() -> [String: String] {
        var headers = [String: String]()

        if let pushSubscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId {
            headers["OneSignal-Subscription-Id"] = pushSubscriptionId
        }
        if let token = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.address {
            headers["Device-Auth-Push-Token"] = "Basic \(token)"
        }
        return headers
    }
}
