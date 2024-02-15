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
 The protocol your ActivityAttributes should conform to in order to allow the OneSignal SDK to manage
 the pushToStart and update token synchronization process on your behalf.
 */
@available(iOS 16.1, *)
public protocol OneSignalActivityAttributes: ActivityAttributes {
    /**
     A reserved attribute name used by the OneSignal SDK.  If starting the live activity via
     pushToStart, this will be a populated attribute by the push to start notification. If starting
     the live activity programmatically, use OneSignalActivity<Attributes>.createLiveActivityAttributeData
     to create this data.
     */
    var onesignal: OneSignalActivityAttributeData { get set }
}

/**
 OneSignal-specific metadata used internally. If using pushToStart, this will be passed into
 the started live activity.  If starting the live activity programmatically, use
 OneSignalActivity<Attributes>.createLiveActivityAttributeData to create a new instance.
 */
public struct OneSignalActivityAttributeData : Decodable, Encodable {
    public var activityId: String
}

/**
 A OneSignal wrapper which enables a user to provide their ActivityKit attributes, which conforms to the
 OneSignalActivityAttributes, and let the OneSignal SDK handle the synchronizing of pushToStart token
 updates, and push token upates, for that specific attribute type.
 */
@available(iOS 16.1, *)
public class OneSignalActivity<Attributes> where Attributes : OneSignalActivityAttributes {
    public static func createLiveActivityAttributeData(activityId: String) -> OneSignalActivityAttributeData {
        OneSignalActivityAttributeData(activityId: activityId)
    }
    
    /**
     Enable the OneSignal SDK to manage 
     */
    public static func enableLiveActivities(activityType: String) async {
        if #available(iOS 17.2, *) {
            Task {
                let data = Activity<Attributes>.pushToStartToken
                if data != nil {
                    let token = data!.map {String(format: "%02x", $0)}.joined()
                    OneSignalLiveActivitiesManager.sharedInstance.setStartToken(activityType: activityType, token: token)
                }
                let x = "\(Attributes.self)"
                for try await data in Activity<Attributes>.pushToStartTokenUpdates {
                    let token = data.map {String(format: "%02x", $0)}.joined()
                    OneSignalLiveActivitiesManager.sharedInstance.setStartToken(activityType: activityType, token: token)
                }
            }
        }
        
        Task {
            for await activity in Activity<Attributes>.activityUpdates {
                Task {
                    for await activityState in activity.activityStateUpdates {
                        switch activityState {
                        case .dismissed:
                            OneSignalLiveActivitiesManager.sharedInstance.removeUpdateToken(activityId: activity.attributes.onesignal.activityId)
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
                        OneSignalLiveActivitiesManager.sharedInstance.setUpdateToken(activityId: activity.attributes.onesignal.activityId, token: token)
                    }
                }
            }
        }
    }
}