//
//  OneSignal-Swizzling.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal : UIApplicationDelegate{
    
    
    func didRegisterForRemoteNotifications(app : UIApplication, deviceToken inDeviceToken : NSData) {
        let trimmedDeviceToken = inDeviceToken.description.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>"))
        let parsedDeviceToken = (trimmedDeviceToken.componentsSeparatedByString(" ") as NSArray).componentsJoinedByString("")
        OneSignal.onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_INFO, message: "Device Registered With Apple: \(parsedDeviceToken)")
        self.registerDeviceToken(parsedDeviceToken, onSuccess: { (results) in
            OneSignal.onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_INFO, message: "Device Registered With OneSignal: \(self.userId)")
            }) { (error) in
                OneSignal.onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_INFO, message: "Error in OneSignal registration: \(error)")
        }
    }
    
    func remoteSilentNotification(application : UIApplication, userInfo : NSDictionary) {
        
        var data : NSDictionary? = nil
        
        if let os_data = userInfo["os_data"] as? NSDictionary { data = os_data["buttons"] as? NSDictionary }
        else if userInfo["m"] != nil {data = userInfo}
        
        if data != nil {
            var notification : UILocalNotification!
            if #available(iOS 8.0, *) {
                let category = UIMutableUserNotificationCategory()
                category.identifier = "dynamic"
                var actionArray : [UIUserNotificationAction] = []
                for button in data!["o"] as! NSArray {
                    let action = UIMutableUserNotificationAction()
                    action.title = button["n"] as? String
                    let identifier = (button["i"] != nil) ? button["i"]! : action.title!
                    action.identifier = identifier as? String
                    action.activationMode = .Foreground
                    action.destructive = false
                    action.authenticationRequired = false
                    actionArray.append(action)
                    // iOS 8 shows notification buttons in reverse in all cases but alerts. This flips it so the frist button is on the left.
                    if actionArray.count == 2 { category.setActions([actionArray[1], actionArray[0]], forContext: .Minimal) }
                }
            
                category.setActions(actionArray, forContext: UIUserNotificationActionContext.Default)
            
                let notificationTypes = NotificationType.All
            
            
                let set = NSSet(object: category) as! Set<UIUserNotificationCategory>
                UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: UIUserNotificationType(rawValue: UInt(notificationTypes.rawValue)), categories: set))
            
                notification = UILocalNotification()
                notification.category = category.identifier
                if let m = data!["m"] as? NSDictionary {
                    if #available(iOS 8.2, *) {notification.alertTitle = m["title"] as? String}
                    notification.alertBody = m["body"] as? String
                }
                else { notification.alertBody = data!["m"] as? String }
            }
            
            notification.userInfo = userInfo as [NSObject : AnyObject]
            notification.soundName = data!["s"] as? String
            if notification.soundName == nil { notification.soundName = UILocalNotificationDefaultSoundName }
            if let badge = data!["b"] as? NSNumber { notification.applicationIconBadgeNumber = badge.integerValue }
            
            UIApplication.sharedApplication().scheduleLocalNotification(notification)
        }
            
        else if application.applicationState != .Background {
            self.notificationOpened(userInfo, isActive: application.applicationState == .Active)
        }
    }
    
    func processLocalActionBasedNotification(notification : UILocalNotification, identifier: NSString) {
        
        if notification.userInfo == nil {return}
        
        var userInfo, customDict, additionalData : NSMutableDictionary!
        var optionsDict : [NSDictionary]!
        
        if let _ = notification.userInfo!["os_data"], buttonsDict = notification.userInfo!["os_data"]?["buttons"] as? NSMutableDictionary {
            userInfo = (notification.userInfo! as NSDictionary).mutableCopy() as! NSMutableDictionary
            additionalData = NSMutableDictionary()
            optionsDict = buttonsDict["o"] as? [NSDictionary]
        }
        else if let custom = notification.userInfo!["custom"] as? NSMutableDictionary {
            userInfo = (notification.userInfo! as NSDictionary).mutableCopy() as! NSMutableDictionary
            customDict = custom.mutableCopy() as! NSMutableDictionary
            additionalData = NSMutableDictionary(dictionary: customDict["a"] as! NSMutableDictionary)
            optionsDict = userInfo["o"] as? [NSDictionary]
        }
        else {return}
        
        let buttonArray = NSMutableArray()
        for button in optionsDict {
            buttonArray.addObject(["text" : button["n"] as! String,
                                "id" : button["i"] != nil ? button["i"] as! String : button["n"] as! String])
        }
        additionalData["actionSelected"] = identifier
        additionalData["actionButtons"] = buttonArray
        
        if let os_data = notification.userInfo!["os_data"] as? [NSObject : AnyObject] {
            userInfo.addEntriesFromDictionary(os_data)
            let alert = userInfo["os_data"]!["buttons"]!!["m"]!!
            userInfo["aps"] = ["alert" : alert]
        }
        else {
            customDict["a"] = additionalData
            userInfo["custom"] = customDict
            userInfo["aps"] = ["alert" : userInfo!["m"]!]
        }
        
        self.notificationOpened(userInfo, isActive: UIApplication.sharedApplication().applicationState == .Active)
    }

    class func getClassWithProtocolInHierarchy(searchClass : AnyClass, protocolToFind : Protocol) -> AnyClass? {
        
        if !class_conformsToProtocol(searchClass, protocolToFind) {
            if searchClass.superclass() == nil { return nil}
            let foundClass : AnyClass? = getClassWithProtocolInHierarchy(searchClass.superclass()!, protocolToFind: protocolToFind)
            if foundClass != nil { return foundClass}
            return searchClass
        }
        return searchClass
    }
    
    class func injectSelector(newClass : AnyClass, newSel : Selector, addToClass : AnyClass, makeLikeSel : Selector) {
        var newMeth = class_getInstanceMethod(newClass, newSel)
        let imp = method_getImplementation(newMeth)
        let methodTypeEncoding = method_getTypeEncoding(newMeth)
        let successful = class_addMethod(addToClass, newSel, imp, methodTypeEncoding)
        if !successful {
            class_addMethod(addToClass, newSel, imp, methodTypeEncoding)
            newMeth = class_getInstanceMethod(addToClass, newSel)
            let orgMeth = class_getInstanceMethod(addToClass, makeLikeSel)
            method_exchangeImplementations(orgMeth, newMeth)
        }
    }
    
    
    
    
}




