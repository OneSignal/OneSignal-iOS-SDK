//
//  OneSignalHTTPClient.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/21/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

class OneSignalHTTPClient : NSObject, UIApplicationDelegate {
    
    var baseURL : URL!
    
    init(baseURL : URL) {
        super.init()
        self.baseURL = baseURL
    }
    
    func requestWithMethod(_ method: NSString, path : NSString) -> URLRequest {
        let url = URL(string: path as String, relativeTo:self.baseURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = method as String
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.setValue("application/json", forHTTPHeaderField:"Accept")
        return request
    }
    
}
