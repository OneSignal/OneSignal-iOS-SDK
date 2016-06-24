//
//  OneSignal-Initialize.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

///--------------------
/// @name Initialize
///--------------------

/**
 Initialize OneSignal. Sends push token to OneSignal so you can later send notifications.
 
 */
extension OneSignal {
   
    convenience init(launchOptions: NSDictionary) {
        self.init(launchOptions: launchOptions, appId: nil, handleNotifications: nil, autoRegister: true)
    }
    
    convenience init(launchOptions : NSDictionary, autoRegister : Bool) {
        self.init(launchOptions: launchOptions, appId: nil, handleNotifications: nil, autoRegister: autoRegister)
    }
    
    convenience init(launchOptions : NSDictionary, appId : NSString?) {
        self.init(launchOptions: launchOptions, appId: appId, handleNotifications: nil, autoRegister: true)
    }
    
    convenience init(launchOptions : NSDictionary, handleNotifications callback : OneSignalHandleNotificationBlock?) {
        self.init(launchOptions: launchOptions, appId: nil, handleNotifications: callback, autoRegister: true)
    }
    
    convenience init(launchOptions : NSDictionary, appId : NSString?, handleNotifications callback : OneSignalHandleNotificationBlock?) {
        self.init(launchOptions: launchOptions, appId: appId, handleNotifications: callback, autoRegister: true)
    }
    
    convenience init(launchOptions : NSDictionary, handleNotifications callback : OneSignalHandleNotificationBlock?, autoRegister : Bool) {
        self.init(launchOptions: launchOptions, appId: nil, handleNotifications: callback, autoRegister: autoRegister)
    }
    
    
}
