//
//  OneSignal-UNUserNotificationCenterDelegate.swift
//  OneSignal
//
//  Created by Joseph Kalash on 6/30/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 10.0, *)
@objc public protocol OneSignalNotificationCenterDelegate {
    @objc optional func userNotificationCenter(_ center: UNUserNotificationCenter, willPresentNotification notification: UNNotification, withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void);
    @objc optional func userNotificationCenter(_ center: UNUserNotificationCenter, didReceiveNotificationResponse response: UNNotificationResponse, withCompletionHandler completionHandler: () -> Void);
}

@available(iOS 10.0, *)
extension OneSignal : UNUserNotificationCenterDelegate {
    
    /* Object that conforms to UNUserNotificationCenterDelegate */
    @available(iOS 10.0, *)
    @nonobjc public static var notificationCenterDelegate : OneSignalNotificationCenterDelegate? = nil
    
    // The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from applicationDidFinishLaunching:.
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: () -> Void) {
        
        let usrInfo = response.notification.request.content.userInfo
        print("usrInfo: \(usrInfo)")
        
        if usrInfo.count == 0 {
            OneSignal.tunnelToDelegate(center, response: response, handler: completionHandler)
            return
        }
        
        let userInfo = NSMutableDictionary()
        let customDict = NSMutableDictionary()
        let additionalData = NSMutableDictionary()
        let optionsDict = NSMutableArray()
        
        if let os_data = usrInfo["os_data"],
            buttonsDict = os_data["buttons"] as? NSMutableDictionary {
            userInfo.addEntries(from: usrInfo)
            if let o = buttonsDict["o"] as? [[NSObject : AnyObject]] { optionsDict.addObjects(from: o) }
        }
        
        else if let custom = usrInfo["custom"] as? [NSObject : AnyObject] {
            userInfo.addEntries(from: usrInfo)
            customDict.addEntries(from: custom)
            if let a = customDict["a"] as? [NSObject : AnyObject] {
                additionalData.addEntries(from: a)
            }
            if let o = userInfo["o"] as? [[String : String]] {
                optionsDict.addObjects(from: o)
            }
        }
            
        else {
            OneSignal.tunnelToDelegate(center, response: response, handler: completionHandler)
            return
        }
        
        let buttonArray = NSMutableArray()
        for button in optionsDict {
            
            let buttonToAppend : [NSObject : AnyObject] = [
                "text" : button["n"] != nil ? button["n"]!! : "",
                "id" : button["i"] != nil ? button["i"]!! : button["n"]!!
            ]
            
            buttonArray.add(buttonToAppend)
        }
        
        additionalData["actionSelected"] = response.actionIdentifier
        additionalData["actionButtons"] = buttonArray

        
        if let os_data = usrInfo["os_data"] as? [String : AnyObject] {
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
            if let m = userInfo["m"] {
                userInfo["aps"] = ["alert":m]
            }
        }
        
        OneSignal.notificationOpened(userInfo, isActive: UIApplication.shared().applicationState == .active)
        
        OneSignal.tunnelToDelegate(center, response: response, handler: completionHandler)
    }
    
    static func tunnelToDelegate(_ center : UNUserNotificationCenter, response: UNNotificationResponse, handler: ()-> Void) {
        /* Tunnel the delegate call */
        if let delegate = OneSignal.notificationCenterDelegate {
            delegate.userNotificationCenter?(center, didReceiveNotificationResponse: response, withCompletionHandler: handler)
        }
        else {
            //Call the completion handler ourselves
            handler()
        }
    }
    
    // The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void) {
        
        
        /* Nothing interesting to do here, proxy to user only */
        if let delegate = OneSignal.notificationCenterDelegate {
            delegate.userNotificationCenter?(center, willPresentNotification: notification, withCompletionHandler: completionHandler)
        }
        
        else {
            //Call the completion handler ourselves
            completionHandler(UNNotificationPresentationOptions(rawValue: 7))
        }
    }
    
    static func registerAsUNNotificationCenterDelegate() {
        UNUserNotificationCenter.current().delegate = OneSignal.oneSignalObject
    }
    
    @available(iOS 10.0, *)
    static func addnotficationRequest(_ data : [String : AnyObject], userInfo : NSDictionary) {
        let notificationRequest = prepareUNNotificationRequest(data, userInfo : userInfo)
        UNUserNotificationCenter.current().add(notificationRequest, withCompletionHandler: nil)
    }
    
    @available(iOS 10.0, *)
    static func requestAuthorization () {
        UNUserNotificationCenter.current().requestAuthorization(options: UNAuthorizationOptions(rawValue: 7), completionHandler: { (result, error) in })
    }
    
    @available(iOS 10.0, *)
    static func conformsToUNProtocol() {
        if class_conformsToProtocol(UIApplication.appDelegateClass, UNUserNotificationCenterDelegate.self) {
            OneSignal.onesignal_Log(.ERROR, message: "Implementing iOS 10's UNUserNotificationCenterDelegate protocol will result in unexpected outcome. Instead, conform to our similar OneSignalNotificationCenterDelegate protocol.")
        }
    }
    
    
    @available(iOS 10.0, *)
    static func prepareUNNotificationRequest(_ data : [String : AnyObject], userInfo : NSDictionary) -> UNNotificationRequest {
        
        print(userInfo)
        var actionArray : [UNNotificationAction] = []
        if let buttons = data["o"] as? [[String : String]] {
            for button in buttons {
                let title = button["n"] != nil ? button["n"]! : ""
                let identifier = (button["i"] != nil) ? button["i"]! : title
                let action = UNNotificationAction(identifier: identifier, title: title, options: .foreground)
                actionArray.append(action)
            }
        }
        
        if actionArray.count == 2 { actionArray = actionArray.reversed() }
        
        let category = UNNotificationCategory(identifier: "dyanamic", actions: actionArray, minimalActions: [], intentIdentifiers: [], options: UNNotificationCategoryOptions())
        let set = Set<UNNotificationCategory>(arrayLiteral: category)
        UNUserNotificationCenter.current().setNotificationCategories(set)
        
        
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
            content.sound = UNNotificationSound.default()
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
                    let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
                    let filePath = (paths[0] as NSString).appendingPathComponent(name!)
                    let url = URL(fileURLWithPath: filePath)
                    var attachment : UNNotificationAttachment!
                    do { attachment = try UNNotificationAttachment(identifier:id, url: url, options: nil) }
                    catch _ {}
                    if attachment != nil {
                        content.attachments.append(attachment)
                        print("Attachment added")
                    }
                }
                    
                    /* Local in bundle resources */
                else {
                    var files = URI.components(separatedBy: ".")
                    if files.count < 2 {continue}
                    let fileExtension = files.last!
                    files.removeLast()
                    let name = files.joined(separator: ".")
                    // Make sure reesource exists
                    if let url = Bundle.main.urlForResource(name, withExtension: fileExtension) {
                        var attachment : UNNotificationAttachment!
                        do { attachment = try UNNotificationAttachment(identifier:id, url: url, options: nil) }
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
    
}
