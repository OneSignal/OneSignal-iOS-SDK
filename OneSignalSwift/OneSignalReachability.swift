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

extension Bool {
    init<T : IntegerType>(_ integer: T){
        self.init(integer != 0)
    }
}

enum NetworkStatus : NSInteger {
    case NotReachable = 0
    case ReachableViaWiFi = 1
    case ReachableViaWWAN = 2
}

class OneSignalReachability : NSObject {
    
    static var alwaysReturnLocalWiFiStatus = false
    static var reachabiliyRef : SCNetworkReachabilityRef!
    
    static func currentReachabilityStatus() -> NetworkStatus {
        assert( reachabiliyRef != nil, "currentNetworkStatus called with NULL SCNetworkReachabilityRef")
        var returnValue : NetworkStatus = .NotReachable
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
        bzero(&zeroAddress, sizeof(sockaddr_in))
        zeroAddress.sin_len = UInt8(sizeof(sockaddr_in))
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
            return Bool(flags.rawValue & SCNetworkReachabilityFlags.ConnectionRequired.rawValue)
        }
        
        return false;
    }
    
    static func reachabilityWithAddress(hostAddress : UnsafePointer<sockaddr>) {
        if let reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress) {
            OneSignalReachability.reachabiliyRef = reachability
            OneSignalReachability.alwaysReturnLocalWiFiStatus = false
        }
    }
    
    //MARK : Network Flag Handling
    
    static func localWifiStatusForFlags(flags : SCNetworkReachabilityFlags) -> NetworkStatus {
        
        var returnValue : NetworkStatus = .NotReachable;
        
        if (flags.rawValue & SCNetworkReachabilityFlags.Reachable.rawValue) != 0 && (flags.rawValue & SCNetworkReachabilityFlags.IsDirect.rawValue) != 0 {
            returnValue = .ReachableViaWiFi
        }
        
        return returnValue
    }
    
    static func networkStatusForFlags(flags : SCNetworkReachabilityFlags) -> NetworkStatus {
        if (flags.rawValue & SCNetworkReachabilityFlags.Reachable.rawValue) == 0 {
            // The target host is not reachable.
            return .NotReachable
        }
        
        var returnValue : NetworkStatus = .NotReachable
        
        if (flags.rawValue & SCNetworkReachabilityFlags.ConnectionRequired.rawValue) == 0 {
            /*
             If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
             */
            returnValue = .ReachableViaWiFi
        }
        
        if (flags.rawValue & SCNetworkReachabilityFlags.ConnectionOnDemand.rawValue)  != 0 ||
            (flags.rawValue & SCNetworkReachabilityFlags.ConnectionOnTraffic.rawValue) != 0
        {
            /*
             ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
             */
            
            if (flags.rawValue & SCNetworkReachabilityFlags.InterventionRequired.rawValue) == 0
            {
                /*
                 ... and no [user] intervention is needed...
                 */
                returnValue = .ReachableViaWiFi
            }
        }
        
        if (flags.rawValue & SCNetworkReachabilityFlags.IsWWAN.rawValue) == SCNetworkReachabilityFlags.IsWWAN.rawValue
        {
            /*
             ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
             */
            returnValue = .ReachableViaWWAN
        }
        
        return returnValue
    }
    
}
