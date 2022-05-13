//
//  User.swift
//  OneSignal
//
//  Created by Elliot Mawby on 5/13/22.
//  Copyright © 2022 Hiptic. All rights reserved.
//

import Foundation
import OneSignalCore

@objc
public class OneSignalUser: NSObject {
    @objc
    public static func userTest() -> String {
        let testString = "ECM test user"
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: testString)
        return testString
    }
}
