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
public protocol OneSignalLiveActivityAttributes: ActivityAttributes {
    /**
     A reserved attribute name used by the OneSignal SDK.  If starting the live activity via
     pushToStart, this will be a populated attribute by the push to start notification. If starting
     the live activity programmatically, use `OneSignalLiveActivityAttributeData.create`
     to create this data.
     */
    var onesignal: OneSignalLiveActivityAttributeData { get set }
}

/**
 OneSignal-specific metadata used internally. If using pushToStart, this will be passed into
 the started live activity.  If starting the live activity programmatically, use
 `OneSignalLiveActivityAttributeData.create` to create this data.
 */
public struct OneSignalLiveActivityAttributeData : Decodable, Encodable {
    
    /**
     Create a new instance of `OneSignalLiveActivityAttributeData`
     - Parameters
        - activityId: The activity identifier OneSignal will use to push updates for.
     */
    public static func create(activityId: String) -> OneSignalLiveActivityAttributeData {
        OneSignalLiveActivityAttributeData(activityId: activityId)
    }
    
    public var activityId: String
}
