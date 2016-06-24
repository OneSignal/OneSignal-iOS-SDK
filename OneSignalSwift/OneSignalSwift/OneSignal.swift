//
//  OneSignal.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

typealias OneSignalResultSuccessBlock = (NSDictionary) -> Void
typealias OneSignalFailureBlock = (NSError) -> Void
typealias OneSignalIdsAvailableBlock = (NSString, NSString) -> Void
typealias OneSignalHandleNotificationBlock = (NSString, NSDictionary, Bool) -> Void


/**
 
 `OneSignal` provides a high level interface to interact with OneSignal's push service.
 
 `OneSignal` exposes a defaultClient for applications which use a globally available client to share configuration settings.

 @objc
 Include `#import "OneSignal/OneSignal.h"` in your application files to access OneSignal's methods.
 
 @Swift
 Include `#import "Import OneSignal` in your application files to access OneSignal's methods.
 
 ### Setting up the SDK ###
 Follow the documentation from http://documentation.gamethrive.com/v1.0/docs/installing-the-gamethrive-ios-sdk to setup with your game.
 */

class OneSignal : NSObject {
    
    static var defaultClient : OneSignal!zdvxfv
    
    var app_id : String!
    var deviceModel : NSString!
    var systemVersion : NSString!
    var lastMessageReceived : NSDictionary!
    var disableBadgeClearing = false
    var tagsToSend : NSMutableDictionary!
    var emailToSet : NSString!
    var deviceToken : NSString!
    var tokenUpdateSuccessBlock : OneSignalResultSuccessBlock!
    var tokenUpdateFailureBlock : OneSignalFailureBlock!
    var userId : NSString!
    var httpClient : OneSignalHTTPClient!
    var idsAvailableBlockWhenReady : OneSignalIdsAvailableBlock!
    var handleNotification : OneSignalHandleNotificationBlock!
    var focusBackgroundTask : UIBackgroundTaskIdentifier!
    var trackIAPPurchase : OneSignalTrackIAP!
    var registeredWithApple = false
    var oneSignalReg = false
    var waitingForOneSReg = false
    var lastTrackedTime : NSNumber!
    var unSentActiveTime : NSNumber!
    var timeToPingWith : NSNumber!
    var notificationTypes = -1
    var subscriptionSet = true
    static var SDKType = "native"
    
    init(launchOptions : NSDictionary, appId : NSString?, handleNotifications callback : OneSignalHandleNotificationBlock?, autoRegister : Bool) {
        
        super.init()
        
        if appId == nil || NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 {return}
        
        if NSUUID(UUIDString: appId! as String) == nil {
            onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_FATAL, message: "OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11eg-bed1-df8f05be55ba'\n")
            return
        }
        
        if appId!.isEqualToString("b2f7f966-d8cc-11eg-bed1-df8f05be55ba") || appId!.isEqualToString("5eb5a37e-b458-11e3-ac11-000c2940e62c") {
            onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_WARN, message: "OneSignal Example AppID detected, please update to your app's id found on OneSignal.com\n")
        }
        
        OneSignalLocation.getLocation(self, prompt: false)
        
        handleNotification = callback
        unSentActiveTime = NSNumber(int: -1)
        lastTrackedTime = NSNumber(double: NSDate().timeIntervalSince1970)
        if appId != nil {self.app_id = appId! as String}
        else {
            app_id = NSBundle.mainBundle().objectForInfoDictionaryKey("OneSignal_APPID") as? String
            if app_id == nil { app_id = NSBundle.mainBundle().objectForInfoDictionaryKey("GameThrive_APPID") as? String}
        }
        if let disable = NSBundle.mainBundle().objectForInfoDictionaryKey("OneSignal_disable_badge_clearing") as? Bool {
            disableBadgeClearing = disable
        }
        
        let url = NSURL(string: DEFAULT_PUSH_HOST)!
        httpClient = OneSignalHTTPClient(baseURL: url)
        
        deviceModel = UIDevice.currentDevice().modelName
        systemVersion = UIDevice.currentDevice().systemVersion
        if OneSignal.defaultClient == nil { OneSignal.defaultClient = self}
        
        let defaults = NSUserDefaults.standardUserDefaults()
        
        if app_id == nil {
            app_id = defaults.stringForKey("GT_APP_ID")
        }
        else if app_id != defaults.stringForKey("GT_APP_ID") {
            defaults.setObject(app_id, forKey: "GT_APP_ID")
            defaults.setObject(nil, forKey: "GT_PLAYER_ID")
            defaults.synchronize()
        }
        
        userId = defaults.stringForKey("GT_PLAYER_ID")
        deviceToken = defaults.stringForKey("GT_DEVICE_TOKEN")
         if #available(iOS 8.0, *) {
            if isCapableOfGettingNotificationTypes() {
                registeredWithApple = UIApplication.sharedApplication().currentUserNotificationSettings() != nil
            }
            notificationTypes = getNotificationTypes()
         }
         else {
            registeredWithApple = deviceToken != nil || defaults.boolForKey("GT_REGISTERED_WITH_APPLE")
        }
        
        subscriptionSet = defaults.objectForKey("ONESIGNAL_SUBSCRIPTION") == nil
        
        // Register this device with Apple's APNS server.
        if autoRegister || registeredWithApple {
            self.registerForPushNotifications()
        }
            
        else if #available(iOS 8.0, *) {
            if UIApplication.sharedApplication().respondsToSelector(#selector(UIApplication.registerForRemoteNotifications)) {
                UIApplication.sharedApplication().registerForRemoteNotifications()
            }
        }
        
        if userId != nil {
            registerUser()
        }
        else {
            self.performSelector(#selector(OneSignal.registerUser), withObject: nil, afterDelay: 30.0)
        }
            
        if let userInfo = launchOptions.objectForKey(UIApplicationLaunchOptionsRemoteNotificationKey) as? NSDictionary {
            if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_0 {
                self.notificationOpened(userInfo, isActive : false)
            }
        }
        
        clearBadgeCount(false)
        
        if OneSignalTrackIAP.canTrack() {
            trackIAPPurchase = OneSignalTrackIAP()
        }
    }

    
}
