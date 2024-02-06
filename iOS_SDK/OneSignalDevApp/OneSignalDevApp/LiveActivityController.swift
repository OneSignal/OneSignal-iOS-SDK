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
import ActivityKit
import UserNotifications

struct OneSignalWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var message: String
    }

    // Fixed non-changing properties about your activity go here!
    var onesignalActivityId: String
}

@objc
class LiveActivityController: NSObject {
    
    @available(iOS 17.2, *)
    @objc
    static func pushToStart() async {
        Task {
            for try await data in Activity<OneSignalWidgetAttributes>.pushToStartTokenUpdates {
                let token = data.map {String(format: "%02x", $0)}.joined()
                print("pushToStartToken: \(token)")
            }
        }
    }
    
    @available(iOS 17.2, *)
    @objc
    static func observeActivityPushToken() {
        Task {
            for await activityData in Activity<OneSignalWidgetAttributes>.activityUpdates {
                Task {
                    for await tokenData in activityData.pushTokenUpdates {
                        let token = tokenData.map {String(format: "%02x", $0)}.joined()
                        print("observe Activity Push Token Push token: \(token)")
                        print("observe Activity Push Token attributes: \(activityData.attributes.onesignalActivityId)")
                    }
                }
            }
        }
    }

    // To aid in testing
    static var counter = 0
    
    @available(iOS 13.0, *)
    @objc
    static func createActivity() async -> String? {
        if #available(iOS 16.2, *) {
            counter += 1
            let attributes = OneSignalWidgetAttributes(onesignalActivityId: "bar")
            let contentState = OneSignalWidgetAttributes.ContentState(message: "Update this message through push or with Activity Kit")
            do {
                let activity = try Activity<OneSignalWidgetAttributes>.request(
                        attributes: attributes,
                        contentState: contentState,
                        pushType: .token)
                Task {
                    for await state in activity.activityStateUpdates {
                        print("LA state update: \(state)")
                    }
                }
                
                Task {
                    for await content in activity.contentUpdates {
                        print("LA activity id: \(activity.id), content update: \(content.state)")
                    }
                }
                
                for await data in activity.pushTokenUpdates {
                    let myToken = data.map {String(format: "%02x", $0)}.joined()
                    print("LA pushTokenUpdates: \(myToken)")
                    print("LA pushTokenUpdates attributes: \(activity.attributes)")
                    return myToken
                }
            } catch let error {
                print(error.localizedDescription)
                return nil
            }
        }
        return nil
    }
    
    @available(iOS 16.2, *)
    @objc
    static func endActivity() async {
        for activity in Activity<OneSignalWidgetAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("Ending the Live Activity: \(activity.id)")
        }
    }
    
    @available(iOS 16.1, *)
    @objc
    static func listenForActivityUpdates() async {
//        for await activity in Activity<OneSignalWidgetAttributes>.activityUpdates {
//            print("new activity added: \(activity.id)")
//        }
    }
}
