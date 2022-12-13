//
//  SwiftTest.swift
//  OneSignalExample
//
//  Created by Elliot Mawby on 12/12/22.
//  Copyright © 2022 OneSignal. All rights reserved.
//

import Foundation
import OneSignalFramework

class SwiftTest: NSObject {
    func testSwiftUserModel() {
        //OneSignal.user()
        OneSignal.User.onJwtExpired { externalId, completion in
            completion("test")
        }
        let token1 = OneSignal.User.pushSubscription.token
        let token = OneSignal.User.pushSubscription.token
    }
}
