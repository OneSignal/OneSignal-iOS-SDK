//
//  OneSignalReachability.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/21/16.
//  Copyright © 2016 One Signal. All rights reserved.
//

import Foundation
import SystemConfiguration
import CoreFoundation
import Darwin
import UIKit

extension Bool {
    init<T : Integer>(_ integer: T){
        self.init(integer != 0)
    }
}

enum NetworkStatus : NSInteger {
    case notReachable = 0
    case reachableViaWiFi = 1
    case reachableViaWWAN = 2
}

class OneSignalReachability : NSObject {
    
    static var alwaysReturnLocalWiFiStatus = false
    static var reachabiliyRef : SCNetworkReachability!
    
    static func currentReachabilityStatus() -> NetworkStatus {
        assert( reachabiliyRef != nil, "currentNetworkStatus called with NULL SCNetworkReachabilityRef")
        var returnValue : NetworkStatus = .notReachable
        var flags = SCNetworkReachabilityFlags()
        
        if SCNetworkReachabilityGetFlags(reachabiliyRef, &flags) {
            if alwaysReturnLocalWiFiStatus { returnValue = self.localWifiStatusForFlags(flags) }
            else { returnValue = self.networkStatusForFlags(flags) }
        }
        
        return returnValue
    }
    
    /*!
     * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
     */
    static func reachabilityForInternetConnection() {
        var zeroAddress = sockaddr_in()
        bzero(&zeroAddress, sizeof(sockaddr_in.self))
        zeroAddress.sin_len = UInt8(sizeof(sockaddr_in.self))
        zeroAddress.sin_family = UInt8(AF_INET)
        
        let _ = withUnsafePointer(&zeroAddress) { self.reachabilityWithAddress(UnsafePointer($0))}
        
    }
    
    /*!
     * WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
     */
    static func connectionRequired() -> Bool {
        assert(reachabiliyRef != nil, "connectionRequired called with NULL reachabilityRef")
        var flags =  SCNetworkReachabilityFlags()
        
        if (SCNetworkReachabilityGetFlags(reachabiliyRef, &flags)) {
            return Bool(flags.rawValue & SCNetworkReachabilityFlags.connectionRequired.rawValue)
        }
        
        return false;
    }
    
    static func reachabilityWithAddress(_ hostAddress : UnsafePointer<sockaddr>) {
        if let reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress) {
            OneSignalReachability.reachabiliyRef = reachability
            OneSignalReachability.alwaysReturnLocalWiFiStatus = false
        }
    }
    
    //MARK : Network Flag Handling
    
    static func localWifiStatusForFlags(_ flags : SCNetworkReachabilityFlags) -> NetworkStatus {
        
        var returnValue : NetworkStatus = .notReachable;
        
        if (flags.rawValue & SCNetworkReachabilityFlags.reachable.rawValue) != 0 && (flags.rawValue & SCNetworkReachabilityFlags.isDirect.rawValue) != 0 {
            returnValue = .reachableViaWiFi
        }
        
        return returnValue
    }
    
    static func networkStatusForFlags(_ flags : SCNetworkReachabilityFlags) -> NetworkStatus {
        if (flags.rawValue & SCNetworkReachabilityFlags.reachable.rawValue) == 0 {
            // The target host is not reachable.
            return .notReachable
        }
        
        var returnValue : NetworkStatus = .notReachable
        
        if (flags.rawValue & SCNetworkReachabilityFlags.connectionRequired.rawValue) == 0 {
            /*
             If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
             */
            returnValue = .reachableViaWiFi
        }
        
        if (flags.rawValue & SCNetworkReachabilityFlags.connectionOnDemand.rawValue)  != 0 ||
            (flags.rawValue & SCNetworkReachabilityFlags.connectionOnTraffic.rawValue) != 0
        {
            /*
             ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
             */
            
            if (flags.rawValue & SCNetworkReachabilityFlags.interventionRequired.rawValue) == 0
            {
                /*
                 ... and no [user] intervention is needed...
                 */
                returnValue = .reachableViaWiFi
            }
        }
        
        if (flags.rawValue & SCNetworkReachabilityFlags.isWWAN.rawValue) == SCNetworkReachabilityFlags.isWWAN.rawValue
        {
            /*
             ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
             */
            returnValue = .reachableViaWWAN
        }
        
        return returnValue
    }
    
}
