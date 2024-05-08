/**
 * Modified MIT License
 *
 * Copyright 2023 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
#if targetEnvironment(macCatalyst)
#else
import ActivityKit
import OneSignalLiveActivities

 /**
  An example of an ActivityAttribute that is "OneSignal SDK aware".  This attribute conforms
  to the OneSignalActivityAttributes protocol and has a onesignal property, which contains
  metadata used by the OneSignal SDK.  To enable this Live Activity type for OneSignal
  you only need to call `enableLiveActivities`, the SDK takes care of the rest.
  */
 struct ExampleAppFirstWidgetAttributes: OneSignalLiveActivityAttributes {
     public struct ContentState: OneSignalLiveActivityContentState {
         // Dynamic stateful properties about your activity go here!
         var message: String

         var onesignal: OneSignalLiveActivityContentStateData?
     }

     // Fixed non-changing properties about your activity go here!
     var title: String

     // OneSignal Attributes to allow the SDK to do it's thing
     var onesignal: OneSignalLiveActivityAttributeData
 }

 /**
  Another example of an ActivityAttribute that is "OneSignal SDK aware".  A second attributes
  structure is created here because the example app has two different "types" of Live Activity
  experiences.  Noting that `enableLiveActivities` must be called for each "type" of
  Live Activity defined.
  */
 struct ExampleAppSecondWidgetAttributes: OneSignalLiveActivityAttributes {
     public struct ContentState: OneSignalLiveActivityContentState {
         var message: String
         var status: String
         var progress: Double
         var bugs: Int

         var onesignal: OneSignalLiveActivityContentStateData?
     }

     // Fixed non-changing properties about your activity go here!
     var title: String

     // OneSignal Attributes to allow the SDK to do it's thing
     var onesignal: OneSignalLiveActivityAttributeData
 }

 /**
  This example of an ActivityAttribute is **not** "OneSignal SDK aware". Listening
  to push to start tokens and update tokens for this activity must be done by the app
  itself.
  */
 struct ExampleAppThirdWidgetAttributes: ActivityAttributes {
     public struct ContentState: Codable, Hashable {
         // Dynamic stateful properties about your activity go here!
         var message: String
     }

     // Fixed non-changing properties about your activity go here!
     var title: String

     // Whether this LA was started via pushToStart (true), or via app (false)
     var isPushToStart: Bool
 }
#endif
