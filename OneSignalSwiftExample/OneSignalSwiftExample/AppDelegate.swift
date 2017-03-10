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
    
    let redViewController = RedViewController()
    let greenViewController = GreenViewController()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
                
        // For debugging
        OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE)

        // Replace 'd368162e-7c4e-48b0-bc7c-b82ba80d4981' with your OneSignal App ID
        OneSignal.initWithLaunchOptions(launchOptions, appId: "d368162e-7c4e-48b0-bc7c-b82ba80d4981",
            handleNotificationReceived: {
                // OSHandleNotificationRecevedBlock - Function to be called when a notification is received
              notification in

                print("notificationID - \((notification?.payload.notificationID)!)")
                print("launchURL = \(notification?.payload.launchURL)")

                // content_available is NOT APPLICABLE IF APP HAS BEEN SWIPED AWAY
                print("content_available = \(notification?.payload.contentAvailable)")
        },
            handleNotificationAction:
            { // OSHandleNotificationActionBlock - Function to be called when a user reacts to a notification received
              result in
                
                let displayType: OSNotificationDisplayType? = result?.notification.displayType
                print("displayType = \(displayType!.rawValue)")
            
                let wasShown: Bool? = result?.notification.wasShown
                print("wasShown = \(wasShown!)")
                
                // https://documentation.onesignal.com/docs/ios-native-sdk#section--osnotificationpayload-
                let payload: OSNotificationPayload? = result?.notification.payload

                print("badge number = \(payload?.badge)")
                print("notification sound = \(payload?.sound)")
                
                if let additionalData: [AnyHashable : Any]? = payload?.additionalData {
                    print("additionalData = \(additionalData)")
                }
                
                if let actionSelected = payload?.actionButtons {
                    print("actionSelected = \(actionSelected)")
                }
                
                
                if let actionID = result?.action.actionID {
                    
                    // For presenting a ViewController from push notification action button
                    let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                    let instantiateRedViewController : UIViewController = mainStoryboard.instantiateViewController(withIdentifier: "RedViewControllerID") as UIViewController
                    let instantiatedGreenViewController: UIViewController = mainStoryboard.instantiateViewController(withIdentifier: "GreenViewControllerID") as UIViewController
                    self.window = UIWindow(frame: UIScreen.main.bounds)
                    
                    print("actionID = \(actionID)")
                    
                    if actionID == "id2" {
                        print("do something when button 2 is pressed")
                        self.window?.rootViewController = instantiateRedViewController
                        self.window?.makeKeyAndVisible()


                    } else if actionID == "id1" {
                        print("do something when button 1 is pressed")
                        self.window?.rootViewController = instantiatedGreenViewController
                        self.window?.makeKeyAndVisible()

                    }
                }
        },
           settings: [
            kOSSettingsKeyAutoPrompt : false, // automatically prompts users to Enable Notifications
                
            kOSSettingsKeyInFocusDisplayOption : OSNotificationDisplayType.notification.rawValue,
            
            kOSSettingsKeyInAppLaunchURL: true // true-default
            ])
        
        return true
    }
    
}

