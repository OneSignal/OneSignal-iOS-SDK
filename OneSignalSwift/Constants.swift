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

enum NotificationType : Int {
    case Badge = 1
    case Douns = 2
    case Alert = 4
    case All = 7
}
