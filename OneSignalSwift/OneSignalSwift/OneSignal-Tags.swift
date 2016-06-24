//
//  OneSigna-Tags.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    func sendTagsWithJSONString(jsonString : NSString) {
        
        let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding)!
        var pairs : NSDictionary? = nil
        do {
            pairs = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: UInt(0))) as? NSDictionary
            if pairs != nil { self.sendTagsWithKeyValuePair(pairs!) }
        }
        catch let error as NSError {
            onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_WARN, message: "sendTags JSON Parse Error: \(error)")
            onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_WARN, message: "sendTags JSON Parse Error, JSON: \(jsonString)")
        }
    }
    
    func sendTagsWithKeyValuePair(keyValuePair : NSDictionary) {
        self.sendTagsWithKeyValuePair(keyValuePair, onSuccess: nil, onFailure: nil)
    }
    
    func sendTagsWithKeyValuePair(keyValuePair : NSDictionary, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock : OneSignalFailureBlock?) {
        
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        if userId == nil {
            if tagsToSend == nil { tagsToSend = NSMutableDictionary(dictionary: keyValuePair) }
            else { tagsToSend.addEntriesFromDictionary(keyValuePair as! [NSObject : AnyObject]) }
            return
        }
        
        let request = self.httpClient.requestWithMethod("POST", path: "players/\(userId)")
        
        let dataDict = ["app_id" : app_id,
                        "tags" : keyValuePair,
                        "net_type" : getNetType()
                    ]
        
        var postData : NSData? = nil
        do { postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0))) }
        catch _ {}
        if postData != nil { request.HTTPBody = postData!}
        self.enqueueRequest(request, onSuccess: successBlock, onFailure: failureBlock)
    }
    
    func sendTag(key : NSString, value : NSString) {
        sendTag(key, value: value, onSuccess: nil, onFailure: nil)
    }
    
    func sendTag(key : NSString, value : NSString, onSuccess successBlock: OneSignalResultSuccessBlock?, onFailure failureBlock : OneSignalFailureBlock?) {
        
        sendTagsWithKeyValuePair([key : value], onSuccess : successBlock, onFailure : failureBlock)
    }
    
    func getTags(onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock: OneSignalFailureBlock?) {
        
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        let request = self.httpClient.requestWithMethod("GET", path: "players/\(userId)")
        self.enqueueRequest(request, onSuccess: { (results) in
            if let tags = results.objectForKey("tags") as? NSDictionary {
                successBlock?(tags)
            }
            }, onFailure: failureBlock)
    }
    
    func getTags(onSuccess successBlock : OneSignalResultSuccessBlock) {
        self.getTags(onSuccess: successBlock, onFailure: nil)
    }
    
    func deleteTag(key : NSString, onSuccess successBlock : OneSignalResultSuccessBlock, onFailure failureBlock : OneSignalFailureBlock) {
        self.deleteTags([key], onSuccess: successBlock, onFailure: failureBlock)
    }
    
    func deleteTag(key : NSString) {
        self.deleteTags([key], onSuccess: nil, onFailure: nil)
    }
    
    func deleteTags(keys : NSArray, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock : OneSignalFailureBlock?) {
        
        if userId == nil || NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        let request = self.httpClient.requestWithMethod("POST", path: "players/\(userId)")
        let tagsToDeleteDict = NSMutableDictionary()
        for key in keys as! [String] {
            tagsToDeleteDict[key] = ""
        }
        
        let dataDict = ["app_id" : app_id, "tags" : tagsToDeleteDict]
        var postData : NSData? = nil
        do { postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0))) }
        catch _ {}
        if postData != nil { request.HTTPBody = postData!}
        self.enqueueRequest(request, onSuccess: successBlock, onFailure: failureBlock)
        
        
    }
    
    func deleteTags(keys : NSArray) {
        self.deleteTags(keys, onSuccess: nil, onFailure: nil)
    }
    
    func deleteTagsWithJSONString(jsonString : NSString) {
        
        let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding)!
        do {
            if let keys = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? NSArray {
                self.deleteTags(keys)
            }
        }
        catch let error as NSError {
            onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_WARN, message: "deleteTags JSON Parse Error: \(error)");
            onesignal_Log(ONE_S_LOG_LEVEL.ONE_S_LL_WARN, message: "deleteTags JSON Parse Error, JSON: \(jsonString)")
        }
    }
    
    func setEmail(email : NSString) {
        
        if userId == nil || NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        if userId == nil {
            emailToSet = email
            return
        }
        
        let request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId)")
        let dataDict = ["app_id" : app_id,
                        "email" : email,
                        "net_type" : getNetType()
        ]
        
        var postData : NSData? = nil
        do { postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0))) }
        catch _ {}
        if postData != nil { request.HTTPBody = postData!}
        self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
    }
    
    
    
    
    
    
    
    
}

















