//
//  OneSignal-Helpers.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation
import UIKit

extension OneSignal {
    
    public static func getSoundFiles() -> NSArray {
        let fm = FileManager.default
        
        var  allFiles = []
        let soundFiles = NSMutableArray()
        do { try allFiles = fm.contentsOfDirectory(atPath: Bundle.main.resourcePath!) }
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
    
    static func getMessageString() -> String {
        
        if let alertObj = self.lastMessageReceived["aps"]?["alert"] as? String {
            return alertObj
        }
        
        if let alertObj = self.lastMessageReceived["aps"]?["alert"]??["body"] as? String {
            return alertObj
        }
        
        return ""
    }
    
    public static func setSubscription(_ enable : Bool) {
        var value : String? = nil
        if !enable { value = "no"}
        
        UserDefaults.standard.set(value, forKey: "ONESIGNAL_SUBSCRIPTION")
        UserDefaults.standard.synchronize()
        
        subscriptionSet = enable
        self.sendNotificationTypesUpdateIsConfirmed(false)
    }
    
    public static func enableInAppAlertNotification(_ enable: Bool) {
        UserDefaults.standard.set(enable, forKey: "ONESIGNAL_INAPP_ALERT")
        UserDefaults.standard.synchronize()
    }
    
    static func verifyUrl (_ urlString: String?) -> Bool {
        //Check for nil
        if let urlString = urlString {
            // create URL instance
            if let url = URL(string: urlString) {
                // check if your application can open the NSURL instance
                return UIApplication.shared().canOpenURL(url)
            }
        }
        return false
    }
    
    static func displayWebView(_ url : URL) {
        let webVC = OneSignalWebView()
        webVC.view.frame = UIScreen.main().bounds
        webVC.url = url
        OneSignal.webController.setViewControllers([webVC], animated: false)
        webVC.showInApp()
    }
    
    //Synchroneously downloads a media
    //On success returns bundle resource name, otherwise returns nil
    static func downloadMediaAndSaveInBundle(_ url : String) -> String? {
        
        print("downloadMediaAndSaveInBundle: " + url)
        
        let supportedExtentions = ["aiff", "wav", "mp3", "mp4", "jpg", "jpeg", "png", "gif", "mpeg", "mpg", "avi", "m4a", "m4v"]
        
        let urlComponents = url.components(separatedBy: ".")
        
        //URL is not to a file
        if urlComponents.count < 2 { return nil}
        let extention = urlComponents.last!
        
        //Unrecognized extention
        if !supportedExtentions.contains(extention) { return nil }
        
        if let URL = URL(string: url), data = try? Data(contentsOf: URL) {
            // Generate random name, save file and return name
            let name = OneSignal.randomStringWithLength(10) as String + "." + extention
            print("generate name: " + name)
            let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
            let filePath = (paths[0] as NSString).appendingPathComponent(name)
            _ = try? data.write(to: Foundation.URL(fileURLWithPath: filePath), options: [.atomicWrite])
            
            //Save array of cached files in defaults
            if var cachedFiles = UserDefaults.standard.object(forKey: "CACHED_MEDIA") as? [String] {
                cachedFiles.append(name)
                UserDefaults.standard.set(cachedFiles, forKey: "CACHED_MEDIA")
                UserDefaults.standard.synchronize()
            }
            else {
                let cachedFiles = [name]
                UserDefaults.standard.set(cachedFiles, forKey: "CACHED_MEDIA")
                UserDefaults.standard.synchronize()
            }
            
            return name
        }
        else { return nil }
    }
    
    //Called on init. Clear cache (not needed)
    static func clearCachedMedia() {
        if let cachedFiles = UserDefaults.standard.object(forKey: "CACHED_MEDIA") as? [String] {
            
            let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
            
            for file in cachedFiles {
                let filePath = (paths[0] as NSString).appendingPathComponent(file)
                do { try FileManager.default.removeItem(atPath: filePath)}
                catch _ {}
            }
            
            UserDefaults.standard.removeObject(forKey: "CACHED_MEDIA")
        }
    }
    
    static func randomStringWithLength (_ len : Int) -> NSString {
        
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        let randomString : NSMutableString = NSMutableString(capacity: len)
        
        for _ in 0 ..< len {
            let length = UInt32 (letters.length)
            let rand = arc4random_uniform(length)
            randomString.appendFormat("%C", letters.character(at: Int(rand)))
        }
        
        return randomString
    }

}
