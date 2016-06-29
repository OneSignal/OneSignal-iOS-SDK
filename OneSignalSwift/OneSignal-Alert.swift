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
    
    /* Keeps ARC from cleaning up this object when it goes out of scope since UIAlertView delegate is weak. */
    var delegateReference = NSMutableArray()
    
    init(messageDict : NSDictionary) {
        
        super.init()
        self.messageDict = messageDict
        self.delegateReference.add(self)
    }
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if buttonIndex != 0 {
            
            let userInfo = messageDict.mutableCopy() as! NSMutableDictionary
            
            if messageDict["os_data"] != nil {
                userInfo["actionSelected"] = messageDict["actionButtons"]?[buttonIndex - 1]?["id"]
            }
            else {
                if let customDict = userInfo["custom"] as? NSMutableDictionary {
                    if let a = customDict["a"] as? NSMutableDictionary {
                        let customCopy = customDict.mutableCopy() as! NSMutableDictionary
                        let additionalData = NSMutableDictionary(dictionary: a)
                        additionalData["actionSelected"] = additionalData["actionButtons"]?[buttonIndex - 1]?["id"]
                        customDict["a"] = additionalData
                        userInfo["custom"] = customCopy
                    }
                }
            }
            
            messageDict = userInfo
            
        }
        
        OneSignal.handleNotificationOpened(messageDict, isActive: true)
        delegateReference.remove(self)
    }
}
