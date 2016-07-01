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
    
    static func getMessageString() -> String {
        
        if let alertObj = self.lastMessageReceived["aps"]?["alert"] as? String {
            return alertObj
        }
        
        if let alertObj = self.lastMessageReceived["aps"]?["alert"]??["body"] as? String {
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
    
    static func verifyUrl (urlString: String?) -> Bool {
        //Check for nil
        if let urlString = urlString {
            // create NSURL instance
            if let url = NSURL(string: urlString) {
                // check if your application can open the NSURL instance
                return UIApplication.sharedApplication().canOpenURL(url)
            }
        }
        return false
    }
    
    //Synchroneously downloads a media
    //On success returns bundle resource name, otherwise returns nil
    static func downloadMediaAndSaveInBundle(url : String) -> String? {
        
        print("downloadMediaAndSaveInBundle: " + url)
        
        let supportedExtentions = ["aiff", "wav", "mp3", "mp4", "jpg", "jpeg", "png", "gif", "mpeg", "mpg", "avi", "m4a", "m4v"]
        
        let urlComponents = url.componentsSeparatedByString(".")
        
        //URL not to a file
        if urlComponents.count < 2 { return nil}
        let extention = urlComponents.last!
        
        //Unrecognized extention
        if !supportedExtentions.contains(extention) { return nil }
        
        if let URL = NSURL(string: url), data = NSData(contentsOfURL: URL) {
            // Generate random name, save file and return name
            let name = OneSignal.randomStringWithLength(10) as String + "." + extention
            print("generate name: " + name)
            let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
            let filePath = (paths[0] as NSString).stringByAppendingPathComponent(name)
            data.writeToFile(filePath, atomically: true)
            
            //Save array of cached files in defaults
            if var cachedFiles = NSUserDefaults.standardUserDefaults().objectForKey("CACHED_MEDIA") as? [String] {
                cachedFiles.append(name)
                NSUserDefaults.standardUserDefaults().setObject(cachedFiles, forKey: "CACHED_MEDIA")
                NSUserDefaults.standardUserDefaults().synchronize()
            }
            else {
                let cachedFiles = [name]
                NSUserDefaults.standardUserDefaults().setObject(cachedFiles, forKey: "CACHED_MEDIA")
                NSUserDefaults.standardUserDefaults().synchronize()
            }
            
            return name
        }
        else { return nil }
    }
    
    //Called on init. Clear cache (not needed)
    static func clearCachedMedia() {
        if let cachedFiles = NSUserDefaults.standardUserDefaults().objectForKey("CACHED_MEDIA") as? [String] {
            
            let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
            
            for file in cachedFiles {
                let filePath = (paths[0] as NSString).stringByAppendingPathComponent(file)
                do { try NSFileManager.defaultManager().removeItemAtPath(filePath)}
                catch _ {}
            }
            
            NSUserDefaults.standardUserDefaults().removeObjectForKey("CACHED_MEDIA")
        }
    }
    
    static func randomStringWithLength (len : Int) -> NSString {
        
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        let randomString : NSMutableString = NSMutableString(capacity: len)
        
        for _ in 0 ..< len {
            let length = UInt32 (letters.length)
            let rand = arc4random_uniform(length)
            randomString.appendFormat("%C", letters.characterAtIndex(Int(rand)))
        }
        
        return randomString
    }

}
