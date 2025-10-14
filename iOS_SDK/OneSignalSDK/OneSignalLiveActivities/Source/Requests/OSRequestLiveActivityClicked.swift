/*
 Modified MIT License

 Copyright 2025 OneSignal

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

class OSRequestLiveActivityClicked: OneSignalRequest, OSLiveActivityRequest {
    override var description: String { return "(OSRequestLiveActivityClicked) key:\(key) requestSuccessful:\(requestSuccessful) activityType:\(activityType) activityId:\(activityId)" }

    var key: String // UUID representing this unique click
    var activityType: String
    var activityId: String
    var requestSuccessful: Bool
    var shouldForgetWhenSuccessful: Bool = true

    func prepareForExecution() -> Bool {
        guard let appId = OneSignalConfigManager.getAppId() else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the OSRequestLiveActivityClicked due to null app ID.")
            return false
        }

        guard let subscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the OSRequestLiveActivityClicked due to null subscription ID.")
            return false
        }

        // TODO: ⚠️ What is the path, method, and parameters
        // TODO: ⚠️ Need to guard for encoding activity strings if in path
        // TODO: ⚠️ Timestamp since we are caching? Same for received event.
        self.path = "foo/bar/\(activityId)/click"
        self.parameters = [
            "app_id": appId,
            "player_id": subscriptionId,
            "device_type": 0,
            "live_activity_id": activityId,
            "live_activity_type": activityType,
            "click_id": key,
            "timestamp": ISO8601DateFormatter().string(from: timestamp)
        ]
        self.method = POST

        return true
    }

    func supersedes(_ existing: any OSLiveActivityRequest) -> Bool {
        return false
    }

    init(key: String, activityType: String, activityId: String) {
        self.key = key
        self.activityType = activityType
        self.activityId = activityId
        self.requestSuccessful = false
        super.init()
    }

    func encode(with coder: NSCoder) {
        coder.encode(key, forKey: "key")
        coder.encode(activityType, forKey: "activityType")
        coder.encode(activityId, forKey: "activityId")
        coder.encode(requestSuccessful, forKey: "requestSuccessful")
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let key = coder.decodeObject(forKey: "key") as? String,
            let activityType = coder.decodeObject(forKey: "activityType") as? String,
            let activityId = coder.decodeObject(forKey: "activityId") as? String,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            return nil
        }
        self.key = key
        self.activityType = activityType
        self.activityId = activityId
        self.requestSuccessful = coder.decodeBool(forKey: "requestSuccessful")
        super.init()
        self.timestamp = timestamp
    }
}
