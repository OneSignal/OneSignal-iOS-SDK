/**
 * Modified MIT License
 *
 * Copyright 2022 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation

import OneSignalUser
import OneSignalOutcomes
import OneSignalNotifications
import OneSignalCore

public extension OneSignal {
    static var User: OSUser {
        return __user()
    }

    static var Notifications: OSNotifications.Type {
        return __notifications()
    }

    static var Session: OSSession.Type {
        return __session()
    }

    static var InAppMessages: OSInAppMessages.Type {
        return __inAppMessages()
    }

    static var Debug: OSDebug.Type {
        return __debug()
    }

    static var Location: OSLocation.Type {
        return __location()
    }
    
    static var LiveActivities: OSLiveActivities.Type {
        return __liveActivities()
    }  
}

public extension OSDebug {
    static func setAlertLevel(_ logLevel: ONE_S_LOG_LEVEL) {
        __setAlert(logLevel)
    }
}

public extension OSInAppMessages {
    static var paused: Bool {
        get {
            return __paused()
        }
        set {
            __paused(newValue)
        }
    }
    
    static func addLifecycleListener(_ listener: OSInAppMessageLifecycleListener) {
        __add(listener)
    }
    
    static func removeLifecycleListener(_ listener: OSInAppMessageLifecycleListener) {
        __remove(listener)
    }
    
    static func addClickListener(_ listener: OSInAppMessageClickListener) {
        __add(listener)
    }
    
    static func removeClickListener(_ listener: OSInAppMessageClickListener) {
        __remove(listener)
    }
}

public extension OSSession {
    static func addOutcome(_ name: String, _ value: NSNumber) {
        __addOutcome(withValue: name, value: value)
    }
}

public extension OSNotifications {
    static var permission: Bool {
        return __permission()
    }

    static var canRequestPermission: Bool {
        return __canRequestPermission()
    }

    static var permissionNative: OSNotificationPermission {
        return __permissionNative()
    }
    
    static func registerForProvisionalAuthorization(_ block: OSUserResponseBlock?) {
        return __register(forProvisionalAuthorization: block)
    }

    static func addPermissionObserver(_ observer: OSNotificationPermissionObserver) {
        return __add(observer)
    }

    static func removePermissionObserver(_ observer: OSNotificationPermissionObserver) {
        return __remove(observer)
    }
    
    static func addClickListener(_ listener: OSNotificationClickListener) {
        return __add(listener)
    }
    
    static func removeClickListener(_ listener: OSNotificationClickListener) {
        return __remove(listener)
    }
}

public extension OSLocation {
    static var isShared: Bool {
        get {
            return __isShared()
        }
        set {
            __setShared(newValue)
        }
    }
}
