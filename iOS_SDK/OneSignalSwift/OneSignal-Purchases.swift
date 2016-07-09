//
//  OneSignal-Purchases.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/23/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation
import UIKit

extension OneSignal {
    
    static func sendPurchases(_ purchases: NSArray) {
        if userId == nil {return}
        
        var request = self.httpClient.requestWithMethod("POST", path: "players/\(userId!)/on_purchase")
        let dataDict = ["app_id" : app_id,
                        "purchases" : purchases,
                        ]
        
        var postData : Data? = nil
        do { postData = try JSONSerialization.data(withJSONObject: dataDict, options: JSONSerialization.WritingOptions(rawValue: UInt(0))) }
        catch _ {}
        if postData != nil { request.httpBody = postData!}
        self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
    }

}
