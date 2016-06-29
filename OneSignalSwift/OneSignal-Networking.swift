//
//  OneSignal-Networking.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    public static func postNotification(_ jsonData : NSDictionary) {
        self.postNotification(jsonData, onSuccess: nil, onFailure: nil)
    }
    
    public static func postNotification(_ jsonData : NSDictionary, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock : OneSignalFailureBlock?) {
        var request = self.httpClient.requestWithMethod("POST", path: "notifications")
        
        let dataDic = NSMutableDictionary(dictionary: jsonData)
        
        dataDic["app_id"] = self.app_id
        
        var postData : Data? = nil
        do {
            postData = try JSONSerialization.data(withJSONObject: dataDic, options: JSONSerialization.WritingOptions(rawValue: UInt(0)))
        }
        catch _ { }
        
        request.httpBody = postData
        
        self.enqueueRequest(request, onSuccess: { (results) in
            var jsonData : Data? = nil
            do { jsonData = try JSONSerialization.data(withJSONObject: results, options: JSONSerialization.WritingOptions(rawValue: UInt(0))) }
            catch _ {}
            
            let resultsString = NSString(data: jsonData!, encoding: String.Encoding.utf8.rawValue)
            
            OneSignal.onesignal_Log(.one_S_LL_DEBUG, message: "HTTP Create Notification Success \(resultsString!)")
            
            if successBlock != nil {successBlock!(results)}
            
            }) { (error) in
                OneSignal.onesignal_Log(.one_S_LL_ERROR, message: "Create Notification Failed")
                OneSignal.onesignal_Log(.one_S_LL_INFO, message: "\(error)")
                if failureBlock != nil { failureBlock!(error) }
        }
    }
    
    static func postNotificationWithJsonString(_ jsonString : NSString, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock : OneSignalFailureBlock?) {
        
        let data = jsonString.data(using: String.Encoding.utf8.rawValue)
        var jsonData : NSDictionary? = nil
        do { jsonData = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions(rawValue: UInt(0))) as? NSDictionary }
        catch let error as NSError {
            OneSignal.onesignal_Log(.one_S_LL_WARN, message: "postNotification JSON Parse Error: \(error)")
            OneSignal.onesignal_Log(.one_S_LL_WARN, message: "postNotification JSON Parse Error, JSON: \(jsonString)")
            return
        }
        
        self.postNotification(jsonData!, onSuccess: successBlock, onFailure: failureBlock)
    }
    
    static func enqueueRequest(_ request : URLRequest, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock : OneSignalFailureBlock?) {
        self.enqueueRequest(request, onSuccess: successBlock, onFailure: failureBlock, isSynchronous: false)
    }
    
    static func enqueueRequest(_ request : URLRequest, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock : OneSignalFailureBlock?, isSynchronous : Bool) {
        
       // OneSignal.onesignal_Log(..ONE_S_LL_VERBOSE, message: "request.body: \(NSString(data: request.HTTPBody!, encoding: NSUTF8StringEncoding)!)")
        
            var response : URLResponse?
            var err : NSError?
            do {
                if isSynchronous { try NSURLConnection.sendSynchronousRequest(request, returning: &response) }
                else {
                    NSURLConnection.sendAsynchronousRequest(request, queue: OperationQueue(), completionHandler: { (response, data, error) in
                        self.handleJSONNSURLResponse(response, data: data, error: error, onSuccess: successBlock, onFailure: failureBlock)
                    })
                }
            }
            catch let error as NSError {
                err = error
            }
        
        if isSynchronous { handleJSONNSURLResponse(response, data: nil, error: err, onSuccess: successBlock, onFailure: failureBlock) }
        
    }
    
    static func handleJSONNSURLResponse(_ response : URLResponse?, data : Data?, error : NSError?, onSuccess successBlock : OneSignalResultSuccessBlock?, onFailure failureBlock : OneSignalFailureBlock?) {
        
        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode
        var innerJson : NSMutableDictionary? = nil
        
        if data != nil && data?.count > 0 {
            do { innerJson = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions(rawValue: UInt(0))) as? NSMutableDictionary }
            catch let jsonError as NSError {
                if failureBlock != nil {
                    failureBlock!(NSError(domain: "OneSignalError", code: statusCode!, userInfo: ["returned" : jsonError]))
                }
                return
            }
            
            if 200 == statusCode && error == nil {
                if successBlock != nil {
                    if innerJson != nil { successBlock!(innerJson!) }
                    else { successBlock!([:]) }
                }
            }
            else if failureBlock != nil {
                if innerJson != nil && error == nil {
                    failureBlock!(NSError(domain: "OneSignalError", code: statusCode!, userInfo: ["returned" : innerJson!]))
                }
                else if error != nil {
                    failureBlock!(NSError(domain: "OneSignalError", code: statusCode!, userInfo: ["error" : error!]))
                }
                else {
                    failureBlock!(NSError(domain: "OneSignalError", code: statusCode!, userInfo: nil))
                }
            }
            
        }
    }
    
}
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
