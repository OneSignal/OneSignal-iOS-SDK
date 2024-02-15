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

@objc public protocol OSLiveActivities {
    static func enter(_ activityId: String, withToken: String)
    static func enter(_ activityId: String, withToken: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?)
    static func exit(_ activityId: String)
    static func exit(_ activityId: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?)
    
    static func setPushToStartToken(_ activityType: String, withToken: String)
    static func removePushToStartToken(_ activityType: String)
}

@objc
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
        _executor.append(OSRequestSetUpdateToken(activityId: activityId, token: withToken))
    }
    
    @objc
    public static func exit(_ activityId: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities leave called with activityId: \(activityId)")
        _executor.append(OSRequestRemoveUpdateToken(activityId: activityId))
    }
    
    @objc
    public static func setPushToStartToken(_ activityType: String, withToken: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities setStartToken called with activityType: \(activityType) token: \(withToken)")
        _executor.append(OSRequestSetStartToken(activityType: activityType, token: withToken))
    }
    
    @objc
    public static func removePushToStartToken(_ activityType: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities removeStartToken called with activityType: \(activityType)")
        _executor.append(OSRequestRemoveStartToken(activityType: activityType))
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
}
