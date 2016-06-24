//
//  OneSignal-FocusTasks.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    func beginBackgroundFocusTask() {
        focusBackgroundTask = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ self.endBackgroundFocusTask() })
    }
    
    func endBackgroundFocusTask() {
        UIApplication.sharedApplication().endBackgroundTask(focusBackgroundTask)
        focusBackgroundTask = UIBackgroundTaskInvalid
    }
    
    func onFocus(state : NSString) {
        
        var wasBadgeSet = false
        
        if state.isEqualToString("resume") {
            
            lastTrackedTime = NSNumber(double: NSDate().timeIntervalSince1970)
            self.sendNotificationTypesUpdateIsConfirmed(false)
            wasBadgeSet = clearBadgeCount(false)
        }
        else {
            let timeElapsed = NSNumber(double: (NSDate().timeIntervalSince1970 - lastTrackedTime.doubleValue + 0.5))
            if timeElapsed.intValue < 0 || timeElapsed.intValue > 604800 { return }
            
            let unSentActiveTime = getUnsentActiveTime()
            let totalTimeActive = NSNumber(int : (unSentActiveTime.intValue + timeElapsed.intValue))
            if totalTimeActive.intValue < 30 {
                self.saveUnsentActiveTime(totalTimeActive)
                return
            }
            
            timeToPingWith = totalTimeActive
        }
        
        if userId == nil { return}
        
        // If resuming and badge was set, clear it on the server as well.
        if wasBadgeSet && state.isEqualToString("resume") {
            
            let request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId!)")
            let dataDict = ["app_id" : app_id,
                            "badge_count" : NSNumber(int: 0),
                            ]
            
            var postData : NSData? = nil
            do { postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0))) }
            catch _ {}
            if postData != nil { request.HTTPBody = postData!}
            self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
            return
        }
        
        // Update the playtime on the server when the app put into the background or the device goes to sleep mode.
        if state.isEqualToString("suspend") {
            self.saveUnsentActiveTime(0)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                self.beginBackgroundFocusTask()
                
                let request = self.httpClient.requestWithMethod("POST", path: "players/\(self.userId!)/on_focus")
                let dataDict = ["app_id" : self.app_id,
                    "state" : "ping",
                    "active_time":self.timeToPingWith,
                    "net_type":self.getNetType()
                ]
                
                var postData : NSData? = nil
                do { postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0))) }
                catch _ {}
                if postData != nil { request.HTTPBody = postData!}
                
                // We are already running in a thread so send the request synchronous to keep the thread alive.
                self.enqueueRequest(request, onSuccess: nil, onFailure: nil, isSynchronous: true)
                
                self.endBackgroundFocusTask()
            })
        }
    }
    
    func getUnsentActiveTime() -> NSNumber {
        if unSentActiveTime.intValue == -1 {
            if let unsent = NSUserDefaults.standardUserDefaults().objectForKey("GT_UNSENT_ACTIVE_TIME") as? NSNumber {
                unSentActiveTime = unsent
            }
            else { unSentActiveTime = 0 }
        }
        return unSentActiveTime
    }
    
    func saveUnsentActiveTime(time : NSNumber) {
        unSentActiveTime = time
        NSUserDefaults.standardUserDefaults().setObject(unSentActiveTime, forKey: "GT_UNSENT_ACTIVE_TIME")
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    
}
