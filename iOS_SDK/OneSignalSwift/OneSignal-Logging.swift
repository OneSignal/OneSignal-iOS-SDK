//
//  OneSignal-Logging.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

extension OneSignal {
    
    public static func setLogLevel(_ nslogLevel : ONE_S_LOG_LEVEL, visualLevel visualLogLevel : ONE_S_LOG_LEVEL) {
        self.nsLogLevel = nslogLevel
        self.visualLogLevel = visualLogLevel
    }
    
    public static func onesignal_Log(_ logLevel : ONE_S_LOG_LEVEL, message : String) {
        
        var levelString = ""
        
        switch logLevel {
            case .FATAL: levelString = "FATAL: "
            case .ERROR: levelString = "ERROR: "
            case .WARN: levelString = "WARN: "
            case .INFO: levelString = "INFO: "
            case .DBG: levelString = "DEBUG: "
            case .VERBOSE: levelString = "VERBOSE: "
            default: break
        }

        if logLevel.rawValue <= nsLogLevel.rawValue && nsLogLevel != .none  { print("\(levelString)\(message)")}
        
        if logLevel.rawValue <= visualLogLevel.rawValue && visualLogLevel != .none {
            let alert = UIAlertView(title: levelString, message: message, delegate: nil, cancelButtonTitle: "Close")
            alert.show()
        }
        
    }
    
}
