//
//  OneSignal.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

/**
 `OneSignal` provides a high level interface to interact with OneSignal's push service.
 `OneSignal` can only be globally accessed with shared configuration settings. You cannot create an instance of this class.

 @objc
 Include `#import "OneSignal/OneSignal-Swift.h"` in your application files to access OneSignal's methods.
 
 @Swift
 Include `#import "Import OneSignal` in your application files to access OneSignal's methods.
 
 ### Setting up the SDK ###
 Follow the documentation from http://documentation.gamethrive.com/v1.0/docs/installing-the-gamethrive-ios-sdk to setup with your game.
 */

@objc(OneSignal) public class OneSignal : NSObject {
    
    /* Object that conforms to UNUserNOtificationCenterDelegate */
    @available(iOS 10.0, *)
    public static var notificationCenterDelegate : OneSignalNotificationCenterDelegate?
    static var oneSignalObject = OneSignal()
    
    static var app_id : String!
    static var trackIAPPurchase : OneSignalTrackIAP!
    static var registeredWithApple = false
    static var focusBackgroundTask : UIBackgroundTaskIdentifier!
    static var lastTrackedTime : NSNumber!
    static var unSentActiveTime : NSNumber!
    static var timeToPingWith : NSNumber!
    static var tagsToSend : NSMutableDictionary!
    static var emailToSet : NSString!
    static var httpClient : OneSignalHTTPClient!
    static var lastLocation : os_last_location!
    static var location_event_fired = false
    static var SDKType = "native"
    static var lastMessageReceived : NSDictionary!
    static var subscriptionSet = true
    static var userId : NSString? = nil
    static var deviceModel : NSString!
    static var systemVersion : NSString!
    static var deviceToken : NSString? = nil
    static var disableBadgeClearing = false
    static var tokenUpdateSuccessBlock : OneSignalResultSuccessBlock!
    static var tokenUpdateFailureBlock : OneSignalFailureBlock!
    static var idsAvailableBlockWhenReady : OneSignalIdsAvailableBlock!
    static var handleNotification : OneSignalHandleNotificationBlock!
    static var oneSignalReg = false
    static var waitingForOneSReg = false
    static var notificationTypes = -1
    static var nsLogLevel : ONE_S_LOG_LEVEL = .WARN
    static var visualLogLevel : ONE_S_LOG_LEVEL = .NONE
    
    /* Starting v2.0, canot create an instance of this class. Pure static */
    private override init() {}
    
    public static func initWithLaunchOptions(launchOptions : NSDictionary?, appId : NSString, handleNotification callback : (OneSignalHandleNotificationBlock?) = nil, autoRegister : Bool = true) {
        
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 {return}
        
        if NSUUID(UUIDString: appId as String) == nil {
            OneSignal.onesignal_Log(.FATAL, message: "OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11eg-bed1-df8f05be55ba'\n")
            return
        }
        
        if appId.isEqualToString("b2f7f966-d8cc-11eg-bed1-df8f05be55ba") || appId.isEqualToString("5eb5a37e-b458-11e3-ac11-000c2940e62c") {
            OneSignal.onesignal_Log(.WARN, message: "OneSignal Example AppID detected, please update to your app's id found on OneSignal.com\n")
        }
        
        OneSignalLocation.getLocation(self, prompt: false)
        
        handleNotification = callback
        unSentActiveTime = NSNumber(int: -1)
        lastTrackedTime = NSNumber(double: NSDate().timeIntervalSince1970)
        self.app_id = appId as String
        
        if let disable = NSBundle.mainBundle().objectForInfoDictionaryKey("OneSignal_disable_badge_clearing") as? Bool {
            disableBadgeClearing = disable
        }
        
        let url = NSURL(string: DEFAULT_PUSH_HOST)!
        httpClient = OneSignalHTTPClient(baseURL: url)
        
        var systemInfo = utsname()
        uname(&systemInfo)
        var v = systemInfo.machine
        let _ = withUnsafePointer(&v){
            self.deviceModel = String.fromCString(UnsafePointer($0))
        }
        
        //!! TEMP : 9.3 until server bug fixed
        systemVersion = "9.3"//UIDevice.currentDevice().systemVersion
        
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
        if isCapableOfGettingNotificationTypes() {
            registeredWithApple = UIApplication.sharedApplication().currentUserNotificationSettings() != nil
        }
        notificationTypes = getNotificationTypes()
        
        subscriptionSet = defaults.objectForKey("ONESIGNAL_SUBSCRIPTION") == nil
        
        // Register this device with Apple's APNS server.
        if autoRegister || registeredWithApple {
            self.registerForPushNotifications()
        }
            
        else if UIApplication.sharedApplication().respondsToSelector(#selector(UIApplication.registerForRemoteNotifications)) {
            UIApplication.sharedApplication().registerForRemoteNotifications()
        }
        
        if userId != nil {
            registerUser()
        }
        else {
            self.performSelector(#selector(OneSignal.registerUser), withObject: nil, afterDelay: 30.0)
        }
            
        if let userInfo = launchOptions?.objectForKey(UIApplicationLaunchOptionsRemoteNotificationKey) as? NSDictionary {
            if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_0 {
                self.notificationOpened(userInfo, isActive : false)
            }
        }
        
        clearBadgeCount(false)
        
        if OneSignalTrackIAP.canTrack() {
            trackIAPPurchase = OneSignalTrackIAP()
        }
        
        /* We are UNUserNotificationCenterDelegate */
        if #available(iOS 10.0, *) {
            OneSignal.registerAsUNNotificationCenterDelegate()
        }
        
        /* Clear cached media attachments (iOS 10+) */
        OneSignal.clearCachedMedia()
    }

    
}
