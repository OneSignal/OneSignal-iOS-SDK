//
//  OneSignal-Location.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation
import CoreLocation 
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
    
    static var lastLocation : os_last_location!
    
    public static func promptLocation() {
        OneSignalLocation.getLocation(self, prompt: true)
    }
    
    static func locationManager(manager: AnyObject, didUpdateLocations locations: [AnyObject]) {
        
        manager.performSelector(NSSelectorFromString("stopUpdatingLocation"))
        
        if location_event_fired == true {
            return
        }
        
        location_event_fired = false
        
        let location = locations.last
        
        var currentLocation = UnsafeMutablePointer<os_last_location>.alloc(sizeof(os_last_location)).memory
        if let vertical = (location?.valueForKey("verticalAccuracy") as? NSNumber)?.doubleValue {
            currentLocation.verticalAccuracy = vertical
        }
        if let horizontal = (location?.valueForKey("horizontalAccuracy") as? NSNumber)?.doubleValue {
            currentLocation.horizontalAccuracy = horizontal
        }
        
        if let cords = location?.valueForKey("coordinate") as? os_location_coordinate { currentLocation.cords = cords }
        
        if userId == nil {
            OneSignal.lastLocation = currentLocation
            return
        }
        
        self.sendLocation(currentLocation)
    }
    
    static func sendLocation(location : os_last_location) {
        
        let request = self.httpClient.requestWithMethod("PUT", path: "players/\(userId!)")
        let dataDic = NSDictionary(objects: [app_id, NSNumber(double: location.cords.latitude), NSNumber(double: location.cords.longitude), NSNumber(double: location.verticalAccuracy), NSNumber(double: location.horizontalAccuracy), getNetType()], forKeys: ["app_id", "lat", "long", "loc_acc_vert", "loc_acc", "net_type"])
        
        var postData : NSData? = nil
        do {
            postData = try NSJSONSerialization.dataWithJSONObject(dataDic, options: NSJSONWritingOptions(rawValue: UInt(0)))
        }
        catch _ { }
        
        request.HTTPBody = postData
        self.enqueueRequest(request, onSuccess: nil, onFailure: nil)
        
    }
    
}
