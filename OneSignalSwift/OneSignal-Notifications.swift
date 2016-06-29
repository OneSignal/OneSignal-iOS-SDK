//
//  OneSignal-Notifications.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/24/16.
//  Copyright © 2016 Joseph Kalash. All rights reserved.
//

import Foundation


extension OneSignal {
    
    static func getUsableDeviceToken() -> NSString? {
        return notificationTypes > 0 ? deviceToken : nil
    }
    
    public static func IdsAvailable(_ idsAvailableBlock : OneSignalIdsAvailableBlock) {
        if userId != nil {
            idsAvailableBlock(userId!, getUsableDeviceToken())
        }
        
        if userId == nil || getUsableDeviceToken() == nil {
            idsAvailableBlockWhenReady = idsAvailableBlock
        }
    }
    
    @available(iOS 8.0, *)
    static func isCapableOfGettingNotificationTypes() -> Bool {
        return UIApplication.shared().responds(to: #selector(UIApplication.currentUserNotificationSettings))
    }
    
    @available(iOS 8.0, *)
    static func  getNotificationTypes() -> Int {
        if subscriptionSet == false { return -2 }
        
        if self.deviceToken != nil {
            if isCapableOfGettingNotificationTypes() {
                if let notifTypes = UIApplication.shared().currentUserNotificationSettings()?.types { return Int(notifTypes.rawValue) }
                return 0
            }
            else { return NotificationType.all.rawValue}
        }
        
        return -1
    }
    
    static func clearBadgeCount(_ fromNotifOpened : Bool) -> Bool {
        if disableBadgeClearing || notificationTypes == -1 || (notificationTypes & NotificationType.badge.rawValue) == 0 { return false}
        
        let wasBadgeSet = UIApplication.shared().applicationIconBadgeNumber > 0
        
        if  ( !(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_7_1) && fromNotifOpened ) || wasBadgeSet {
            
            // Clear bages and nofiications from this app.
            // Setting to 1 then 0 was needed to clear the notifications on iOS 6 & 7. (Otherwise you can click the notification multiple times.)
            // iOS 8+ auto dismisses the notificaiton you tap on so only clear the badge (and notifications [side-effect]) if it was set.
            UIApplication.shared().applicationIconBadgeNumber = 1
            UIApplication.shared().applicationIconBadgeNumber = 0
        }
        
        return wasBadgeSet
    }
    
    public static func registerForPushNotifications() {
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        // iOS 8+
   //     if #available(iOS 8.0, *) {
            let existingCategories = UIApplication.shared().currentUserNotificationSettings()?.categories
            let notificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: existingCategories)
            UIApplication.shared().registerUserNotificationSettings(notificationSettings)
            UIApplication.shared().registerForRemoteNotifications()
//        }
//        else {
//            UIApplication.sharedApplication().registerForRemoteNotificationTypes([.Badge, .Sound, .Alert])
//            if !registeredWithApple {
//                NSUserDefaults.standardUserDefaults().setObject(NSNumber(bool: true), forKey: "GT_REGISTERED_WITH_APPLE")
//                NSUserDefaults.standardUserDefaults().synchronize()
//            }
//        }
    }
    
    static func registerDeviceToken(_ inDeviceToken : NSString, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock: OneSignalFailureBlock?) {
        self.updateDeviceToken(inDeviceToken, onSuccess: successBlock, onFailure: failureBlock)
        UserDefaults.standard().set(deviceToken, forKey: "GT_DEVICE_TOKEN")
        UserDefaults.standard().synchronize()
    }
    
    static func updateDeviceToken(_ deviceToken : NSString, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock: OneSignalFailureBlock?) {
        
        if userId == nil {
            self.deviceToken = deviceToken
            tokenUpdateSuccessBlock = successBlock
            tokenUpdateFailureBlock = failureBlock
            
            // iOS 8 - We get a token right away but give the user 30 sec to responsed to the system prompt.
            // Also check mNotificationTypes so there is no waiting if user has already answered the system prompt.
            // The goal is to only have 1 server call.
            if notificationTypes == -1 {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(OneSignal.registerUser), object: nil)
                self.perform(#selector(OneSignal.registerUser), with: nil, afterDelay: 30.0)
            }
            
            return
        }
        
        if self.deviceToken != nil && deviceToken.isEqual(to: self.deviceToken as! String) {
            if successBlock != nil {
                successBlock!([:])
            }
            return
        }
        
        self.deviceToken = deviceToken
        var request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId)")
        let dataDic = NSDictionary(objects: [app_id, deviceToken], forKeys: ["app_id", "identifier"])
        OneSignal.onesignal_Log(.one_S_LL_VERBOSE, message: "Calling OneSignal PUT updated pushToken!")
        
