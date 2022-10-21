//
//  LiveActivityController.swift
//  OneSignalExample
//
//  Created by Henry Boswell on 10/20/22.
//  Copyright © 2022 OneSignal. All rights reserved.
//

import Foundation
import ActivityKit
import UserNotifications

struct OneSignalWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var value: Int
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}
@objc
class LiveActivityController: NSObject {
    @objc
    static func createActivity() {
        if #available(iOS 16.1, *) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                
                if let error = error {
                    // Handle the error here.
                }
                
                // Enable or disable features based on the authorization.
            }
            
            let attributes = OneSignalWidgetAttributes(name: "OneSignal")
            let contentState = OneSignalWidgetAttributes.ContentState(value: 5)
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
