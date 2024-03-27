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
import OneSignalUser

class OSRequestRemoveUpdateToken: OneSignalRequest, OSLiveActivityRequest, OSLiveActivityUpdateTokenRequest {
    override var description: String { return "(OSRequestRemoveUpdateToken) key:\(key) requestSuccessful:\(requestSuccessful)" }

    var key: String
    var requestSuccessful: Bool
    var shouldForgetWhenSuccessful: Bool = true

    func prepareForExecution() -> Bool {
        guard let appId = OneSignalConfigManager.getAppId() else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the reemove update token request due to null app ID.")
            return false
        }

        guard let subscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the remove update token request due to null subscription ID.")
            return false
        }

        guard let activityId = self.key.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlUserAllowed) else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot translate activity type to url encoded string.")
            return false
        }
        
        // self.path = "apps/\(appId)/activities/tokens/update/\(activityId)/subscriptions/\(subscriptionId)"
        self.path = "apps/\(appId)/live_activities/\(activityId)/token/\(subscriptionId)"
        self.method = DELETE

        return true
    }

    func supersedes(_ existing: OSLiveActivityRequest) -> Bool {
        // Note that NSDate has nanosecond precision. It's possible for two requests to come in at the same time. If
        // that does happen, we assume the current one supersedes the existing one.
        return self.timestamp >= existing.timestamp
    }

    init(key: String) {
        self.key = key
        self.requestSuccessful = false
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(key, forKey: "key")
        coder.encode(timestamp, forKey: "timestamp")
        coder.encode(requestSuccessful, forKey: "requestSuccessful")
    }

    required init?(coder: NSCoder) {
        guard
            let key = coder.decodeObject(forKey: "key") as? String,
            let requestSuccessful = coder.decodeObject(forKey: "requestSuccessful") as? Bool,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.key = key
        self.requestSuccessful = requestSuccessful
        super.init()
        self.timestamp = timestamp
    }
}
