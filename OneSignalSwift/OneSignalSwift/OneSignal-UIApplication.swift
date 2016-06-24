//
//  OneSignal-UIApplication.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 Joseph Kalash. All rights reserved.
//

import Foundation

extension UIApplication {
    
    func oneSignalDidRegisterForRemoteNotifications(app : UIApplication, deviceToken inDeviceToken : NSData) {
        if OneSignal.defaultClient != nil {
            OneSignal.defaultClient.didRegisterForRemoteNotifications(app, deviceToken: inDeviceToken)
        }
        if self.respondsToSelector(#selector(UIApplication.oneSignalDidRegisterForRemoteNotifications(_:deviceToken:))) {
            self.oneSignalDidRegisterForRemoteNotifications(app, deviceToken: inDeviceToken)
        }
    }
    
    func oneSignalDidFailRegisterForRemoteNotifications(app : UIApplication, error : NSError) {
        OneSignal.onesignal_Log(OneSignal.ONE_S_LOG_LEVEL.ONE_S_LL_ERROR, message: "Error registering for Apple push notifications. Error: \(error)")
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalDidFailRegisterForRemoteNotifications(_:error:))) {
            self.oneSignalDidFailRegisterForRemoteNotifications(app, error: error)
        }
    }
    
    @available(iOS 8.0, *)
    func oneSignalDidRegisterUserNotifications(application : UIApplication, settings notificationSettings : UIUserNotificationSettings) {
        
        if OneSignal.defaultClient != nil {
            OneSignal.defaultClient.updateNotificationTypes(Int(notificationSettings.types.rawValue))
        }
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalDidRegisterUserNotifications(_:settings:))) {
            self.oneSignalDidRegisterUserNotifications(application, settings: notificationSettings)
        }
    }
    
    
    //MARK : iOS 6 Only
    func oneSignalReceivedRemoteNotification(application : UIApplication, userInfo : NSDictionary) {
        
        if OneSignal.defaultClient != nil {
            OneSignal.defaultClient.notificationOpened(userInfo, isActive: application.applicationState == .Active)
        }
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalReceivedRemoteNotification(_:userInfo:))) {
            self.oneSignalReceivedRemoteNotification(application, userInfo: userInfo)
        }
    }
    
    func oneSignalRemoteSilentNotification(application : UIApplication, userInfo : NSDictionary, fetchCompletionHandler completionHandler : (UIBackgroundFetchResult) -> Void) {
        if OneSignal.defaultClient != nil {
            OneSignal.defaultClient.remoteSilentNotification(application, userInfo: userInfo)
        }
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalRemoteSilentNotification(_:userInfo:fetchCompletionHandler:))) {
            self.oneSignalRemoteSilentNotification(application, userInfo: userInfo, fetchCompletionHandler: completionHandler)
        }
        else {
            completionHandler(UIBackgroundFetchResult.NewData)
        }
    }
    
    func oneSignalLocalNotificationOpened(application : UIApplication, handleActionWithIdentifier identifier : NSString, forLocalNotification notification : UILocalNotification, completionHandler : ()-> Void) {
        if OneSignal.defaultClient != nil {
            OneSignal.defaultClient.processLocalActionBasedNotification(notification, identifier: identifier)
        }
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalLocalNotificationOpened(_:handleActionWithIdentifier:forLocalNotification:completionHandler:))) {
            self.oneSignalLocalNotificationOpened(application, handleActionWithIdentifier: identifier, forLocalNotification: notification, completionHandler: completionHandler)
        }
        else {
            completionHandler()
        }
    }
    
    func oneSignalLocalNotificationOpened(application : UIApplication, notification : UILocalNotification) {
        if OneSignal.defaultClient != nil {
            OneSignal.defaultClient.processLocalActionBasedNotification(notification, identifier: "__DEFAULT__")
        }
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalLocalNotificationOpened(_:notification:))) {
            self.oneSignalLocalNotificationOpened(application, notification: notification)
        }
    }
    
    func oneSignalApplicationWillResignActive(application : UIApplication) {
        if OneSignal.defaultClient != nil {
            OneSignal.defaultClient.onFocus("suspend")
        }
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalApplicationWillResignActive(_:))) {
            self.oneSignalApplicationWillResignActive(application)
        }
    }
    
    func oneSignalApplicationDidbecomeActive(application : UIApplication) {
        if OneSignal.defaultClient != nil {
            OneSignal.defaultClient.onFocus("resume")
        }
        
        if self.respondsToSelector(#selector(UIApplication.oneSignalApplicationDidbecomeActive(_:))) {
            self.oneSignalApplicationDidbecomeActive(application)
        }
    }
    
    @nonobjc static var delegateClass : AnyClass? = nil
    
    public override class func initialize() {
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
    
    func setOneSignalDelegate(delegate : UIApplicationDelegate) {
        
        if UIApplication.delegateClass != nil {
            self.setOneSignalDelegate(delegate)
            return
        }
        
        UIApplication.delegateClass = OneSignal.getClassWithProtocolInHierarchy((delegate as AnyObject).classForCoder, protocolToFind: UIApplicationDelegate.self)
        
        if UIApplication.delegateClass == nil { return }
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalRemoteSilentNotification(_:userInfo:fetchCompletionHandler:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)))
        
        if #available(iOS 8.0, *) {
            OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalLocalNotificationOpened(_:handleActionWithIdentifier:forLocalNotification:completionHandler:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:handleActionWithIdentifier:forLocalNotification:completionHandler:)))
        }
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalDidFailRegisterForRemoteNotifications(_:error:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)))
        
       if #available(iOS 8.0, *) {
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalDidRegisterUserNotifications(_:settings:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didRegisterUserNotificationSettings:)))
        }
        
        if NSClassFromString("CoronaAppDelegate") != nil {
            self.setOneSignalDelegate(delegate)
            return
        }
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalReceivedRemoteNotification(_:userInfo:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalDidRegisterForRemoteNotifications(_:deviceToken:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalLocalNotificationOpened(_:notification:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.application(_:didReceiveLocalNotification:)))
        
        OneSignal.injectSelector(self.classForCoder, newSel: #selector(UIApplication.oneSignalApplicationDidbecomeActive(_:)), addToClass: UIApplication.delegateClass!, makeLikeSel: #selector(UIApplicationDelegate.applicationDidBecomeActive(_:)))
        
        self.setOneSignalDelegate(delegate)
    }
    
}
