//
//  OneSignal-Alert.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation


class OneSignalAlertViewDelegate : NSObject, UIAlertViewDelegate {
    
    var messageDict : NSDictionary!
    var oneSignal : OneSignal!
    
    /* Keeps ARC from cleaning up this object when it goes out of scope since UIAlertView delegate is weak. */
    static var delegateReference : NSMutableArray!
    
    init(messageDict : NSDictionary, oneSignal : OneSignal) {
        
        super.init()
        
        self.messageDict = messageDict
        self.oneSignal = oneSignal
        
        if OneSignalAlertViewDelegate.delegateReference == nil {
            OneSignalAlertViewDelegate.delegateReference = NSMutableArray()
        }
        
        OneSignalAlertViewDelegate.delegateReference.addObject(self)
    }
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex != 0 {
            
            let userInfo = messageDict.mutableCopy() as! NSMutableDictionary
            
            if messageDict["os_data"] != nil {
                userInfo["actionSelected"] = messageDict["actionButtons"]?[buttonIndex - 1]?["id"]
            }
            else {
                if let customDict = userInfo["custom"]?.mutableCopy() as? NSMutableDictionary, a = customDict["a"] as? NSMutableDictionary {
                    let additionalData = NSMutableDictionary(dictionary: a)
                    additionalData["actionSelected"] = additionalData["actionButtons"]?[buttonIndex - 1]?["id"]
                    customDict["a"] = additionalData
                    userInfo["custom"] = customDict
                }
            }
            
            messageDict = userInfo
            
        }
        
    
        oneSignal.handleNotificationOpened(messageDict, isActive: true)
        OneSignalAlertViewDelegate.delegateReference.removeObject(self)
        
    }
}
