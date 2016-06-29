//
//  OneSignal-UIApplication.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension UIApplication {
    
    static func oneSignalDidRegisterForRemoteNotifications(_ app : UIApplication, deviceToken inDeviceToken : Data) {
        
        OneSignal.didRegisterForRemoteNotifications(app, deviceToken: inDeviceToken)

        if self.responds(to: #selector(UIApplication.oneSignalDidRegisterForRemoteNotifications(_:deviceToken:))) {
            self.oneSignalDidRegisterForRemoteNotifications(app, deviceToken: inDeviceToken)
        }
    }
    
    static func oneSignalDidFailRegisterForRemoteNotifications(_ app : UIApplication, error : NSError) {
        OneSignal.onesignal_Log(.one_S_LL_ERROR, message: "Error registering for Apple push notifications. Error: \(error)")
        
        if self.responds(to: #selector(UIApplication.oneSignalDidFailRegisterForRemoteNotifications(_:error:))) {
            self.oneSignalDidFailRegisterForRemoteNotifications(app, error: error)
        }
    }
    
    @available(iOS 8.0, *)
    static func oneSignalDidRegisterUserNotifications(_ application : UIApplication, settings notificationSettings : UIUserNotificationSettings) {
    
        OneSignal.updateNotificationTypes(Int(notificationSettings.types.rawValue))
        
        if self.responds(to: #selector(UIApplication.oneSignalDidRegisterUserNotifications(_:settings:))) {
            self.oneSignalDidRegisterUserNotifications(application, settings: notificationSettings)
        }
    }
    
    static func oneSignalRemoteSilentNotification(_ application : UIApplication, userInfo : NSDictionary, fetchCompletionHandler completionHandler : (UIBackgroundFetchResult) -> Void) {
        
        OneSignal.remoteSilentNotification(application, userInfo: userInfo)
        
        if self.responds(to: #selector(UIApplication.oneSignalRemoteSilentNotification(_:userInfo:fetchCompletionHandler:))) {
            self.oneSignalRemoteSilentNotification(application, userInfo: userInfo, fetchCompletionHandler: completionHandler)
        }
        else {
            completionHandler(UIBackgroundFetchResult.newData)
        }
    }
    
    static func oneSignalLocalNotificationOpened(_ application : UIApplication, handleActionWithIdentifier identifier : NSString, forLocalNotification notification : UILocalNotification, completionHandler : ()-> Void) {
        
       
        OneSignal.processLocalActionBasedNotification(notification, identifier: identifier)
        
        if self.responds(to: #selector(UIApplication.oneSignalLocalNotificationOpened(_:handleActionWithIdentifier:forLocalNotification:completionHandler:))) {
            self.oneSignalLocalNotificationOpened(application, handleActionWithIdentifier: identifier, forLocalNotification: notification, completionHandler: completionHandler)
        }
        else {
            completionHandler()
        }
    }
    
    static func oneSignalLocalNotificationOpened(_ application : UIApplication, notification : UILocalNotification) {
        
        OneSignal.processLocalActionBasedNotification(notification, identifier: "__DEFAULT__")
        
        if self.responds(to: #selector(UIApplication.oneSignalLocalNotificationOpened(_:notification:))) {
            self.oneSignalLocalNotificationOpened(application, notification: notification)
        }
    }
    
    static func oneSignalApplicationWillResignActive(_ application : UIApplication) {
        
        OneSignal.onFocus("suspend")
        
        if self.responds(to: #selector(UIApplication.oneSignalApplicationWillResignActive(_:))) {
            self.oneSignalApplicationWillResignActive(application)
        }
    }
    
    static func oneSignalApplicationDidbecomeActive(_ application : UIApplication) {
        
        OneSignal.onFocus("resume")
        
        if self.responds(to: #selector(UIApplication.oneSignalApplicationDidbecomeActive(_:))) {
            self.oneSignalApplicationDidbecomeActive(application)
        }
    }
    
    @nonobjc static var delegateClass : AnyClass? = nil
    
    public override static  func initialize() {
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return }
 
        if self !== UIApplication.self { return } /* Make sure this isn't a subclass */
        
    
        //Exchange UIApplicaions's setDelegate with OneSignal's
        let originalSelector = NSSelectorFromString("setDelegate:")
        let swizzledSelector = #selector(UIApplication.setOneSignalDelegate(_:))
        
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        let originalMethod = class_getInstanceMethod(self,originalSelector)
        let didAddMethod = class_addMethod(self, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        }
        else { method_exchangeImplementations(originalMethod, swizzledMethod) }
    }
    
    static func setOneSignalDelegate(_ delegate : UIApplicationDelegate) {
        
        if UIApplication.delegateClass != nil {
            self.setOneSignalDelegate(delegate)
            return
        }
        
        UIApplication.delegateClass = OneSignal.getClassWithProtocolInHierarchy((delegate as AnyObject).classForCoder, protocolToFind: UIApplicationDelegate.self)
        
        if UIApplication.delegateClass == nil { return }
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalRemoteSilentNotification(_:userInfo:fetchCompletionHandler:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalLocalNotificationOpened(_:handleActionWithIdentifier:forLocalNotification:completionHandler:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:handleActionWithIdentifier:for:completionHandler:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalDidFailRegisterForRemoteNotifications(_:error:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalDidRegisterUserNotifications(_:settings:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didRegister:)))
        
        if NSClassFromString("CoronaAppDelegate") != nil {
            self.setOneSignalDelegate(delegate)
            return
        }
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalDidRegisterForRemoteNotifications(_:deviceToken:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalLocalNotificationOpened(_:notification:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceive:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalApplicationWillResignActive(_:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.applicationWillResignActive(_:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalApplicationDidbecomeActive(_:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.applicationDidBecomeActive(_:)))
        
        self.setOneSignalDelegate(delegate)
    }
    
}
