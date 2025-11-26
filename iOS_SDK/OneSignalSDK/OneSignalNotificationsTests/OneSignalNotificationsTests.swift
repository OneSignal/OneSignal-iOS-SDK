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

import XCTest
import OneSignalNotifications
import OneSignalCoreMocks
import UIKit

final class OneSignalNotificationsTests: XCTestCase {

    var notifTypes: Int32 = 0
    var token: String = ""

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.notifTypes = 0
        self.token = ""
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Helper to get cached badge count from OneSignalUserDefaults
    private func getCachedBadgeCount() -> Int {
        return OneSignalUserDefaults.initShared().getSavedInteger(forKey: "onesignalBadgeCount", defaultValue: 0)
    }

    /// Helper to set badge count
    private func setBadgeCount(_ count: Int, completion: @escaping () -> Void = {}) {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error = error {
                    XCTFail("Failed to set badge count: \(error)")
                }
                completion()
            }
        } else {
            // Fallback for iOS 15 and earlier
            UIApplication.shared.applicationIconBadgeNumber = count
            completion()
        }
    }

    func testClearBadgesWhenAppEntersForeground() throws {
        // NotificationManager Start to register lifecycle listener
        OSNotificationsManager.start()
        // Set badge count > 0
        let expectation = self.expectation(description: "Badge set")
        setBadgeCount(1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)

        // Verify badge was set
        XCTAssertEqual(getCachedBadgeCount(), 1)

        // Then background the app
        OneSignalCoreMocks.backgroundApp()
        // Foreground the app
        OneSignalCoreMocks.foregroundApp()

        // Wait for async badge clearing on iOS 16+
        Thread.sleep(forTimeInterval: 0.1)

        // Ensure that badge count == 0
        XCTAssertEqual(getCachedBadgeCount(), 0)
    }

    func testDontclearBadgesWhenAppBecomesActive() throws {
        // NotificationManager Start to register lifecycle listener
        OSNotificationsManager.start()
        // Set badge count > 0
        let expectation = self.expectation(description: "Badge set")
        setBadgeCount(1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)

        // Verify badge was set
        XCTAssertEqual(getCachedBadgeCount(), 1)

        // Then resign active
        OneSignalCoreMocks.resignActive()
        // App becomes active the app
        OneSignalCoreMocks.becomeActive()

        // Wait for async badge clearing on iOS 16+
        Thread.sleep(forTimeInterval: 0.1)

        // Ensure that badge count == 1
        XCTAssertEqual(getCachedBadgeCount(), 1)
    }

    func testUpdateNotificationTypesOnAppEntersForeground() throws {
        // NotificationManager Start to register lifecycle listener
        OSNotificationsManager.start()

        OSNotificationsManager.delegate = self

        XCTAssertEqual(self.notifTypes, 0)

        // Then background the app
        OneSignalCoreMocks.backgroundApp()

        // Foreground the app for within 30 seconds
        OneSignalCoreMocks.foregroundApp()

        // Ensure that the delegate is updated with the new notification type
        XCTAssertEqual(self.notifTypes, ERROR_PUSH_NEVER_PROMPTED)
    }

}

extension OneSignalNotificationsTests: OneSignalNotificationsDelegate {
    public func setNotificationTypes(_ notificationTypes: Int32) {
        self.notifTypes = notificationTypes
    }

    public func setPushToken(_ pushToken: String) {
        self.token = pushToken
    }
}
