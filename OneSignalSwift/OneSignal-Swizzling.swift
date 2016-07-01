//
//  OneSignal-Swizzling.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal : UIApplicationDelegate{
    
    
    static func didRegisterForRemoteNotifications(app : UIApplication, deviceToken inDeviceToken : NSData) {
        
        let trimmedDeviceToken = inDeviceToken.description.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>"))
        let parsedDeviceToken = (trimmedDeviceToken.componentsSeparatedByString(" ") as NSArray).componentsJoinedByString("")
        
        OneSignal.onesignal_Log(.INFO, message: "Device Registered With Apple: \(parsedDeviceToken)")
        
        self.registerDeviceToken(parsedDeviceToken, onSuccess: { (results) in
            OneSignal.onesignal_Log(.INFO, message: "Device Registered With OneSignal: \(self.userId!)")
            }) { (error) in
                OneSignal.onesignal_Log(.INFO, message: "Error in OneSignal registration: \(error)")
        }
    }
    
    
    /* Pre iOS 10.0 Use UIUserNotificationAction & UILocalNotification */
    static func prepareUILocalNotification(data : [String : AnyObject], userInfo : NSDictionary) -> UILocalNotification {
        let notification = UILocalNotification()
        let category = UIMutableUserNotificationCategory()
        category.identifier = "dynamic"
        var actionArray : [UIUserNotificationAction] = []
        if let buttons = data["o"] as? [[String : String]] {
            for button in buttons {
                let action = UIMutableUserNotificationAction()
                action.title = button["n"]
                action.identifier = (button["i"] != nil) ? button["i"]! : action.title!
                action.activationMode = .Foreground
                action.destructive = false
                action.authenticationRequired = false
                actionArray.append(action)
            }
        }
        
        //iOS 8 shows notification buttons in reverse in all cases but alerts. This flips it so the frist button is on the left.
        if actionArray.count == 2 {
            category.setActions([actionArray[1], actionArray[0]], forContext: .Minimal)
        }
        else {
            category.setActions(actionArray, forContext: .Default)
        }
        
        let notificationTypes = NotificationType.All
        let set = Set<UIUserNotificationCategory>(arrayLiteral: category)
        let notificationType = UIUserNotificationType(rawValue: UInt(notificationTypes.rawValue))
        let notificationSettings = UIUserNotificationSettings(forTypes: notificationType, categories: set)
        UIApplication.sharedApplication().registerUserNotificationSettings(notificationSettings)
        
        notification.category = category.identifier
        if let m = data["m"] as? [String : String] {
            if #available(iOS 8.2, *) {notification.alertTitle = m["title"] }
            notification.alertBody = m["body"]
        }
        else if let m = data["m"] as? String {
            notification.alertBody = m
        }
        notification.userInfo = userInfo as [NSObject : AnyObject]
        notification.soundName = data["s"] as? String
        if notification.soundName == nil {
            notification.soundName = UILocalNotificationDefaultSoundName
        }
        
        if let badge = data["b"] as? NSNumber {
            notification.applicationIconBadgeNumber = badge.integerValue
        }
        
        return notification
    }
    
    
    @available(iOS 10.0, *)
    static func prepareUNNotificationRequest(data : [String : AnyObject], userInfo : NSDictionary) -> UNNotificationRequest {
        
        print(userInfo)
        var actionArray : [UNNotificationAction] = []
        if let buttons = data["o"] as? [[String : String]] {
            for button in buttons {
                let title = button["n"] != nil ? button["n"]! : ""
                let identifier = (button["i"] != nil) ? button["i"]! : title
                let action = UNNotificationAction(identifier: identifier, title: title, options: .Foreground)
                actionArray.append(action)
            }
        }
        
        if actionArray.count == 2 { actionArray = actionArray.reverse() }
        
        let category = UNNotificationCategory(identifier: "dyanamic", actions: actionArray, minimalActions: [], intentIdentifiers: [], options: .None)
        let set = Set<UNNotificationCategory>(arrayLiteral: category)
        UNUserNotificationCenter.currentNotificationCenter().setNotificationCategories(set)
        
        
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "dyanamic"
        
        if let m = data["m"] as? [String : String] {
            if let title = m["title"] { content.title = title }
            if let body = m["body"] { content.body = body }
        }
        else if let m = data["m"] as? String {
            content.body = m
        }
        
        content.userInfo = userInfo as [NSObject : AnyObject]
        
        if let sound = data["s"] as? String {
            content.sound = UNNotificationSound(named: sound)
        }
        else {
            content.sound = UNNotificationSound.defaultSound()
        }
        
        content.badge = data["b"] as? NSNumber
        
        
        //Check if media attached
        //!! TEMP : Until Server implements Media Dict, use additional data dict as key val media
        if let custom = userInfo["custom"] as? NSDictionary,
            additional = custom["a"] as? [String : String] {
            for (id, URI) in additional {
                /* Remote Object */
                if OneSignal.verifyUrl(URI) {
                    /* Synchroneously download file and chache it */
                    let name = OneSignal.downloadMediaAndSaveInBundle(URI)
                    if name == nil { continue }
                    let paths = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)
                    let filePath = (paths[0] as NSString).stringByAppendingPathComponent(name!)
                    let url = NSURL(fileURLWithPath: filePath)
                    var attachment : UNNotificationAttachment!
                    do { attachment = try UNNotificationAttachment(identifier:id, URL: url, options: nil) }
                    catch _ {}
                    if attachment != nil {
                        content.attachments.append(attachment)
                        print("Attachment added")
                    }
                }
                    
                /* Local in bundle resources */
                else {
                    var files = URI.componentsSeparatedByString(".")
                    if files.count < 2 {continue}
                    let fileExtension = files.last!
                    files.removeLast()
                    let name = files.joinWithSeparator(".")
                    // Make sure reesource exists
                    if let url = NSBundle.mainBundle().URLForResource(name, withExtension: fileExtension) {
                        var attachment : UNNotificationAttachment!
                        do { attachment = try UNNotificationAttachment(identifier:id, URL: url, options: nil) }
                        catch _ {}
                        if attachment != nil {content.attachments.append(attachment)}
                    }
                }
            }
        }
        
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.25, repeats: false)
        let notification = UNNotificationRequest(identifier: "dynamic", content: content, trigger: trigger)
        return notification
    }
    
    static func remoteSilentNotification(application : UIApplication, userInfo : NSDictionary) {
        
        var data : [String : AnyObject]? = nil

        if let buttons = userInfo["os_data"]?["buttons"] as? [String : AnyObject] { data = buttons }
        else if let _ = userInfo["m"] as? [String : AnyObject] { data = userInfo as? [String : AnyObject] }
        
        if data != nil {
            
            if #available(iOS 10.0, *) {
                let notificationRequest = prepareUNNotificationRequest(data!, userInfo : userInfo)
                UNUserNotificationCenter.currentNotificationCenter().addNotificationRequest(notificationRequest, withCompletionHandler: nil)
            }
            else {
                let notification = prepareUILocalNotification(data!, userInfo : userInfo)
                UIApplication.sharedApplication().scheduleLocalNotification(notification)
            }
        }
            
        else if application.applicationState != .Background {
            self.notificationOpened(userInfo, isActive: application.applicationState == .Active)
        }
        
    }
    
    static func processLocalActionBasedNotification(notification : UILocalNotification, identifier: NSString) {
        
        if notification.userInfo == nil {return}
        
        let userInfo = NSMutableDictionary()
        let customDict = NSMutableDictionary()
        let additionalData = NSMutableDictionary()
        let optionsDict = NSMutableArray()
        
        if let os_data = notification.userInfo!["os_data"],
        buttonsDict = os_data["buttons"] as? NSMutableDictionary {
            userInfo.addEntriesFromDictionary(notification.userInfo!)
            if let o = buttonsDict["o"] as? [[NSObject : AnyObject]] { optionsDict.addObjectsFromArray(o) }
        }
        else if let custom = notification.userInfo!["custom"] as? [NSObject : AnyObject] {
            userInfo.addEntriesFromDictionary(notification.userInfo!)
            customDict.addEntriesFromDictionary(custom)
            if let a = customDict["a"] as? [NSObject : AnyObject] {
                additionalData.addEntriesFromDictionary(a)
            }
            if let o = userInfo["o"] as? [[String : String]] {
                optionsDict.addObjectsFromArray(o)
            }
        }
            
        else {return}

        let buttonArray = NSMutableArray()
        for button in optionsDict {
            
            let buttonToAppend : [NSObject : AnyObject] = [
                                        "text" : button["n"] != nil ? button["n"]!! : "",
                                            "id" : button["i"] != nil ? button["i"]!! : button["n"]!!
                                ]
            
            buttonArray.addObject(buttonToAppend)
        }
        
        additionalData["actionSelected"] = identifier
        additionalData["actionButtons"] = buttonArray
        
        if let os_data = notification.userInfo!["os_data"] as? [String : AnyObject] {
            for (key, val) in os_data { userInfo.setObject(val, forKey: key) }
            if let os_d = userInfo["os_data"],
            buttons = os_d["buttons"] as? NSMutableDictionary,
                m = buttons["m"] {
                let alert = m
                userInfo["aps"] = ["alert" : alert]
            }
        }
        else {
            customDict["a"] = additionalData
            userInfo["custom"] = customDict
            userInfo["aps"] = ["alert":userInfo["m"]!]
        }
        
        OneSignal.notificationOpened(userInfo, isActive: UIApplication.sharedApplication().applicationState == .Active)
    }

    static func getClassWithProtocolInHierarchy(searchClass : AnyClass, protocolToFind : Protocol) -> AnyClass? {
        
        if !class_conformsToProtocol(searchClass, protocolToFind) {
            if searchClass.superclass() == nil { return nil}
            let foundClass : AnyClass? = getClassWithProtocolInHierarchy(searchClass.superclass()!, protocolToFind: protocolToFind)
            if foundClass != nil { return foundClass}
            return searchClass
        }
        return searchClass
    }
    
    static func injectSelector(newClass : AnyClass, newSel : Selector, addToClass : AnyClass, makeLikeSel : Selector) {
        var newMeth = class_getInstanceMethod(newClass, newSel)
        let imp = method_getImplementation(newMeth)
        let methodTypeEncoding = method_getTypeEncoding(newMeth)
        let successful = class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding)
        if !successful {
            class_addMethod(addToClass, newSel, imp, methodTypeEncoding)
            newMeth = class_getInstanceMethod(addToClass, newSel)
            let orgMeth = class_getInstanceMethod(addToClass, makeLikeSel)
            method_exchangeImplementations(orgMeth, newMeth)
        }
    }
    
}

