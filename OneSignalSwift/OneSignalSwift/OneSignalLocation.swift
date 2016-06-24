//
//  OneSignalLocation.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/21/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

// CoreLocation must be statically linked for geotagging to work on iOS 6 and possibly 7.
// plist NSLocationUsageDescription (iOS 6 & 7) and NSLocationWhenInUseUsageDescription (iOS 8+) keys also required.

// Suppressing undeclared selector warnings
// NSClassFromString and performSelector are used so OneSignal does not depend on CoreLocation to link the app.
class OneSignalLocation : NSObject {
    
    static var locationManager : AnyObject?
    static var started = false
    static var hasDelayed = false
    
    class func getLocation(delegate : AnyObject, prompt : Bool) {
        if hasDelayed {
            OneSignalLocation.internalGetLocation(delegate, prompt:prompt)
        }
        else {
            // Delay required for locationServicesEnabled and authorizationStatus return the correct values when CoreLocation is not staticly linked.
            let popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * Int64(NSEC_PER_SEC))
            dispatch_after(popTime, dispatch_get_main_queue(), {() -> Void in
                    hasDelayed = true
                    OneSignalLocation.internalGetLocation(delegate, prompt:prompt)
                })
        }
        
    }
    
    class func internalGetLocation(delegate : AnyObject, prompt : Bool) {
        
        if started {return}
        
        let clLocationManagerClass : AnyClass? = NSClassFromString("CLLocationManager")
        
        if (clLocationManagerClass as? NSObjectProtocol)?.performSelector(NSSelectorFromString("locationServicesEnabled")).takeUnretainedValue() as? Bool != true {return}
        
        if (clLocationManagerClass as? NSObjectProtocol)?.performSelector(NSSelectorFromString("authorizationStatus")).takeUnretainedValue() as? Int32 == 0 && prompt == false {return}
        
        // Check for location in plist
        if (clLocationManagerClass as! NSObjectProtocol).performSelector(NSSelectorFromString("locationServicesEnabled")) == nil { return }
        
        if (clLocationManagerClass as! NSObjectProtocol).performSelector(NSSelectorFromString("authorizationStatus")) == nil && !prompt { return }

        
        locationManager = clLocationManagerClass?.alloc()
        locationManager?.setValue(delegate, forKey: "delegate")
        if (UIDevice.currentDevice().systemVersion as NSString).floatValue >= 8.0 {
            locationManager?.performSelector(NSSelectorFromString("requestWhenInUseAuthorization"))
        }
        
        locationManager?.performSelector(NSSelectorFromString("startUpdatingLocation"))
        
        started = true
    }

}
