//
//  OneSignalJailbreakDetection.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/21/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

class OneSignalJailbreakDetection : NSObject {
    
    static func isJailbroken() -> Bool {
        return NSFileManager.defaultManager().fileExistsAtPath("/private/var/lib/apt/")
    }
}
