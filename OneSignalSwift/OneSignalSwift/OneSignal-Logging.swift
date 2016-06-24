//
//  OneSignal-Logging.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    enum ONE_S_LOG_LEVEL : Int {
        case ONE_S_LL_NONE
        case ONE_S_LL_FATAL
        case ONE_S_LL_ERROR
        case ONE_S_LL_WARN
        case ONE_S_LL_INFO
        case ONE_S_LL_DEBUG
        case ONE_S_LL_VERBOSE
    }
    
    static var nsLogLevel = ONE_S_LOG_LEVEL.ONE_S_LL_WARN
    static var visualLogLevel = ONE_S_LOG_LEVEL.ONE_S_LL_NONE
    
    
    class func setLogLevel(nslogLevel : ONE_S_LOG_LEVEL, visualLevel visualLogLevel : ONE_S_LOG_LEVEL) {
        OneSignal.nsLogLevel = nslogLevel
        OneSignal.visualLogLevel = visualLogLevel
    }
    
    class func onesignal_Log(logLevel : ONE_S_LOG_LEVEL, message : NSString) {
        onesignal_Log(logLevel, message: message)
    }
    
    func onesignal_Log(logLevel : ONE_S_LOG_LEVEL, message : String) {
        var levelString = ""
        
        switch logLevel {
            case .ONE_S_LL_FATAL: levelString = "FATAL: "
            case .ONE_S_LL_ERROR: levelString = "ERROR: "
            case .ONE_S_LL_WARN: levelString = "WARN: "
            case .ONE_S_LL_INFO: levelString = "INFO: "
            case .ONE_S_LL_DEBUG: levelString = "DEBUG: "
            case .ONE_S_LL_VERBOSE: levelString = "VERBOSE: "
            default: break
        }
        
        if logLevel.rawValue <= OneSignal.nsLogLevel.rawValue { print("\(levelString)\(message)") }
        
        if logLevel.rawValue <= OneSignal.visualLogLevel.rawValue {
            let alert = UIAlertView(title: levelString, message: message, delegate: nil, cancelButtonTitle: "Close")
            alert.show()
        }
        
    }
    
}
