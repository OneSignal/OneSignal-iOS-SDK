//
//  OneSignal-UNUserNotificationCenterDelegate.swift
//  OneSignal
//
//  Created by Joseph Kalash on 6/30/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

@available(iOS 10.0, *)
@objc public protocol OneSignalNotificationCenterDelegate {
    optional func userNotificationCenter(center: UNUserNotificationCenter, willPresentNotification notification: UNNotification, withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void);
    optional func userNotificationCenter(center: UNUserNotificationCenter, didReceiveNotificationResponse response: UNNotificationResponse, withCompletionHandler completionHandler: () -> Void);
}

@available(iOS 10.0, *)
extension OneSignal : UNUserNotificationCenterDelegate {
    
    // The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from applicationDidFinishLaunching:.
    public func userNotificationCenter(center: UNUserNotificationCenter, didReceiveNotificationResponse response: UNNotificationResponse, withCompletionHandler completionHandler: () -> Void) {
        
        let usrInfo = response.notification.request.content.userInfo
        
        if usrInfo.count == 0 {
            OneSignal.tunnelToDelegate(center, response: response, handler: completionHandler)
            return
        }
        
        let userInfo = NSMutableDictionary()
        let customDict = NSMutableDictionary()
        let additionalData = NSMutableDictionary()
        let optionsDict = NSMutableArray()
        
        if let os_data = usrInfo["os_data"],
            buttonsDict = os_data["buttons"] as? NSMutableDictionary {
            userInfo.addEntriesFromDictionary(usrInfo)
            if let o = buttonsDict["o"] as? [[NSObject : AnyObject]] { optionsDict.addObjectsFromArray(o) }
        }
        
        else if let custom = usrInfo["custom"] as? [NSObject : AnyObject] {
            userInfo.addEntriesFromDictionary(usrInfo)
            customDict.addEntriesFromDictionary(custom)
            if let a = customDict["a"] as? [NSObject : AnyObject] {
                additionalData.addEntriesFromDictionary(a)
            }
            if let o = userInfo["o"] as? [[String : String]] {
                optionsDict.addObjectsFromArray(o)
            }
        }
            
        else {
            OneSignal.tunnelToDelegate(center, response: response, handler: completionHandler)
            return
        }
            
        let buttonArray = NSMutableArray()
        for button in optionsDict {
            
            let buttonToAppend : [NSObject : AnyObject] = [
                "text" : button["n"] != nil ? button["n"]!! : "",
                "id" : button["i"] != nil ? button["i"]!! : button["n"]!!
            ]
            
            buttonArray.addObject(buttonToAppend)
        }
        
        additionalData["actionSelected"] = response.actionIdentifier
        additionalData["actionButtons"] = buttonArray

        
        if let os_data = usrInfo["os_data"] as? [String : AnyObject] {
            for (key, val) in os_data { userInfo.setObject(val, forKey: key) }
            if let os_d = userInfo["os_data"],
                buttons = os_d["buttons"] as? NSMutableDictionary,
                m = buttons["m"] {
                let alert = m
                userInfo["aps"] = ["alert" : alert]
            }
        }
        else {
            customDict["a"] = additionalData
            userInfo["custom"] = customDict
            userInfo["aps"] = ["alert":userInfo["m"]!]
        }
        
        OneSignal.notificationOpened(userInfo, isActive: UIApplication.sharedApplication().applicationState == .Active)
        
        OneSignal.tunnelToDelegate(center, response: response, handler: completionHandler)
    }
    
    static func tunnelToDelegate(center : UNUserNotificationCenter, response: UNNotificationResponse, handler: ()-> Void) {
        /* Tunnel the delegate call */
        if let delegate = OneSignal.notificationCenterDelegate {
            delegate.userNotificationCenter?(center, didReceiveNotificationResponse: response, withCompletionHandler: handler)
        }
        else {
            //Call the completion handler ourselves
            handler()
        }
    }
    
    // The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.
    
    public func userNotificationCenter(center: UNUserNotificationCenter, willPresentNotification notification: UNNotification, withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void) {
        
        
        /* Nothing interesting to do here, proxy to user only */
        if let delegate = OneSignal.notificationCenterDelegate {
            delegate.userNotificationCenter?(center, willPresentNotification: notification, withCompletionHandler: completionHandler)
        }
        
        else {
            //Call the completion handler ourselves
            completionHandler(UNNotificationPresentationOptions(rawValue: 7))
        }
    }
    
    static func registerAsUNNotificationCenterDelegate() {
        UNUserNotificationCenter.currentNotificationCenter().delegate = OneSignal.oneSignalObject
    }
    
}
