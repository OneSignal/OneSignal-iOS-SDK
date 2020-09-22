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
class AppDelegate: UIResponder, UIApplicationDelegate, OSPermissionObserver, OSSubscriptionObserver { // Add OSPermissionObserver after UIApplicationDelegate
    // Add OSSubscriptionObserver after UIApplicationDelegate
    
    var window: UIWindow?
    
    let redViewController = RedViewController()
    let greenViewController = GreenViewController()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // For debugging
        OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE)
        
        let notifWillShowInForegroundHandler: OSNotificationWillShowInForegroundBlock = { notification, completion in
            print("Received Notification: ", notification.notificationId ?? "no id")
            print("launchURL: ", notification.launchURL ?? "no launch url")
            print("content_available = \(notification.contentAvailable)")
        }
        
        let notificationOpenedBlock: OSNotificationOpenedBlock = { result in
            // This block gets called when the user reacts to a notification received
            let notification: OSNotification = result.notification
            
            print("Message: ", notification.body ?? "empty body")
            print("badge number: ", notification.badge)
            print("notification sound: ", notification.sound ?? "No sound")
            
            if let additionalData = notification.additionalData {
                print("additionalData: ", additionalData)
                
                if let actionSelected = notification.actionButtons {
                    print("actionSelected: ", actionSelected)
                }
                
                // DEEP LINK from action buttons
                if let actionID = result.action.actionId {
                    
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
            }
        }

        let onesignalInitSettings = [kOSSettingsKeyAutoPrompt: false, kOSSettingsKeyInAppLaunchURL: true,]
        
        OneSignal.setAppId("3beb3078-e0f1-4629-af17-fde833b9f716")
        OneSignal.initWithLaunchOptions(launchOptions)
        OneSignal.setNotificationOpenedHandler(notificationOpenedBlock)
        OneSignal.setNotificationWillShowInForegroundHandler(notifWillShowInForegroundHandler)
        OneSignal.setAppSettings(onesignalInitSettings)
        
        // Add your AppDelegate as an obsserver
        OneSignal.add(self as OSPermissionObserver)
        
        OneSignal.add(self as OSSubscriptionObserver)
        
        return true
    }
    
    // Add this new method
    func onOSPermissionChanged(_ stateChanges: OSPermissionStateChanges) {
        
        // Example of detecting answering the permission prompt
        if stateChanges.from.status == OSNotificationPermission.notDetermined {
            if stateChanges.to.status == OSNotificationPermission.authorized {
                print("Thanks for accepting notifications!")
            } else if stateChanges.to.status == OSNotificationPermission.denied {
                print("Notifications not accepted. You can turn them on later under your iOS settings.")
            }
        }
        // prints out all properties
        print("PermissionStateChanges: ", stateChanges)
    }
    
    // Output:
    /*
     Thanks for accepting notifications!
     PermissionStateChanges:
     Optional(<OSSubscriptionStateChanges:
     from: <OSPermissionState: hasPrompted: 0, status: NotDetermined>,
     to:   <OSPermissionState: hasPrompted: 1, status: Authorized>
     >
     */
    
    // TODO: update docs to change method name
    // Add this new method
    func onOSSubscriptionChanged(_ stateChanges: OSSubscriptionStateChanges) {
        if !stateChanges.from.subscribed && stateChanges.to.subscribed {
            print("Subscribed for OneSignal push notifications!")
        }
        print("SubscriptionStateChange: ", stateChanges)
    }
    
    // Output:
    
    /*
     Subscribed for OneSignal push notifications!
     PermissionStateChanges:
     Optional(<OSSubscriptionStateChanges:
     from: <OSSubscriptionState: userId: (null), pushToken: 0000000000000000000000000000000000000000000000000000000000000000 userSubscriptionSetting: 1, subscribed: 0>,
     to:   <OSSubscriptionState: userId: 11111111-222-333-444-555555555555, pushToken: 0000000000000000000000000000000000000000000000000000000000000000, userSubscriptionSetting: 1, subscribed: 1>
     >
     */
}

