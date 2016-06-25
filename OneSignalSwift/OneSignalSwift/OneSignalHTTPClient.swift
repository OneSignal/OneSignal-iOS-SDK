//
//  OneSignalHTTPClient.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/21/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

class OneSignalHTTPClient : NSObject, UIApplicationDelegate {
    
    var baseURL : NSURL!
    
    init(baseURL : NSURL) {
        super.init()
        self.baseURL = baseURL
    }
    
    func requestWithMethod(method: NSString, path : NSString) -> NSMutableURLRequest {
        let url = NSURL(string: path as String, relativeToURL:self.baseURL)!
        if let uuu = url.absoluteString { OneSignal.onesignal_Log(OneSignal.ONE_S_LOG_LEVEL.ONE_S_LL_VERBOSE, message: "URL_REQUEST: uuu")  }
        
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method as String
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        return request
    }
    
}
