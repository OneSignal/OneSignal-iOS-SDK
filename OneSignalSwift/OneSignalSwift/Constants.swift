//
//  Constants.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

let ONESIGNAL_VERSION = "011303"
let DEFAULT_PUSH_HOST = "https://onesignal.com/api/v1/"

enum NotificationType : Int {
    case Badge = 1
    case Douns = 2
    case Alert = 4
    case All = 7
}
