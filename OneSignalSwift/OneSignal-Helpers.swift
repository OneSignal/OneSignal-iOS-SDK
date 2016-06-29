//
//  OneSignal-Helpers.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    public static func getSoundFiles() -> NSArray {
        let fm = NSFileManager.defaultManager()
        
        var  allFiles = []
        let soundFiles = NSMutableArray()
        do { try allFiles = fm.contentsOfDirectoryAtPath(NSBundle.mainBundle().resourcePath!) }
        catch _ { return [] }
        
        for file in allFiles { if file.hasSuffix(".wav") || file.hasSuffix(".mp3") { soundFiles.addObject(file) } }
        
        return soundFiles
    }
    
    static func getNetType() -> NSNumber {
        OneSignalReachability.reachabilityForInternetConnection()
        let status = OneSignalReachability.currentReachabilityStatus()
        if status == .ReachableViaWiFi { return NSNumber(int: 0) }
        return NSNumber(int: 1)
    }
    
    static func setMSDKType(str : NSString) { SDKType = str as String }
    
    static func getAdditionalData() -> NSDictionary {
        
        var additionalData : NSMutableDictionary!
        let osDataDict = self.lastMessageReceived.objectForKey("os_data") as? NSMutableDictionary
        
        if osDataDict != nil {
            additionalData = lastMessageReceived.mutableCopy() as! NSMutableDictionary
            if let u = osDataDict!["u"] { additionalData["launchURL"] = u }
        }
        else {
            if let custom = self.lastMessageReceived["custom"] as? NSDictionary {
                if let data = custom["a"] as? NSMutableDictionary {
                    additionalData = data.mutableCopy() as! NSMutableDictionary
                }
                if let u = custom["u"] {
                    additionalData["launchURL"] = u
                }
            }
        }
        
        if additionalData == nil { additionalData = NSMutableDictionary() }
        
        // TODO: Add sound when notification sent with buttons
        if let sound = self.lastMessageReceived["aps"]?["sound"] { additionalData["sound"] = sound }
        if let alert = self.lastMessageReceived["aps"]?["alert"] as? NSDictionary {
            additionalData["title"] = alert["title"]!
        }
        
        if osDataDict != nil {
            additionalData.removeObjectForKey("aps")
            additionalData.removeObjectForKey("os_data")
        }
        
        return additionalData
    }
    
    static func getMessageString() -> NSString {
        
        if let alertObj = self.lastMessageReceived["aps"]?["alert"] as? NSString {
            return alertObj
        }
        
        if let alertObj = self.lastMessageReceived["aps"]?["alert"]??["body"] as? NSString {
            return alertObj
        }
        
        return ""
    }
    
    public static func setSubscription(enable : Bool) {
        var value : String? = nil
        if !enable { value = "no"}
        
        NSUserDefaults.standardUserDefaults().setObject(value, forKey: "ONESIGNAL_SUBSCRIPTION")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        subscriptionSet = enable
        self.sendNotificationTypesUpdateIsConfirmed(false)
    }
    
    public static func enableInAppAlertNotification(enable: Bool) {
        NSUserDefaults.standardUserDefaults().setBool(enable, forKey: "ONESIGNAL_INAPP_ALERT")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
}
