//
//  OneSignal-Notifications.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/24/16.
//  Copyright © 2016 Joseph Kalash. All rights reserved.
//

import Foundation


extension OneSignal {
    
    func getUsableDeviceToken() -> NSString? {
        if notificationTypes > 0 { return deviceToken}
        return nil
    }
    
    func idsAvailable(idsAvailableBlock : OneSignalIdsAvailableBlock) {
        if let usableToken = getUsableDeviceToken() where userId != nil {
            idsAvailableBlock(userId, usableToken)
        }
        else {
            idsAvailableBlockWhenReady = idsAvailableBlock
        }
    }
    
    @available(iOS 8.0, *)
    func isCapableOfGettingNotificationTypes() -> Bool {
        return UIApplication.sharedApplication().respondsToSelector(#selector(UIApplication.currentUserNotificationSettings))
    }
    
    @available(iOS 8.0, *)
    func  getNotificationTypes() -> Int {
        if subscriptionSet == false { return -2 }
        
        if self.deviceToken != nil {
            if isCapableOfGettingNotificationTypes() {
                if let notifTypes = UIApplication.sharedApplication().currentUserNotificationSettings()?.types {
                    return Int(notifTypes.rawValue)
                }
                
                return -1
            }
            else { return NotificationType.All.rawValue}
        }
        
        return -1
    }
    
    func clearBadgeCount(fromNotifOpened : Bool) -> Bool {
        if disableBadgeClearing || notificationTypes == -1 || (notificationTypes & NotificationType.Badge.rawValue) == 0 { return false}
        
        let wasBadgeSet = UIApplication.sharedApplication().applicationIconBadgeNumber > 0
        
        if  ( !(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) && fromNotifOpened ) || wasBadgeSet {
            
            // Clear bages and nofiications from this app.
            // Setting to 1 then 0 was needed to clear the notifications on iOS 6 & 7. (Otherwise you can click the notification multiple times.)
            // iOS 8+ auto dismisses the notificaiton you tap on so only clear the badge (and notifications [side-effect]) if it was set.
            UIApplication.sharedApplication().applicationIconBadgeNumber = 1
            UIApplication.sharedApplication().applicationIconBadgeNumber = 0
        }
        
        return wasBadgeSet
    }
    
    func registerForPushNotifications() {
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        // iOS 8+
        if #available(iOS 8.0, *) {
            let existingCategories = UIApplication.sharedApplication().currentUserNotificationSettings()?.categories
            let notificationSettings = UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: existingCategories)
            UIApplication.sharedApplication().registerUserNotificationSettings(notificationSettings)
            UIApplication.sharedApplication().registerForRemoteNotifications()
        }
        else {
            UIApplication.sharedApplication().registerForRemoteNotificationTypes([.Badge, .Sound, .Alert])
            if !registeredWithApple {
                NSUserDefaults.standardUserDefaults().setObject(NSNumber(bool: true), forKey: "GT_REGISTERED_WITH_APPLE")
                NSUserDefaults.standardUserDefaults().synchronize()
            }
        }
    }
    
    func registerDeviceToken(inDeviceToken : NSString, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock: OneSignalFailureBlock?) {
        self.updateDeviceToken(inDeviceToken, onSuccess: successBlock, onFailure: failureBlock)
        NSUserDefaults.standardUserDefaults().setObject(deviceToken, forKey: "GT_DEVICE_TOKEN")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func updateDeviceToken(deviceToken : NSString, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock: OneSignalFailureBlock?) {
        
        if userId == nil {
            self.deviceToken = deviceToken
            tokenUpdateSuccessBlock = successBlock
            tokenUpdateFailureBlock = failureBlock
            
            // iOS 8 - We get a token right away but give the user 30 sec to responsed to the system prompt.
            // Also check mNotificationTypes so there is no waiting if user has already answered the system prompt.
            // The goal is to only have 1 server call.
            if notificationTypes == -1 {
                if #available(iOS 8, *) {
                    NSObject.cancelPreviousPerformRequestsWithTarget(self, selector: #selector(OneSignal.registerUser), object: nil)
                    self.performSelector(#selector(OneSignal.registerUser), withObject: nil, afterDelay: 30.0)
                }
                else {
                    registerUser()
                }
            }
            
            return
        }
        
        if deviceToken.isEqualToString(self.deviceToken as String) {
            if successBlock != nil {
                successBlock!([:])
            }
            return
        }
        
        self.deviceToken = deviceToken
        let request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId)")
        let dataDic = NSDictionary(objects: [app_id, deviceToken], forKeys: ["app_id", "identifier"])
        onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_VERBOSE, message: "Calling OneSignal PUT updated pushToken!")
        
        var postData : NSData? = nil
        do {
            postData = try NSJSONSerialization.dataWithJSONObject(dataDic, options: NSJSONWritingOptions(rawValue: UInt(0)))
        }
        catch _ { }
        
        request.HTTPBody = postData
        self.enqueueRequest(request, onSuccess: successBlock, onFailure: failureBlock)
        
        if idsAvailableBlockWhenReady != nil {
            if#available(iOS 8, *) {
                self.notificationTypes = getNotificationTypes()
            }
            if let usableToken = getUsableDeviceToken() {
                idsAvailableBlockWhenReady(userId, usableToken)
                idsAvailableBlockWhenReady = nil
            }
        }
    }
    
    func registerUser() {
        
        // Make sure we only call create or on_session once per run of the app.
        if oneSignalReg || waitingForOneSReg { return}
        
        waitingForOneSReg = true
        
        let request : NSMutableURLRequest!
        if userId == nil {
            request = self.httpClient.requestWithMethod("POST", path: "Players")
        }
        else {
            request = self.httpClient.requestWithMethod("POST", path: "players/\(userId)/on_session")
        }
        
        let infoDictionary = NSBundle.mainBundle().infoDictionary
        let build = infoDictionary?[kCFBundleVersionKey as String] as? String
        var dataDict = ["app_id" : app_id,
                        "device_model" : deviceModel,
                        "device_os" : systemVersion,
                        "language" : NSLocale.preferredLanguages()[0],
                        "timezone" : NSNumber(long: NSTimeZone.localTimeZone().secondsFromGMT),
                        "ad_id" : NSNumber(int : 0),
                        "sounds" : self.getSoundFiles(),
                        "sdk" : ONESIGNAL_VERSION,
                        "identifier" : deviceToken,
                        "net_type" : getNetType()
        ]
        
        if build != nil {
            dataDict["game_version"] = build!
        }
        
        if #available(iOS 8, *) {
            notificationTypes = getNotificationTypes()
        }
        
        if OneSignalJailbreakDetection.isJailbroken() {
            dataDict["rooted"] = true
        }
        
        if userId != nil {
            dataDict["sdk_type"] = OneSignal.SDKType
            dataDict["ios_bundle"] = NSBundle.mainBundle().bundleIdentifier
        }
        
        if notificationTypes != -1 {
            dataDict["notification_types"] = NSNumber(long: notificationTypes)
        }
        
        /* Ad Support */
        var enabledAdvertizing = false
        if let ASIdentifierManager = NSClassFromString("ASIdentifierManager"),
            asIdManager = ASIdentifierManager.valueForKey("sharedManager"),
            enabled = asIdManager.valueForKey("advertizingTrackingEnabled") as? Bool
            where enabled {
                dataDict["as_id"] = (asIdManager.valueForKey("advertisingIdentifier") as! NSUUID).UUIDString
                enabledAdvertizing = true
        }
        
        if !enabledAdvertizing {
            dataDict["as_id"] = "OptedOut"
        }
        
        let releaseMode = OneSignalMobileProvision.releaseMode()
        if releaseMode == .UIApplicationReleaseDev || releaseMode == .UIApplicationReleaseAdHoc || releaseMode == .UIApplicationReleaseWildcard {
            dataDict["test_type"] = NSNumber(long: releaseMode.rawValue)
        }
        
        if OneSignal.lastLocation != nil {
            dataDict["lat"] = NSNumber(double: OneSignal.lastLocation.cords.latitude)
            dataDict["long"] = NSNumber(double: OneSignal.lastLocation.cords.longitude)
            dataDict["loc_acc_vert"] = NSNumber(double: OneSignal.lastLocation.verticalAccuracy)
            dataDict["loc_acc"] = NSNumber(double: OneSignal.lastLocation.horizontalAccuracy)
            OneSignal.lastLocation = nil
        }
        
        onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_VERBOSE, message: "Calling OneSignal create/on_session")
        
        var postData : NSData? = nil
        do {
            postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0)))
        }
        catch _ {}
        
        
        if postData != nil {
            request.HTTPBody = postData!
        }
        
        self.enqueueRequest(request, onSuccess: { (results) in
            self.oneSignalReg = true
            self.waitingForOneSReg = false
            if let uid = results.objectForKey("id") as? NSString {
                self.userId = uid
                NSUserDefaults.standardUserDefaults().setObject(self.userId, forKey: "GT_PLAYER_ID")
                NSUserDefaults.standardUserDefaults().synchronize()
                
                if self.deviceToken != nil {
                    self.updateDeviceToken(self.deviceToken, onSuccess: self.tokenUpdateSuccessBlock, onFailure: self.tokenUpdateFailureBlock)
                }
                
                if self.tagsToSend != nil {
                    self.sendTagsWithKeyValuePair(self.tagsToSend)
                    self.tagsToSend = nil
                }
                
                if OneSignal.lastLocation != nil {
                    self.sendLocation(OneSignal.lastLocation)
                    OneSignal.lastLocation = nil
                }
                
                if self.emailToSet != nil {
                    self.setEmail(self.emailToSet)
                    self.emailToSet = nil
                }
                
                if let block = self.idsAvailableBlockWhenReady {
                    if let token = self.getUsableDeviceToken() {
                        block(self.userId, token)
                        self.idsAvailableBlockWhenReady = nil
                    }
                }
            }
        }) { (error) in
            self.oneSignalReg = false
            self.waitingForOneSReg = false
            OneSignal.onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_ERROR, message: "Error registering with OneSignal: \(error)")
        }
        
    }
    
    @available(iOS 8.0, *)
    func sendNotificationTypesUpdateIsConfirmed(isConfirm : Bool) {
        // User changed notification settings for the app.
        
        if notificationTypes != -1 && userId != nil && (isConfirm || notificationTypes != getNotificationTypes()) {
            notificationTypes = getNotificationTypes()
            let request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId)")
            let dataDict = ["app_id" : app_id, "notification_types" : NSNumber(long: notificationTypes)]
            var postData : NSData? = nil
            do { postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0))) }
            catch _ {}
            if postData != nil { request.HTTPBody = postData!}
            self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
            
            if let usableToken = getUsableDeviceToken(), block = idsAvailableBlockWhenReady {
                block(userId, usableToken)
                idsAvailableBlockWhenReady = nil
            }
        }
    }
    
    func notificationOpened(messageDict : NSDictionary, isActive : Bool) {
        
        var inAppAlert = false
        if isActive {
            
            inAppAlert = NSUserDefaults.standardUserDefaults().boolForKey("ONESIGNAL_INAPP_ALERT")
            if inAppAlert {
                self.lastMessageReceived = messageDict
                let additionalData = self.getAdditionalData()
                var title = additionalData["title"] as? String
                if title == nil {
                    title = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleDisplayName") as? String
                }
                
                let oneSignalAlertViewDelegate = OneSignalAlertViewDelegate(messageDict: messageDict, oneSignal: self)
                let alert = UIAlertView(title: title, message: self.getMessageString() as String, delegate: oneSignalAlertViewDelegate, cancelButtonTitle: "Close")
                
                if let additional = additionalData["actionButtons"] as? [NSDictionary] {
                    for button in additional {
                        alert.addButtonWithTitle(button["text"] as? String)
                    }
                }
                
                alert.show()
            }
        }
        
        self.handleNotificationOpened(messageDict, isActive: isActive)
        
    }
    
    func handleNotificationOpened(messageDict : NSDictionary, isActive : Bool) {
        
        var messageId, openUrl : String?
        
        var customDict = messageDict.objectForKey("os_data") as? NSDictionary
        if customDict == nil {
            customDict = messageDict.objectForKey("custom") as? NSDictionary
        }
        
        messageId = customDict?.objectForKey("i") as? String
        openUrl = customDict?.objectForKey("u") as? String
        
        if messageId != nil {
            
            let request = self.httpClient.requestWithMethod("PUT", path: "notifications/\(messageId!)")
            let dataDict = ["app_id" : app_id,
                            "player_id" : userId,
                            "opened": NSNumber(bool: true)
                            ]
            
            var postData : NSData? = nil
            do {
                postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0)))
            }
            catch _ {}
            if postData != nil {
                request.HTTPBody = postData!
            }
            self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
        }
        
        if openUrl != nil {
            if UIApplication.sharedApplication().applicationState != .Active {
                dispatch_async(dispatch_get_main_queue(), {
                    UIApplication.sharedApplication().openURL(NSURL(string: openUrl!)!)
                })
            }
        }
        
        self.lastMessageReceived =  messageDict
        clearBadgeCount(true)
        
        if handleNotification != nil {
            handleNotification!(self.getMessageString(), self.getAdditionalData(), isActive)
        }
    }
    
    @available(iOS 8.0, *)
    func updateNotificationTypes(notificationTypes : Int) {
        
        if self.notificationTypes == -2 { return}
        
        let changed = self.notificationTypes != notificationTypes
        self.notificationTypes = notificationTypes
        
        if userId == nil && deviceToken != nil {
            self.registerUser()
        }
        else if deviceToken != nil {
            self.sendNotificationTypesUpdateIsConfirmed(changed)
        }
        
        if let block = idsAvailableBlockWhenReady, uid = userId, usableToken = getUsableDeviceToken() { block(uid, usableToken) }
        
    }
    
}
