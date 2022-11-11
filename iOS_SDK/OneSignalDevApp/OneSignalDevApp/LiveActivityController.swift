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
    @objc
    static func createActivity() {
        if #available(iOS 16.1, *) {
            let attributes = OneSignalWidgetAttributes(title: "OneSignal Dev App Live Activity")
            let contentState = OneSignalWidgetAttributes.ContentState(message: "Update this message through push or with Activity Kit")
            do {
               
                    let _ = try Activity<OneSignalWidgetAttributes>.request(
                        attributes: attributes,
                        contentState: contentState,
                        pushType: .token)
            } catch (let error) {
                print(error.localizedDescription)
            }
        } else {
            // Fallback on earlier versions
        }
    }
}
