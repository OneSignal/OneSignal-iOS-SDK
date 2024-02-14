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
@objc
public class OneSignalLiveActivitiesManager: NSObject {
    @objc public static let sharedInstance = OneSignalLiveActivitiesManager()
    
    private let _executor: OSLiveActivitiesExecutor
    
    override init() {
        _executor = OSLiveActivitiesExecutor()
    }
    
    @objc
    public func start() {
//        _executor.start()
    }
    
    @objc
    public func setUpdateToken(activityId: String, token: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities enter called with activityId: \(activityId) token: \(token)")
        _executor.append(OSRequestSetUpdateToken(activityId: activityId, token: token))
    }
    
    @objc
    public func removeUpdateToken(activityId: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities leave called with activityId: \(activityId)")
        _executor.append(OSRequestRemoveUpdateToken(activityId: activityId))
    }
    
    @objc
    public func setStartToken(activityType: String, token: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities setStartToken called with activityType: \(activityType) token: \(token)")
        _executor.append(OSRequestSetStartToken(activityType: activityType, token: token))
    }
    
    @objc
    public func removeStartToken(activityType: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities removeStartToken called with activityType: \(activityType)")
        _executor.append(OSRequestRemoveStartToken(activityType: activityType))
    }
}
