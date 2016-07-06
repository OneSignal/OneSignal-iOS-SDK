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
    
    static var locationManager : AnyObject? = nil
    static var started = false
    static var hasDelayed = false
    
    static func getLocation(_ delegate : AnyObject, prompt : Bool) {
        if hasDelayed {
            internalGetLocation(delegate, prompt:prompt)
        }
        else {

            // Delay required for locationServicesEnabled and authorizationStatus return the correct values when CoreLocation is not staticly linked.
            let popTime = DispatchTime.now() + Double(2 * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
    
            DispatchQueue.main.after(when: popTime, execute: {() -> Void in
                    hasDelayed = true
                    internalGetLocation(delegate, prompt:prompt)
                })
        }

    }
    
    static func internalGetLocation(_ delegate : AnyObject, prompt : Bool) {

        if started {return}
    
        let clLocationManagerClass : AnyClass? = NSClassFromString("CLLocationManager")
        
        
        if clLocationManagerClass == nil {
            OneSignal.onesignal_Log(.ERROR, message: "No CLLocationManager Class. Need to import Core Location first.")
            return
        }
        
        if OneSignalLocationHelper.getLocationServicesEnabled() == false {
            OneSignal.onesignal_Log(.ERROR, message: "Could not implement location services. Make sure to add NSLocationWhenInUseUsageDescription to you Info.plist file.")
            return
        }
        
        if let authStatus = OneSignalLocationHelper.getLocationAuthorizationStatus() {
            if authStatus.int32Value == 0 && !prompt {
                return
            }
        }
        else {
            return
        }
        
        if locationManager == nil {
            locationManager = OneSignalLocationHelper.getLocationManager()
        }
        
        locationManager?.setValue(delegate, forKey: "delegate")
        _ = locationManager?.perform(NSSelectorFromString("requestWhenInUseAuthorization"))
        _ = locationManager?.perform(NSSelectorFromString("startUpdatingLocation"))
        
        started = true
    }

}
