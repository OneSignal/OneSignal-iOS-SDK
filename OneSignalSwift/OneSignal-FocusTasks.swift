//
//  OneSignal-FocusTasks.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    static func beginBackgroundFocusTask() {
        focusBackgroundTask = UIApplication.shared().beginBackgroundTask(expirationHandler: { self.endBackgroundFocusTask() })
    }
    
    static func endBackgroundFocusTask() {
        UIApplication.shared().endBackgroundTask(focusBackgroundTask)
        focusBackgroundTask = UIBackgroundTaskInvalid
    }
    
    static func onFocus(_ state : NSString) {
        
        var wasBadgeSet = false
        
        if state.isEqual(to: "resume") {
            
            lastTrackedTime = NSNumber(value: Date().timeIntervalSince1970)
            self.sendNotificationTypesUpdateIsConfirmed(false)
      
            wasBadgeSet = clearBadgeCount(false)
        }
        else {
            let timeElapsed = NSNumber(value: (Date().timeIntervalSince1970 - lastTrackedTime.doubleValue + 0.5))
            if timeElapsed.int32Value < 0 || timeElapsed.int32Value > 604800 { return }
            
            let unSentActiveTime = getUnsentActiveTime()
            let totalTimeActive = NSNumber(value : (unSentActiveTime.int32Value + timeElapsed.int32Value))
            if totalTimeActive.int32Value < 30 {
                self.saveUnsentActiveTime(totalTimeActive)
                return
            }
            
            timeToPingWith = totalTimeActive
        }
        
        if userId == nil { return}
        
        // If resuming and badge was set, clear it on the server as well.
        if wasBadgeSet && state.isEqual(to: "resume") {
            
            var request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId!)")
            let dataDict = ["app_id" : app_id,
                            "badge_count" : NSNumber(value: 0),
                            ]
            
            var postData : Data? = nil
            do { postData = try JSONSerialization.data(withJSONObject: dataDict, options: JSONSerialization.WritingOptions(rawValue: UInt(0))) }
            catch _ {}
            if postData != nil { request.httpBody = postData!}
            self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
            return
        }
        
        // Update the playtime on the server when the app put into the background or the device goes to sleep mode.
        if state.isEqual(to: "suspend") {
            self.saveUnsentActiveTime(0)
            DispatchQueue.global(attributes: DispatchQueue.GlobalAttributes.qosDefault).async(execute: {
                self.beginBackgroundFocusTask()
                
                var request = self.httpClient.requestWithMethod("POST", path: "players/\(self.userId!)/on_focus")
                let dataDict = ["app_id" : self.app_id,
                    "state" : "ping",
                    "active_time":self.timeToPingWith,
                    "net_type":self.getNetType()
                ]
                
                var postData : Data? = nil
                do { postData = try JSONSerialization.data(withJSONObject: dataDict, options: JSONSerialization.WritingOptions(rawValue: UInt(0))) }
                catch _ {}
                if postData != nil { request.httpBody = postData!}
                
                // We are already running in a thread so send the request synchronous to keep the thread alive.
                self.enqueueRequest(request, onSuccess: nil, onFailure: nil, isSynchronous: true)
                
                self.endBackgroundFocusTask()
            })
        }
    }
    
    static func getUnsentActiveTime() -> NSNumber {
        if unSentActiveTime.int32Value == -1 {
            if let unsent = UserDefaults.standard().object(forKey: "GT_UNSENT_ACTIVE_TIME") as? NSNumber {
                unSentActiveTime = unsent
            }
            else { unSentActiveTime = 0 }
        }
        return unSentActiveTime
    }
    
    static func saveUnsentActiveTime(_ time : NSNumber) {
        unSentActiveTime = time
        UserDefaults.standard().set(unSentActiveTime, forKey: "GT_UNSENT_ACTIVE_TIME")
        UserDefaults.standard().synchronize()
    }
    
    
}
