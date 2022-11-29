//
//  LiveActivityController.swift
//  OneSignalExample
//
//  Created by Henry Boswell on 11/9/22.
//  Copyright © 2022 OneSignal. All rights reserved.
//

import Foundation
import ActivityKit
import UserNotifications

struct OneSignalWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var message: String
    }

    // Fixed non-changing properties about your activity go here!
    var title: String
}
@objc
class LiveActivityController: NSObject {
    // To aid in testing
    static var counter = 0
    @available(iOS 13.0, *)
    @objc
    static func createActivity() async -> String? {
        if #available(iOS 16.1, *) {
            counter += 1;
            let attributes = OneSignalWidgetAttributes(title: "#" + String(counter) + " OneSignal Dev App Live Activity")
            let contentState = OneSignalWidgetAttributes.ContentState(message: "Update this message through push or with Activity Kit")
            do {
                let activity = try Activity<OneSignalWidgetAttributes>.request(
                        attributes: attributes,
                        contentState: contentState,
                        pushType: .token)
                for await data in activity.pushTokenUpdates {
                    let myToken = data.map {String(format: "%02x", $0)}.joined()
                    return myToken
                }
            } catch (let error) {
                print(error.localizedDescription)
                return nil
            }
        }
        return nil
    }
}
