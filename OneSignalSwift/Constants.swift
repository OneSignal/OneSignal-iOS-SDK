//
//  Constants.swift
//  OneSignal
//
//  Created by Joseph Kalash on 7/1/16.
//  Copyright © 2016 Joseph Kalash. All rights reserved.
//

import Foundation


let ONESIGNAL_VERSION = "011303"
let DEFAULT_PUSH_HOST = "https://onesignal.com/api/v1/"

public typealias OneSignalResultSuccessBlock = (NSDictionary) -> Void
public typealias OneSignalFailureBlock = (NSError) -> Void
public typealias OneSignalIdsAvailableBlock = (NSString, NSString?) -> Void
public typealias OneSignalHandleNotificationBlock = (NSString, NSDictionary, Bool) -> Void

public enum ONE_S_LOG_LEVEL : Int {
    case NONE = 0
    case FATAL = 1
    case ERROR = 2
    case WARN = 3
    case INFO = 4
    case DEBUG = 5
    case VERBOSE = 6
}

enum NotificationType : Int {
    case Badge = 1
    case Douns = 2
    case Alert = 4
    case All = 7
}
