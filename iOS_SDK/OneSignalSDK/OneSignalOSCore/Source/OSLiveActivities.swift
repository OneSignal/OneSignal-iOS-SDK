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

/**
 Provides access to OneSignal LiveActivities.
 */
@objc
public protocol OSLiveActivities {
    /**
     Indicate this device has entered a live activity, identified within OneSignal by the `activityId`.
     - Parameters
        - activityId: The activity identifier the live activity on this device will receive updates for.
        - withToken: The live activity's update token to receive the updates.
     */
    static func enter(_ activityId: String, withToken: String)

    /**
     Indicate this device has entered a live activity, identified within OneSignal by the `activityId`. This method is deprecated since
     the request to enter a live activity will always succeed.
     - Parameters
        - activityId: The activity identifier the live activity on this device will receive updates for.
        - withToken: The live activity's update token to receive the updates.
        - withSuccess: A success callback that will be called when the live activity enter request has been queued.
        - withFailure: A failure callback that will be called when the live activity enter request was not successfully queued.
     */
    @available(*, deprecated)
    static func enter(_ activityId: String, withToken: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?)

    /**
     Indicate this device has exited a live activity, identified within OneSignal by the `activityId`.
     - Parameters
        - activityId: The activity identifier the live activity on this device will no longer receive updates for.
     */
    static func exit(_ activityId: String)

    /**
     Indicate this device has exited a live activity, identified within OneSignal by the `activityId`. This method is deprecated since
     the request to enter a live activity will always succeed.
     - Parameters
        - activityId: The activity identifier the live activity on this device will no longer receive updates for.
        - withSuccess: A success callback that will be called when the live activity exit request has been queued.
        - withFailure: A failure callback that will be called when the live activity enter exit was not successfully queued.
     */
    @available(*, deprecated)
    static func exit(_ activityId: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?)
}
