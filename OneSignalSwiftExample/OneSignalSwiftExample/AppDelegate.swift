/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
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

import UIKit
import OneSignal

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE)
        
        OneSignal.initWithLaunchOptions(launchOptions, appId: "b2f7f966-d8cc-11e4-bed1-df8f05be55ba", handleNotificationReceived: { (notification) in
                print("Received Notification - \(notification?.payload.notificationID)")
            }, handleNotificationAction: { (result) in
                
                // This block gets called when the user reacts to a notification received
                let payload = result?.notification.payload
                var fullMessage = payload?.title
                
                //Try to fetch the action selected
                if let actionSelected = result?.action.actionID {
                    fullMessage =  fullMessage! + "\nPressed ButtonId:\(actionSelected)"
                }
                
                print(fullMessage)
                
            }, settings: [kOSSettingsKeyAutoPrompt : true,
                          kOSSettingsKeyInFocusDisplayOption : OSNotificationDisplayType.notification.rawValue])
        
        OneSignal.idsAvailable({ (userId, pushToken) in
            print("UserId = \(userId)")
            if (pushToken != nil) {
                NSLog("Sending Test Noification to this device now");
                OneSignal.postNotification(["contents": ["en": "Test Message"], "include_player_ids": [userId]]);
            }
        });
        
        
        // iOS 10 ONLY - Add category for the OSContentExtension
        // Make sure to add UserNotifications framework in the Linked Frameworks & Libraries.
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationCategories { (categories) in
                let myAction = UNNotificationAction(identifier: "action0", title: "Hit Me!", options: .foreground)
                let myCategory = UNNotificationCategory(identifier: "myOSContentCategory", actions: [myAction], intentIdentifiers: [], options: .customDismissAction)
                let mySet = NSSet(array: [myCategory]).addingObjects(from: categories) as! Set<UNNotificationCategory>
                UNUserNotificationCenter.current().setNotificationCategories(mySet)
            }
        }
        
        return true
    }
}

