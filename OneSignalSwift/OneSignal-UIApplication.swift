//
//  OneSignal-UIApplication.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension UIApplication {
    
    static func oneSignalDidRegisterForRemoteNotifications(app : UIApplication, deviceToken inDeviceToken : NSData) {
        
        OneSignal.didRegisterForRemoteNotifications(app, deviceToken: inDeviceToken)

        if self.respondsToSelector(#selector(UIApplication.oneSignalDidRegisterForRemoteNotifications(_:deviceToken:))) {
            self.oneSignalDidRegisterForRemoteNotifications(app, deviceToken: inDeviceToken)
        }
    }
    
    static func oneSignalDidFailRegisterForRemoteNotifications(app : UIApplication, error : NSError) {
        OneSignal.onesignal_Log(.ONE_S_LL_ERROR, message: "Error registering for Apple push notifications. Error: \(error)")
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalDidFailRegisterForRemoteNotifications(_:error:))) {
            self.oneSignalDidFailRegisterForRemoteNotifications(app, error: error)
        }
    }
    
    @available(iOS 8.0, *)
    static func oneSignalDidRegisterUserNotifications(application : UIApplication, settings notificationSettings : UIUserNotificationSettings) {
    
        OneSignal.updateNotificationTypes(Int(notificationSettings.types.rawValue))
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalDidRegisterUserNotifications(_:settings:))) {
            self.oneSignalDidRegisterUserNotifications(application, settings: notificationSettings)
        }
    }
    
    static func oneSignalRemoteSilentNotification(application : UIApplication, userInfo : NSDictionary, fetchCompletionHandler completionHandler : (UIBackgroundFetchResult) -> Void) {
        
        OneSignal.remoteSilentNotification(application, userInfo: userInfo)
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalRemoteSilentNotification(_:userInfo:fetchCompletionHandler:))) {
            self.oneSignalRemoteSilentNotification(application, userInfo: userInfo, fetchCompletionHandler: completionHandler)
        }
        else {
            completionHandler(UIBackgroundFetchResult.NewData)
        }
    }
    
    static func oneSignalLocalNotificationOpened(application : UIApplication, handleActionWithIdentifier identifier : NSString, forLocalNotification notification : UILocalNotification, completionHandler : ()-> Void) {
        
       
        OneSignal.processLocalActionBasedNotification(notification, identifier: identifier)
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalLocalNotificationOpened(_:handleActionWithIdentifier:forLocalNotification:completionHandler:))) {
            self.oneSignalLocalNotificationOpened(application, handleActionWithIdentifier: identifier, forLocalNotification: notification, completionHandler: completionHandler)
        }
        else {
            completionHandler()
        }
    }
    
    static func oneSignalLocalNotificationOpened(application : UIApplication, notification : UILocalNotification) {
        
        OneSignal.processLocalActionBasedNotification(notification, identifier: "__DEFAULT__")
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalLocalNotificationOpened(_:notification:))) {
            self.oneSignalLocalNotificationOpened(application, notification: notification)
        }
    }
    
    static func oneSignalApplicationWillResignActive(application : UIApplication) {
        
        OneSignal.onFocus("suspend")
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalApplicationWillResignActive(_:))) {
            self.oneSignalApplicationWillResignActive(application)
        }
    }
    
    static func oneSignalApplicationDidbecomeActive(application : UIApplication) {
        
        OneSignal.onFocus("resume")
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalApplicationDidbecomeActive(_:))) {
            self.oneSignalApplicationDidbecomeActive(application)
        }
    }
    
    @nonobjc static var delegateClass : AnyClass? = nil
    
    public override static  func initialize() {
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return }
        struct Static { static var token: dispatch_once_t = 0 }
        if self !== UIApplication.self { return } /* Make sure this isn't a subclass */
        
        dispatch_once(&Static.token) {
    
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
        
    }
    
    static func setOneSignalDelegate(delegate : UIApplicationDelegate) {
        
        if UIApplication.delegateClass != nil {
            self.setOneSignalDelegate(delegate)
            return
        }
        
        UIApplication.delegateClass = OneSignal.getClassWithProtocolInHierarchy((delegate as AnyObject).classForCoder, protocolToFind: UIApplicationDelegate.self)
        
        if UIApplication.delegateClass == nil { return }
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalRemoteSilentNotification(_:userInfo:fetchCompletionHandler:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalLocalNotificationOpened(_:handleActionWithIdentifier:forLocalNotification:completionHandler:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:handleActionWithIdentifier:forLocalNotification:completionHandler:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalDidFailRegisterForRemoteNotifications(_:error:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalDidRegisterUserNotifications(_:settings:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didRegisterUserNotificationSettings:)))
        
        if NSClassFromString("CoronaAppDelegate") != nil {
            self.setOneSignalDelegate(delegate)
            return
        }
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalDidRegisterForRemoteNotifications(_:deviceToken:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalLocalNotificationOpened(_:notification:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceiveLocalNotification:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalApplicationWillResignActive(_:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.applicationWillResignActive(_:)))
        
        OneSignal.injectSelector(self.classForCoder(), newSel: #selector(UIApplication.oneSignalApplicationDidbecomeActive(_:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.applicationDidBecomeActive(_:)))
        
        self.setOneSignalDelegate(delegate)
    }
    
}
