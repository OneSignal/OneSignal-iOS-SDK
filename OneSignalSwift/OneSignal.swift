//
//  OneSignal.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

let ONESIGNAL_VERSION = "020000"
let DEFAULT_PUSH_HOST = "https://onesignal.com/api/v1/"

public typealias OneSignalResultSuccessBlock = (NSDictionary) -> Void
public typealias OneSignalFailureBlock = (NSError) -> Void
public typealias OneSignalIdsAvailableBlock = (NSString, NSString?) -> Void
public typealias OneSignalHandleNotificationBlock = (NSString, NSDictionary, Bool) -> Void

enum NotificationType : Int {
    case badge = 1
    case douns = 2
    case alert = 4
    case all = 7
}

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
    
    public enum ONE_S_LOG_LEVEL : Int {
        case one_S_LL_NONE = 0
        case one_S_LL_FATAL = 1
        case one_S_LL_ERROR = 2
        case one_S_LL_WARN = 3
        case one_S_LL_INFO = 4
        case one_S_LL_DEBUG = 5
        case one_S_LL_VERBOSE = 6
    }
    
    static var SDKType = "native"
    static var nsLogLevel : ONE_S_LOG_LEVEL = .one_S_LL_WARN
    static var visualLogLevel : ONE_S_LOG_LEVEL = .one_S_LL_NONE
    
    static var app_id : String!
    static var deviceModel : NSString!
    static var systemVersion : NSString!
    static var lastMessageReceived : NSDictionary!
    static var disableBadgeClearing = false
    static var tagsToSend : NSMutableDictionary!
    static var emailToSet : NSString!
    static var deviceToken : NSString? = nil
    static var tokenUpdateSuccessBlock : OneSignalResultSuccessBlock!
    static var tokenUpdateFailureBlock : OneSignalFailureBlock!
    static var userId : NSString? = nil
    static var httpClient : OneSignalHTTPClient!
    static var idsAvailableBlockWhenReady : OneSignalIdsAvailableBlock!
    static var handleNotification : OneSignalHandleNotificationBlock!
    static var focusBackgroundTask : UIBackgroundTaskIdentifier!
    static var trackIAPPurchase : OneSignalTrackIAP!
    static var registeredWithApple = false
    static var oneSignalReg = false
    static var waitingForOneSReg = false
    static var lastTrackedTime : NSNumber!
    static var unSentActiveTime : NSNumber!
    static var timeToPingWith : NSNumber!
    static var notificationTypes = -1
    static var subscriptionSet = true
    static var location_event_fired = false
    
    /* Starting v2.0, canot create an instance of this class. Pure static */
    private override init() {}
    
    public static func initWithLaunchOptions(_ launchOptions : NSDictionary?, appId : NSString, handleNotification callback : (OneSignalHandleNotificationBlock?) = nil, autoRegister : Bool = true) {
        
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 {return}
        
        if UUID(uuidString: appId as String) == nil {
            OneSignal.onesignal_Log(.one_S_LL_FATAL, message: "OneSignal AppId format is invalid.\nExample: 'b2f7f966-d8cc-11eg-bed1-df8f05be55ba'\n")
            return
        }
        
        if appId.isEqual(to: "b2f7f966-d8cc-11eg-bed1-df8f05be55ba") || appId.isEqual(to: "5eb5a37e-b458-11e3-ac11-000c2940e62c") {
            OneSignal.onesignal_Log(.one_S_LL_WARN, message: "OneSignal Example AppID detected, please update to your app's id found on OneSignal.com\n")
        }
        
        OneSignalLocation.getLocation(self, prompt: false)
        
        handleNotification = callback
        unSentActiveTime = NSNumber(value: -1)
        lastTrackedTime = NSNumber(value: Date().timeIntervalSince1970)
        self.app_id = appId as String
        
        if let disable = Bundle.main().objectForInfoDictionaryKey("OneSignal_disable_badge_clearing") as? Bool {
            disableBadgeClearing = disable
        }
        
        let url = URL(string: DEFAULT_PUSH_HOST)!
        httpClient = OneSignalHTTPClient(baseURL: url)
        
        var systemInfo = utsname()
        uname(&systemInfo)
        var v = systemInfo.machine
        let _ = withUnsafePointer(&v){
            self.deviceModel = String(cString: UnsafePointer($0))
        }
        
        systemVersion = UIDevice.current().systemVersion

        
        let defaults = UserDefaults.standard()
        
        if app_id == nil {
            app_id = defaults.string(forKey: "GT_APP_ID")
        }
        else if app_id != defaults.string(forKey: "GT_APP_ID") {
            defaults.set(app_id, forKey: "GT_APP_ID")
            defaults.set(nil, forKey: "GT_PLAYER_ID")
            defaults.synchronize()
        }
        
        userId = defaults.string(forKey: "GT_PLAYER_ID")
        deviceToken = defaults.string(forKey: "GT_DEVICE_TOKEN")
        if isCapableOfGettingNotificationTypes() {
            registeredWithApple = UIApplication.shared().currentUserNotificationSettings() != nil
        }
        notificationTypes = getNotificationTypes()
        
        subscriptionSet = defaults.object(forKey: "ONESIGNAL_SUBSCRIPTION") == nil
        
        // Register this device with Apple's APNS server.
        if autoRegister || registeredWithApple {
            self.registerForPushNotifications()
        }
            
            
        else { UIApplication.shared().registerForRemoteNotifications() }
        
        
        if userId != nil {
            registerUser()
        }
        else {
            self.perform(#selector(OneSignal.registerUser), with: nil, afterDelay: 30.0)
        }
            
        if let userInfo = launchOptions?.object(forKey: UIApplicationLaunchOptionsRemoteNotificationKey) as? NSDictionary {
            if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_7_0 {
                self.notificationOpened(userInfo, isActive : false)
            }
        }
        
        let _ = clearBadgeCount(false)
        
        if OneSignalTrackIAP.canTrack() {
            trackIAPPurchase = OneSignalTrackIAP()
        }
    }

    
}
