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

class OSRequestSetUpdateToken: OneSignalRequest, OSLiveActivityRequest, OSLiveActivityUpdateTokenRequest {
    override var description: String { return "(OSRequestSetUpdateToken) activityId:\(activityId) requestSuccessful:\(requestSuccessful) token:\(token)" }
    
    var requestSuccessful: Bool
    var activityId: String
    var token: String
    
    var isRemoveRequest: Bool {
        return false
    }
    
    func prepareForExecution() -> Bool {
        guard let appId = OneSignalConfigManager.getAppId() else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the set update token request due to null app ID.")
            return false
        }
        
        guard let subscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the set update token request due to null subscription ID.")
            return false
        }
        
        let safeActivityId = NSString.addingPercentEncoding(self.activityId as NSString)
        self.path = "apps/\(appId)/live_activities/\(String(describing: safeActivityId))/token"
        self.parameters = ["subscription_id": subscriptionId, "push_token": self.token, "device_type": 0]
        self.method = POST
        
        return true
    }
    
    func supersedes(_ existing: OSLiveActivityRequest) -> Bool {
        if let existingSetRequest = existing as? OSRequestSetUpdateToken {
            return self.token != existingSetRequest.token
        }

        return true
    }
    
    init(activityId: String, token: String) {
        self.activityId = activityId
        self.token = token
        self.requestSuccessful = false
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(activityId, forKey: "activityId")
        coder.encode(token, forKey: "token")
        coder.encode(requestSuccessful, forKey: "requestSuccessful")
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let activityId = coder.decodeObject(forKey: "activityId") as? String,
            let token = coder.decodeObject(forKey: "token") as? String,
            let requestSuccessful = coder.decodeObject(forKey: "requestSuccessful") as? Bool,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.activityId = activityId
        self.token = token
        self.requestSuccessful = requestSuccessful
        super.init()
        self.timestamp = timestamp
    }
}
