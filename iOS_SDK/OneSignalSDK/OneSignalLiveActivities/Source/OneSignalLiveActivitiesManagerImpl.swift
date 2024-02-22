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
import ActivityKit

public class OneSignalLiveActivitiesManagerImpl: NSObject, OSLiveActivities {
    private static let _executor: OSLiveActivitiesExecutor = OSLiveActivitiesExecutor()
    
    @objc
    public static func LiveActivities() -> AnyClass {
        return OneSignalLiveActivitiesManagerImpl.self
    }
    
    @objc
    public static func start() {
        _executor.start()
    }
    
    @objc
    public static func enter(_ activityId: String, withToken: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities enter called with activityId: \(activityId) token: \(withToken)")
        _executor.append(OSRequestSetUpdateToken(key: activityId, token: withToken))
    }
    
    @objc
    public static func exit(_ activityId: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities leave called with activityId: \(activityId)")
        _executor.append(OSRequestRemoveUpdateToken(key: activityId))
    }
    
    @available(iOS 17.2, *)
    public static func setPushToStartToken(_ activityType: String, withToken: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities setStartToken called with activityType: \(activityType) token: \(withToken)")
        _executor.append(OSRequestSetStartToken(key: activityType, token: withToken))
    }
    
    @available(iOS 17.2, *)
    public static func removePushToStartToken(_ activityType: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities removeStartToken called with activityType: \(activityType)")
        _executor.append(OSRequestRemoveStartToken(key: "\(activityType)"))
    }
    
    @available(iOS 17.2, *)
    public static func setPushToStartToken<T>(_ activityType: T.Type, withToken: String) where T : ActivityAttributes {
        OneSignalLiveActivitiesManagerImpl.setPushToStartToken("\(activityType)", withToken: withToken)
    }
    
    @available(iOS 17.2, *)
    public static func removePushToStartToken<T>(_ activityType: T.Type) where T : ActivityAttributes {
        OneSignalLiveActivitiesManagerImpl.removePushToStartToken("\(activityType)")
    }
    
    @objc
    public static func enter(_ activityId: String, withToken: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?) {
        enter(activityId, withToken: withToken)
        
        if(withSuccess != nil) {
            DispatchQueue.main.async {
                withSuccess!([AnyHashable : Any]())
            }
        }
    }
    
    @objc
    public static func exit(_ activityId: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?) {
        exit(activityId)
        
        if(withSuccess != nil) {
            DispatchQueue.main.async {
                withSuccess!([AnyHashable : Any]())
            }
        }
    }
    
    @available(iOS 16.1, *)
    public static func monitor<Attributes : OneSignalLiveActivityAttributes>(_ activityType: Attributes.Type) {
        if #available(iOS 17.2, *) {
            Task {
                for try await data in Activity<Attributes>.pushToStartTokenUpdates {
                    let token = data.map {String(format: "%02x", $0)}.joined()
                    OneSignalLiveActivitiesManagerImpl.setPushToStartToken(Attributes.self, withToken: token)
                }
            }
        }
        
        Task {
            for await activity in Activity<Attributes>.activityUpdates {
                if #available(iOS 16.2, *) {
                    // if there's already an activity with the same OneSignal activityId, dismiss it before
                    // listening for the new activity's events.
                    for otherActivity in Activity<Attributes>.activities {
                        if activity.id != otherActivity.id && otherActivity.attributes.onesignal.activityId == activity.attributes.onesignal.activityId {
                            await otherActivity.end(nil, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
                        }
                    }
                }
                
                // listen for activity dismisses so we can forget about the token
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
                
                // listen for activity update token updates so we can tell OneSignal how to update the activity
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
