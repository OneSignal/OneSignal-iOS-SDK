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
        let fm = FileManager.default()
        
        var  allFiles = []
        let soundFiles = NSMutableArray()
        do { try allFiles = fm.contentsOfDirectory(atPath: Bundle.main().resourcePath!) }
        catch _ { return [] }
        
        for file in allFiles { if file.hasSuffix(".wav") || file.hasSuffix(".mp3") { soundFiles.add(file) } }
        
        return soundFiles
    }
    
    static func getNetType() -> NSNumber {
        OneSignalReachability.reachabilityForInternetConnection()
        let status = OneSignalReachability.currentReachabilityStatus()
        if status == .reachableViaWiFi { return NSNumber(value: 0) }
        return NSNumber(value: 1)
    }
    
    static func setMSDKType(_ str : NSString) { SDKType = str as String }
    
    static func getAdditionalData() -> NSDictionary {
        
        var additionalData : NSMutableDictionary!
        let osDataDict = self.lastMessageReceived.object(forKey: "os_data") as? NSMutableDictionary
        
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
            additionalData.removeObject(forKey: "aps")
            additionalData.removeObject(forKey: "os_data")
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
    
    public static func setSubscription(_ enable : Bool) {
        var value : String? = nil
        if !enable { value = "no"}
        
        UserDefaults.standard().set(value, forKey: "ONESIGNAL_SUBSCRIPTION")
        UserDefaults.standard().synchronize()
        
        subscriptionSet = enable
        self.sendNotificationTypesUpdateIsConfirmed(false)
    }
    
    public static func enableInAppAlertNotification(_ enable: Bool) {
        UserDefaults.standard().set(enable, forKey: "ONESIGNAL_INAPP_ALERT")
        UserDefaults.standard().synchronize()
    }
}
