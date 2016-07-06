//
//  OneSigna-Tags.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    static func sendTagsWithJSONString(jsonString : NSString) {
        
        let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding)!
        var pairs : NSDictionary? = nil
        do {
            pairs = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: UInt(0))) as? NSDictionary
            if pairs != nil { self.sendTags(pairs!) }
        }
        catch let error as NSError {
            OneSignal.onesignal_Log(.WARN, message: "sendTags JSON Parse Error: \(error)")
            OneSignal.onesignal_Log(.WARN, message: "sendTags JSON Parse Error, JSON: \(jsonString)")
        }
    }
    
    public static func sendTags(keyValuePair : NSDictionary) {
        self.sendTags(keyValuePair, successBlock: nil, failureBlock: nil)
    }
    
    public static func sendTags(keyValuePair : NSDictionary, successBlock : OneSignalResultSuccessBlock?, failureBlock : OneSignalFailureBlock?) {
        
        if NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        if userId == nil {
            if tagsToSend == nil { tagsToSend = NSMutableDictionary(dictionary: keyValuePair) }
            else { tagsToSend.addEntriesFromDictionary(keyValuePair as! [NSObject : AnyObject]) }
            return
        }
        
        let request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId!)")
        
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
    
    public static func sendTag(key : NSString, value : NSString) {
        sendTag(key, value: value, successBlock: nil, failureBlock: nil)
    }
    
    public static func sendTag(key : NSString, value : NSString, successBlock: OneSignalResultSuccessBlock?, failureBlock : OneSignalFailureBlock?) {
        
        sendTags([key : value], successBlock : successBlock, failureBlock : failureBlock)
    }
    
    public static func getTags(successBlock : OneSignalResultSuccessBlock?, failureBlock: OneSignalFailureBlock?) {
        
        if userId == nil || NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        let request = self.httpClient.requestWithMethod("GET", path: "players/\(userId!)")
        self.enqueueRequest(request, onSuccess: { (results) in
            if let tags = results.objectForKey("tags") as? NSDictionary {
                successBlock?(tags)
            }
            }, onFailure: failureBlock)
    }
    
    public static func getTags(successBlock : OneSignalResultSuccessBlock) {
        self.getTags(successBlock, failureBlock: nil)
    }
    
    public static func deleteTag(key : NSString, successBlock : OneSignalResultSuccessBlock, failureBlock : OneSignalFailureBlock) {
        self.deleteTags([key], successBlock: successBlock, failureBlock: failureBlock)
    }
    
    public static func deleteTag(key : NSString) {
        self.deleteTags([key], successBlock: nil, failureBlock: nil)
    }
    
    public static func deleteTags(keys : NSArray, successBlock : OneSignalResultSuccessBlock?, failureBlock : OneSignalFailureBlock?) {
        
        if userId == nil || NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        let request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId!)")
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
    
    public static func deleteTags(keys : NSArray) {
        self.deleteTags(keys, successBlock: nil, failureBlock: nil)
    }
    
    static func deleteTagsWithJSONString(jsonString : NSString) {
        
        let data = jsonString.dataUsingEncoding(NSUTF8StringEncoding)!
        do {
            if let keys = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as? NSArray {
                self.deleteTags(keys)
            }
        }
        catch let error as NSError {
            OneSignal.onesignal_Log(.WARN, message: "deleteTags JSON Parse Error: \(error)");
            OneSignal.onesignal_Log(.WARN, message: "deleteTags JSON Parse Error, JSON: \(jsonString)")
        }
    }
    
    static func setEmail(email : NSString) {
        
        if userId == nil || NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_6_0 { return}
        
        if userId == nil {
            emailToSet = email
            return
        }
        
        let request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId!)")
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

