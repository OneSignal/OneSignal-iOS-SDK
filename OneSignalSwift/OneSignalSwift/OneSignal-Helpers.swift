//
//  OneSignal-Helpers.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    func getSoundFiles() -> NSArray {
        let fm = NSFileManager.defaultManager()
        
        var  allFiles = []
        let soundFiles = NSMutableArray()
        do { try allFiles = fm.contentsOfDirectoryAtPath(NSBundle.mainBundle().resourcePath!) }
        catch _ { return [] }
        
        for file in allFiles { if file.hasSuffix(".wav") || file.hasSuffix(".mp3") { soundFiles.addObject(file) } }
        
        return soundFiles
    }
    
    func getNetType() -> NSNumber {
        let  reachability = OneSignalReachability.reachabilityForInternetConnection()
        let status = reachability?.currentReachabilityStatus()
        if status == .ReachableViaWiFi { return NSNumber(int: 0) }
        return NSNumber(int: 1)
    }
    
    class func setMSDKType(str : NSString) { SDKType = str as String }
    
    func getAdditionalData() -> NSDictionary {
        
        var additionalData : NSMutableDictionary!
        let osDataDict = self.lastMessageReceived.objectForKey("os_data") as? NSMutableDictionary
        
        if osDataDict != nil {
            additionalData = lastMessageReceived.mutableCopy() as! NSMutableDictionary
            if let u = osDataDict!["u"] { additionalData["launchURL"] = u }
        }
        else {
            additionalData = (self.lastMessageReceived["custom"]?["a"] as! NSMutableDictionary).mutableCopy() as! NSMutableDictionary
            if let u = self.lastMessageReceived["custom"]?["u"] { additionalData["launchURL"] = u }
        }
        
        if additionalData == nil { additionalData = NSMutableDictionary() }
        
        // TODOL Add sound when notification sent with buttons
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
    
    func getMessageString() -> NSString {
        
        if let alertObj = self.lastMessageReceived["aps"]?["alert"] as? NSString {
            return alertObj
        }
        
        if let alertObj = self.lastMessageReceived["aps"]?["alert"]??["body"] as? NSString {
            return alertObj
        }
        
        return ""
    }
    
    func setSubscription(enable : Bool) {
        var value : String? = nil
        if !enable { value = "no"}
        
        NSUserDefaults.standardUserDefaults().setObject(value, forKey: "ONESIGNAL_SUBSCRIPTION")
        NSUserDefaults.standardUserDefaults().synchronize()
        
        subscriptionSet = enable
        if #available(iOS 8.0, *) {
            self.sendNotificationTypesUpdateIsConfirmed(false)
        }
    }
    
    func enableInAppAlertNotification(enable: Bool) {
        NSUserDefaults.standardUserDefaults().setBool(enable, forKey: "ONESIGNAL_INAPP_ALERT")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
}

public extension UIDevice {
    
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8 where value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
        case "iPod5,1":                                 return "iPod Touch 5"
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
        case "iPhone4,1":                               return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8":return "iPad Pro"
        case "AppleTV5,3":                              return "Apple TV"
        case "i386", "x86_64":                          return "Simulator"
        default:                                        return identifier
        }
    }
    
}
