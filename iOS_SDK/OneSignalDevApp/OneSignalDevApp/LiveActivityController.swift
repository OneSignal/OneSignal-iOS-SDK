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

import Foundation
import UserNotifications
import OneSignalFramework
#if targetEnvironment(macCatalyst)
#else
import ActivityKit
import OneSignalLiveActivities
@objc
class LiveActivityController: NSObject {

    @available(iOS 16.1, *)
    @objc
    static func start() {
        // ExampleAppFirstWidgetAttributes and ExampleAppSecondWidgetAttributes enable the OneSignal SDK to
        // listen for start/update tokens, this is the only call needed.
        OneSignal.LiveActivities.setup(ExampleAppFirstWidgetAttributes.self)
        OneSignal.LiveActivities.setup(ExampleAppSecondWidgetAttributes.self)

        // There is a "built in" Live Activity Widget Attributes called `DefaultLiveActivityAttributes`.
        // This is mostly for cross-platform SDKs and allows OneSignal to handle everything but the
        // creation of the Widget Extension.
        OneSignal.LiveActivities.setupDefault()

        if #available(iOS 17.2, *) {
            // ExampleAppThirdWidgetAttributes is an example of how to manually set up LA.
            // Setup an async task to monitor and send pushToStartToken updates to OneSignalSDK.
            Task {
                for try await data in Activity<ExampleAppThirdWidgetAttributes>.pushToStartTokenUpdates {
                    let token = data.map {String(format: "%02x", $0)}.joined()
                    OneSignal.LiveActivities.setPushToStartToken(ExampleAppThirdWidgetAttributes.self, withToken: token)
                }
            }
            // Setup an async task to monitor for an activity to be started, for each started activity we
            // can then set up an async task to monitor and send updateToken updates to OneSignalSDK.  We
            // filter out LA started in-app, because the `createActivity` function below does its own
            // updateToken update monitoring. If there can be multiple instances of this activity-type,
            // the activity-id (i.e. "my-activity-id") is most likely passed down as an attribute within
            // ExampleAppThirdWidgetAttributes.
            Task {
                for await activity in Activity<ExampleAppThirdWidgetAttributes>.activityUpdates
                    where activity.attributes.isPushToStart {
                    Task {
                        for await pushToken in activity.pushTokenUpdates {
                            let token = pushToken.map {String(format: "%02x", $0)}.joined()
                            OneSignal.LiveActivities.enter("my-activity-id", withToken: token)
                        }
                    }
                }
            }
        }
    }

     /**
      An example of starting a Live Activity whose attributes are "OneSignal SDK aware". The SDK will handle listening for update tokens on behalf of the app.
      */
     static var counter1 = 0
     @available(iOS 13.0, *)
     @objc
     static func createOneSignalAwareActivity(activityId: String) {
         if #available(iOS 16.1, *) {
             counter1 += 1
             let oneSignalAttribute = OneSignalLiveActivityAttributeData.create(activityId: activityId)
             let attributes = ExampleAppFirstWidgetAttributes(title: "#" + String(counter1) + " OneSignal Dev App Live Activity", onesignal: oneSignalAttribute)
             let contentState = ExampleAppFirstWidgetAttributes.ContentState(message: "Update this message through push or with Activity Kit")
             do {
                 _ = try Activity<ExampleAppFirstWidgetAttributes>.request(
                         attributes: attributes,
                         contentState: contentState,
                         pushType: .token)
             } catch let error {
                 print(error.localizedDescription)
             }
         }
     }

    /**
     An example of starting a Live Activity using the DefaultLiveActivityAttributes.  The SDK will handle listening for update tokens on behalf of the app.
     */
    @available(iOS 13.0, *)
    @objc
    static func createDefaultActivity(activityId: String) {
        if #available(iOS 16.1, *) {
            let attributeData: [String: Any] = ["title": "in-app-title"]
            let contentData: [String: Any] = ["message": ["en": "HELLO", "es": "HOLA"], "progress": 0.58, "status": "1/15", "bugs": 2]

            OneSignal.LiveActivities.startDefault(activityId, attributes: attributeData, content: contentData)
        }
    }

    /**
     An example of starting a Live Activity whose attributes are **not** "OneSignal SDK aware".  The app must handle listening for update tokens and notify the OneSignal SDK.
     */
    static var counter2 = 0
    @available(iOS 13.0, *)
    @objc
    static func createActivity(activityId: String) async {
        if #available(iOS 16.1, *) {
            counter2 += 1
            let attributes = ExampleAppThirdWidgetAttributes(title: "#" + String(counter2) + " OneSignal Dev App Live Activity", isPushToStart: false)
            let contentState = ExampleAppThirdWidgetAttributes.ContentState(message: "Update this message through push or with Activity Kit")
            do {
                let activity = try Activity<ExampleAppThirdWidgetAttributes>.request(
                        attributes: attributes,
                        contentState: contentState,
                        pushType: .token)
                for await data in activity.pushTokenUpdates {
                    let myToken = data.map {String(format: "%02x", $0)}.joined()
                    OneSignal.LiveActivities.enter(activityId, withToken: myToken)
                }
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
}
#endif
