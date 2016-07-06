//
//  OneSignal-UIApplication.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation


extension UIApplication {
    
    func oneSignalDidRegisterForRemoteNotifications(_ app : UIApplication, deviceToken inDeviceToken : Data) {
        
        OneSignal.didRegisterForRemoteNotifications(app, deviceToken: inDeviceToken)

        if self.responds(to: #selector(UIApplication.oneSignalDidRegisterForRemoteNotifications(_:deviceToken:))) {
            self.oneSignalDidRegisterForRemoteNotifications(app, deviceToken: inDeviceToken)
        }
    }
    
    func oneSignalDidFailRegisterForRemoteNotifications(_ app : UIApplication, error : NSError) {
        OneSignal.onesignal_Log(.ERROR, message: "Error registering for Apple push notifications. Error: \(error)")
        
        if self.responds(to: #selector(UIApplication.oneSignalDidFailRegisterForRemoteNotifications(_:error:))) {
            self.oneSignalDidFailRegisterForRemoteNotifications(app, error: error)
        }
    }
    
    @available(iOS 8.0, *)
    func oneSignalDidRegisterUserNotifications(_ application : UIApplication, settings notificationSettings : UIUserNotificationSettings) {
    
        OneSignal.updateNotificationTypes(Int(notificationSettings.types.rawValue))
        
        if self.responds(to: #selector(UIApplication.oneSignalDidRegisterUserNotifications(_:settings:))) {
            self.oneSignalDidRegisterUserNotifications(application, settings: notificationSettings)
        }
    }
    
    func oneSignalRemoteSilentNotification(_ application : UIApplication, userInfo : NSDictionary, fetchCompletionHandler completionHandler : (UIBackgroundFetchResult) -> Void) {

        OneSignal.remoteSilentNotification(application, userInfo: userInfo)
        
        if self.responds(to: #selector(UIApplication.oneSignalRemoteSilentNotification(_:userInfo:fetchCompletionHandler:))) {
            self.oneSignalRemoteSilentNotification(application, userInfo: userInfo, fetchCompletionHandler: completionHandler)
        }
        else {
            completionHandler(UIBackgroundFetchResult.newData)
        }
    }
    
    func oneSignalLocalNotificationOpened(_ application : UIApplication, handleActionWithIdentifier identifier : NSString, forLocalNotification notification : UILocalNotification, completionHandler : ()-> Void) {
        
       
        OneSignal.processLocalActionBasedNotification(notification, identifier: identifier)
        
        if self.responds(to: #selector(UIApplication.oneSignalLocalNotificationOpened(_:handleActionWithIdentifier:forLocalNotification:completionHandler:))) {
            self.oneSignalLocalNotificationOpened(application, handleActionWithIdentifier: identifier, forLocalNotification: notification, completionHandler: completionHandler)
        }
        else {
            completionHandler()
        }
    }
    
    func oneSignalLocalNotificationOpened(_ application : UIApplication, notification : UILocalNotification) {
        
        OneSignal.processLocalActionBasedNotification(notification, identifier: "__DEFAULT__")
        
        if self.responds(to: #selector(UIApplication.oneSignalLocalNotificationOpened(_:notification:))) {
            self.oneSignalLocalNotificationOpened(application, notification: notification)
        }
    }
    
    func oneSignalApplicationWillResignActive(_ application : UIApplication) {
        
        OneSignal.onFocus("suspend")
        
        if self.responds(to: #selector(UIApplication.oneSignalApplicationWillResignActive(_:))) {
            self.oneSignalApplicationWillResignActive(application)
        }
    }
    
    func oneSignalApplicationDidbecomeActive(_ application : UIApplication) {
        
        OneSignal.onFocus("resume")
        
        if self.responds(to: #selector(UIApplication.oneSignalApplicationDidbecomeActive(_:))) {
            self.oneSignalApplicationDidbecomeActive(application)
        }
    }
    
    @nonobjc static var appDelegateClass : AnyClass? = nil
    
    override public static func initialize() {
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return }
        //struct Static { static var token: Int = 0 }
        if self !== UIApplication.self { return } /* Make sure this isn't a subclass */
        
        //dispatch_once(&Static.token) {
    
            //Exchange UIApplications's setDelegate with OneSignal's
            let originalSelector = NSSelectorFromString("setDelegate:")
            let swizzledSelector = #selector(UIApplication.setOneSignalDelegate(_:))
            
            let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
            let originalMethod = class_getInstanceMethod(self,originalSelector)
            let didAddMethod = class_addMethod(self, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
            
            if didAddMethod {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
            }
            else { method_exchangeImplementations(originalMethod, swizzledMethod) }
        //}
        
    }
    
    func setOneSignalDelegate(_ delegate : UIApplicationDelegate) {
        
        if UIApplication.appDelegateClass != nil {
            self.setOneSignalDelegate(delegate)
            return
        }
        
        UIApplication.appDelegateClass = OneSignal.getClassWithProtocolInHierarchy((delegate as AnyObject).classForCoder, protocolToFind: UIApplicationDelegate.self)
        
        if UIApplication.appDelegateClass == nil { return }
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalRemoteSilentNotification(_:userInfo:fetchCompletionHandler:)), addToClass: UIApplication.appDelegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalLocalNotificationOpened(_:handleActionWithIdentifier:forLocalNotification:completionHandler:)), addToClass: UIApplication.appDelegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:handleActionWithIdentifier:for:completionHandler:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalDidRegisterUserNotifications(_:settings:)), addToClass: UIApplication.appDelegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didRegister:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalDidFailRegisterForRemoteNotifications(_:error:)), addToClass: UIApplication.appDelegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)))
        
        
        if NSClassFromString("CoronaAppDelegate") != nil {
            self.setOneSignalDelegate(delegate)
            return
        }
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalDidRegisterForRemoteNotifications(_:deviceToken:)), addToClass: UIApplication.appDelegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalLocalNotificationOpened(_:notification:)), addToClass: UIApplication.appDelegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceive:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalApplicationWillResignActive(_:)), addToClass: UIApplication.appDelegateClass!, makeLikeSel: #selector(UIApplicationDelegate.applicationWillResignActive(_:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalApplicationDidbecomeActive(_:)), addToClass: UIApplication.appDelegateClass!, makeLikeSel: #selector(UIApplicationDelegate.applicationDidBecomeActive(_:)))
        
        
        /* iOS 10.0: UNUserNotificationCenterDelegate instead of UIApplicationDelegate for methods handling opening app from notification
            Make sure AppDelegate does not conform to this protocol */
        if #available(iOS 10.0, *) {
            let oneSignalClass : AnyClass! = NSClassFromString("OneSignal")!
            if (oneSignalClass as? NSObjectProtocol)?.responds(to: NSSelectorFromString("conformsToUNProtocol")) == true {
                let _ = (oneSignalClass as? NSObjectProtocol)?.perform(NSSelectorFromString("conformsToUNProtocol"))
            }
        }
        
        self.setOneSignalDelegate(delegate)
    }
    
}
