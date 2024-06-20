/*
 Modified MIT License
 Copyright 2024 OneSignal
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import Foundation
import OneSignalCore
import XCTest

@objc
public class OneSignalCoreMocks: NSObject {
    @objc
    public static func clearUserDefaults() {
        guard let userDefaults = OneSignalUserDefaults.initStandard().userDefaults else {
            return
        }
        let dictionary = userDefaults.dictionaryRepresentation()
        for key in dictionary.keys {
            userDefaults.removeObject(forKey: key)
        }

        guard let sharedUserDefaults = OneSignalUserDefaults.initShared().userDefaults else {
            return
        }
        let sharedDictionary = sharedUserDefaults.dictionaryRepresentation()
        for key in sharedDictionary.keys {
            sharedUserDefaults.removeObject(forKey: key)
        }
    }

    /** Wait specified number of seconds for any async methods to run */
    @objc
    public static func waitForBackgroundThreads(seconds: Double) {
        let expectation = XCTestExpectation(description: "Wait for \(seconds) seconds")
        _ = XCTWaiter.wait(for: [expectation], timeout: seconds)
    }
    
    @objc public static func backgroundApp() {
        if (OSBundleUtils.isAppUsingUIScene()) {
            if #available(iOS 13.0, *) {
                NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: nil)
                NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: nil)
            }
        } else {
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
    }
    
    @objc public static func foregroundApp() {
        if (OSBundleUtils.isAppUsingUIScene()) {
            if #available(iOS 13.0, *) {
                NotificationCenter.default.post(name: UIScene.willEnterForegroundNotification, object: nil)
                NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
            }
        } else {
            NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
    
    @objc public static func resignActive() {
        if (OSBundleUtils.isAppUsingUIScene()) {
            if #available(iOS 13.0, *) {
                NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: nil)
            }
        } else {
            NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        }
    }
    
    @objc public static func becomeActive() {
        if (OSBundleUtils.isAppUsingUIScene()) {
            if #available(iOS 13.0, *) {
                NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)
            }
        } else {
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }
}