        var postData : Data? = nil
        do {
            postData = try JSONSerialization.data(withJSONObject: dataDic, options: JSONSerialization.WritingOptions(rawValue: UInt(0)))
        }
        catch _ { }
        
        request.httpBody = postData
        self.enqueueRequest(request, onSuccess: successBlock, onFailure: failureBlock)
        
        if idsAvailableBlockWhenReady != nil {
            self.notificationTypes = getNotificationTypes()
            if let usableToken = getUsableDeviceToken() {
                idsAvailableBlockWhenReady(userId!, usableToken)
                idsAvailableBlockWhenReady = nil
            }
        }
    }
    
    static func registerUser() {
        
        // Make sure we only call create or on_session once per run of the app.
        if oneSignalReg || waitingForOneSReg { return}
        
        waitingForOneSReg = true
        
        var request : URLRequest!
        if userId == nil {
            request = self.httpClient.requestWithMethod("POST", path: "players")
        }
        else {
            request = self.httpClient.requestWithMethod("POST", path: "players/\(userId!)/on_session")
        }
        
        let infoDictionary = Bundle.main().infoDictionary
        let build = infoDictionary?[kCFBundleVersionKey as String] as? String
        let identifier = deviceToken == nil ? "" : deviceToken!
        
        var dataDict = ["app_id" : app_id,
                        "device_model" : deviceModel,
                        "device_os" : systemVersion,
                        "language" : Locale.preferredLanguages()[0],
                        "timezone" : NSNumber(value: TimeZone.local().secondsFromGMT),
                        "device_type" : NSNumber(value : 0),
                        "sounds" : self.getSoundFiles(),
                        "sdk" : ONESIGNAL_VERSION,
                        "identifier" : identifier,
                        "net_type" : getNetType()
        ]
        
        if build != nil {
            dataDict["game_version"] = build!
        }
        
        notificationTypes = getNotificationTypes()
        
        if let vendorIdentifier = UIDevice.current().identifierForVendor?.uuidString {
            dataDict["ad_id"] = vendorIdentifier
        }
        
        if OneSignalJailbreakDetection.isJailbroken() {
            dataDict["rooted"] = true
        }
        
        if userId != nil {
            dataDict["sdk_type"] = OneSignal.SDKType
            dataDict["ios_bundle"] = Bundle.main().bundleIdentifier
        }
        
        if notificationTypes != -1 {
            dataDict["notification_types"] = NSNumber(value: notificationTypes)
        }
        
        /* Ad Support */
        var enabledAdvertizing = false
        if let ASIdentifierManager = NSClassFromString("ASIdentifierManager"),
            asIdManager = ASIdentifierManager.value(forKey: "sharedManager"),
            enabled = asIdManager.value(forKey: "advertizingTrackingEnabled") as? Bool
            where enabled {
                dataDict["as_id"] = (asIdManager.value(forKey: "advertisingIdentifier") as! UUID).uuidString
                enabledAdvertizing = true
        }
        
        if !enabledAdvertizing {
            dataDict["as_id"] = "OptedOut"
        }
        
        let releaseMode = OneSignalMobileProvision.releaseMode()
        if releaseMode == .uiApplicationReleaseDev || releaseMode == .uiApplicationReleaseAdHoc || releaseMode == .uiApplicationReleaseWildcard {
            dataDict["test_type"] = NSNumber(value: releaseMode.rawValue)
        }
        
        
        if OneSignal.lastLocation != nil {
            dataDict["lat"] = NSNumber(value: OneSignal.lastLocation.cords.latitude)
            dataDict["long"] = NSNumber(value: OneSignal.lastLocation.cords.longitude)
            dataDict["loc_acc_vert"] = NSNumber(value: OneSignal.lastLocation.verticalAccuracy)
            dataDict["loc_acc"] = NSNumber(value: OneSignal.lastLocation.horizontalAccuracy)
            OneSignal.lastLocation = nil
        }
        
        OneSignal.onesignal_Log(.one_S_LL_VERBOSE, message: "Calling OneSignal create/on_session")
        
        var postData : Data? = nil
        do {
            postData = try JSONSerialization.data(withJSONObject: dataDict, options: JSONSerialization.WritingOptions(rawValue: UInt(0)))
        }
        catch _ {}
        
        
        if postData != nil {
            request.httpBody = postData!
        }
        
        self.enqueueRequest(request, onSuccess: { (results) in
            self.oneSignalReg = true
            self.waitingForOneSReg = false
            if let uid = results.object(forKey: "id") as? NSString {
                self.userId = uid
            }
            UserDefaults.standard().set(self.userId!, forKey: "GT_PLAYER_ID")
            UserDefaults.standard().synchronize()
                
            if self.deviceToken != nil {
                self.updateDeviceToken(self.deviceToken!, onSuccess: self.tokenUpdateSuccessBlock, onFailure: self.tokenUpdateFailureBlock)
            }
                
            if self.tagsToSend != nil {
                self.sendTags(self.tagsToSend)
                self.tagsToSend = nil
            }
                
            if OneSignal.lastLocation != nil && self.userId != nil {
                self.sendLocation(OneSignal.lastLocation)
                OneSignal.lastLocation = nil
            }

                
            if self.emailToSet != nil {
                self.setEmail(self.emailToSet)
                self.emailToSet = nil
            }
                
            if let block = self.idsAvailableBlockWhenReady {
                if let token = self.getUsableDeviceToken() {
                    block(self.userId!, token)
                    self.idsAvailableBlockWhenReady = nil
                }
            }
        }) { (error) in
            self.oneSignalReg = false
            self.waitingForOneSReg = false
            OneSignal.onesignal_Log(.one_S_LL_ERROR, message: "Error registering with OneSignal: \(error)")
        }
        
    }
    
    @available(iOS 8.0, *)
    static func sendNotificationTypesUpdateIsConfirmed(_ isConfirm : Bool) {
        // User changed notification settings for the app.
        
        if notificationTypes != -1 && userId != nil && (isConfirm || notificationTypes != getNotificationTypes()) {
            notificationTypes = getNotificationTypes()
            var request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId)")
            let dataDict = ["app_id" : app_id, "notification_types" : NSNumber(value: notificationTypes)]
            var postData : Data? = nil
            do { postData = try JSONSerialization.data(withJSONObject: dataDict, options: JSONSerialization.WritingOptions(rawValue: UInt(0))) }
            catch _ {}
            if postData != nil { request.httpBody = postData!}
            self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
            
            if let usableToken = getUsableDeviceToken(), block = idsAvailableBlockWhenReady {
                block(userId!, usableToken)
                idsAvailableBlockWhenReady = nil
            }
        }
    }
    
    static func notificationOpened(_ messageDict : NSDictionary, isActive : Bool) {
        
        var inAppAlert = false
        if isActive {
            
            inAppAlert = UserDefaults.standard().bool(forKey: "ONESIGNAL_INAPP_ALERT")
            if inAppAlert {
                self.lastMessageReceived = messageDict
                let additionalData = self.getAdditionalData()
                var title = additionalData["title"] as? String
                if title == nil {
                    title = Bundle.main().objectForInfoDictionaryKey("CFBundleDisplayName") as? String
                }
                
                let oneSignalAlertViewDelegate = OneSignalAlertViewDelegate(messageDict: messageDict)
                let alert = UIAlertView(title: title, message: self.getMessageString() as String, delegate: oneSignalAlertViewDelegate, cancelButtonTitle: "Close")
                
                if let additional = additionalData["actionButtons"] as? [NSDictionary] {
                    for button in additional {
                        alert.addButton(withTitle: button["text"] as? String)
                    }
                }
                
                alert.show()
            } 
        }
        
        self.handleNotificationOpened(messageDict, isActive: isActive)
        
    }
    
    static func handleNotificationOpened(_ messageDict : NSDictionary, isActive : Bool) {
        
        var messageId, openUrl : String?
        
        var customDict = messageDict.object(forKey: "os_data") as? NSDictionary
        if customDict == nil {
            customDict = messageDict.object(forKey: "custom") as? NSDictionary
        }
        
        messageId = customDict?.object(forKey: "i") as? String
        openUrl = customDict?.object(forKey: "u") as? String
        
        if messageId != nil {
            
            var request = self.httpClient.requestWithMethod("PUT", path: "notifications/\(messageId!)")
            let playerId = userId != nil ? userId! : ""
            let dataDict = ["app_id" : app_id,
                            "player_id" : playerId,
                            "opened": NSNumber(value: true)
                            ]
            
            var postData : Data? = nil
            do {
                postData = try JSONSerialization.data(withJSONObject: dataDict, options: JSONSerialization.WritingOptions(rawValue: UInt(0)))
            }
            catch _ {}
            if postData != nil {
                request.httpBody = postData!
            }
            self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
        }
        
        if openUrl != nil {
            if UIApplication.shared().applicationState != .active {
                DispatchQueue.main.async(execute: {
                    UIApplication.shared().openURL(URL(string: openUrl!)!)
                })
            }
        }
        
        self.lastMessageReceived =  messageDict
        let _ = clearBadgeCount(true)
        
        if handleNotification != nil {
            handleNotification!(self.getMessageString(), self.getAdditionalData(), isActive)
        }
    }
    
    @available(iOS 8.0, *)
    static func updateNotificationTypes(_ notificationTypes : Int) {
        
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
