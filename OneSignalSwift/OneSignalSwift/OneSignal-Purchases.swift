//
//  OneSignal-Purchases.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    func sendPurchases(purchases: NSArray) {
        if userId == nil {return}
        
        let request = self.httpClient.requestWithMethod("POST", path: "players/\(userId!)/on_purchase")
        let dataDict = ["app_id" : app_id,
                        "purchases" : purchases,
                        ]
        
        var postData : NSData? = nil
        do { postData = try NSJSONSerialization.dataWithJSONObject(dataDict, options: NSJSONWritingOptions(rawValue: UInt(0))) }
        catch _ {}
        if postData != nil { request.HTTPBody = postData!}
        self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
    }

}
