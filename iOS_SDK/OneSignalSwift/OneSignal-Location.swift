//
//  OneSignal-Location.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

extension OneSignal  {
    
    struct os_location_coordinate {
        var latitude : Double
        var longitude : Double
    }
    
    struct os_last_location {
        var cords : os_location_coordinate
        var verticalAccuracy : Double
        var horizontalAccuracy : Double
    }
    
    public static func promptLocation() {
        OneSignalLocation.getLocation(self, prompt: true)
    }
    
    static func locationManager(_ manager: AnyObject, didUpdateLocations locations: [AnyObject]) {
        
        let _ = manager.perform(NSSelectorFromString("stopUpdatingLocation"))
        
        if location_event_fired == true {
            return
        }
        
        location_event_fired = false
        
        let location = locations.last

        var currentLocation = UnsafeMutablePointer<os_last_location>(allocatingCapacity: sizeof(os_last_location.self)).pointee
        if let vertical = (location?.value(forKey: "verticalAccuracy") as? NSNumber)?.doubleValue {
            currentLocation.verticalAccuracy = vertical
        }
        if let horizontal = (location?.value(forKey: "horizontalAccuracy") as? NSNumber)?.doubleValue {
            currentLocation.horizontalAccuracy = horizontal
        }
        
        if let cords = location?.value(forKey: "coordinate") as? os_location_coordinate { currentLocation.cords = cords }
        
        if userId == nil {
            OneSignal.lastLocation = currentLocation
            return
        }
        
        self.sendLocation(currentLocation)
    }
    
    static func sendLocation(_ location : os_last_location) {
        
        var request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId!)")
        let dataDic = NSDictionary(objects: [app_id, NSNumber(value: location.cords.latitude), NSNumber(value: location.cords.longitude), NSNumber(value: location.verticalAccuracy), NSNumber(value: location.horizontalAccuracy), getNetType()], forKeys: ["app_id", "lat", "long", "loc_acc_vert", "loc_acc", "net_type"])
        
        var postData : Data? = nil
        do {
            postData = try JSONSerialization.data(withJSONObject: dataDic, options: JSONSerialization.WritingOptions(rawValue: UInt(0)))
        }
        catch _ { }
        
        request.httpBody = postData
        
        self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
        
    }
    
    
}
