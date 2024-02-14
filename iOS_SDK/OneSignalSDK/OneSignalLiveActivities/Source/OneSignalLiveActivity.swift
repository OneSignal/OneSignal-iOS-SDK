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

import ActivityKit

/**
 A OneSignal wrapper which enables a user to provide their ActivityKit attributes, which conforms to the
 OneSignalActivityAttributes, and let the OneSignal SDK handle the synchronizing of pushToStart token
 updates, and push token upates, for that specific attribute type.
 */
@available(iOS 16.1, *)
public class OneSignalLiveActivity<Attributes> where Attributes : OneSignalLiveActivityAttributes {
    /**
     Enable the OneSignal SDK to manage
     */
    public static func enableLiveActivities(activityType: String) async {
        if #available(iOS 17.2, *) {
            Task {
                let data = Activity<Attributes>.pushToStartToken
                if data != nil {
                    let token = data!.map {String(format: "%02x", $0)}.joined()
                    OneSignalLiveActivitiesManagerImpl.setPushToStartToken(activityType, withToken: token)
                }
                for try await data in Activity<Attributes>.pushToStartTokenUpdates {
                    let token = data.map {String(format: "%02x", $0)}.joined()
                    OneSignalLiveActivitiesManagerImpl.setPushToStartToken(activityType, withToken: token)
                }
            }
        }
        
        Task {
            for await activity in Activity<Attributes>.activityUpdates {
                Task {
                    for await activityState in activity.activityStateUpdates {
                        switch activityState {
                        case .dismissed:
                            OneSignalLiveActivitiesManagerImpl.exit(activity.attributes.onesignal.activityId)
                        case .active: break
                        case .ended: break
                        case .stale: break
                        default: break
                        }
                    }
                }
                Task {
                    for await pushToken in activity.pushTokenUpdates {
                        let token = pushToken.map {String(format: "%02x", $0)}.joined()
                        OneSignalLiveActivitiesManagerImpl.enter(activity.attributes.onesignal.activityId, withToken: token)
                    }
                }
            }
        }
    }
}
