//
//  OSStubLiveActivities.swift
//  OneSignalOSCore
//
//  Created by Elliot Mawby on 3/29/24.
//  Copyright © 2024 Hiptic. All rights reserved.
//

import OneSignalCore

public class OSStubLiveActivities: NSObject, OSLiveActivities {

    @objc
    public static func liveActivities() -> AnyClass {
        return OSStubLiveActivities.self
    }

    public static func enter(_ activityId: String, withToken: String) {
        OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignalLiveActivities not found. In order to use OneSignal's LiveActivities features the OneSignalLiveActivities module must be added.")
    }

    public static func enter(_ activityId: String, withToken: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?) {
        OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignalLiveActivities not found. In order to use OneSignal's LiveActivities features the OneSignalLiveActivities module must be added.")
    }

    public static func exit(_ activityId: String) {
        OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignalLiveActivities not found. In order to use OneSignal's LiveActivities features the OneSignalLiveActivities module must be added.")
    }

    public static func exit(_ activityId: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?) {
        OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignalLiveActivities not found. In order to use OneSignal's LiveActivities features the OneSignalLiveActivities module must be added.")
    }

}
