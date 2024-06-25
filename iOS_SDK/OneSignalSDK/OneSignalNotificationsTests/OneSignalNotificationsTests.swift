//
//  OneSignalNotificationsTests.swift
//  OneSignalNotificationsTests
//
//  Created by Elliot Mawby on 6/17/24.
//  Copyright © 2024 Hiptic. All rights reserved.
//

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

    func testClearBadgesWhenAppEntersForeground() throws {
        // NotificationManager Start to register lifecycle listener
        OSNotificationsManager.start()
        // Set badge count > 0
        UIApplication.shared.applicationIconBadgeNumber = 1
        // Then background the app
        OneSignalCoreMocks.backgroundApp()
        // Foreground the app
        OneSignalCoreMocks.foregroundApp()
        // Ensure that badge count == 0
        XCTAssertEqual(UIApplication.shared.applicationIconBadgeNumber, 0)
    }

    func testDontclearBadgesWhenAppBecomesActive() throws {
        // NotificationManager Start to register lifecycle listener
        OSNotificationsManager.start()
        // Set badge count > 0
        UIApplication.shared.applicationIconBadgeNumber = 1
        // Then resign active
        OneSignalCoreMocks.resignActive()
        // App becomes active the app
        OneSignalCoreMocks.becomeActive()
        // Ensure that badge count == 0
        XCTAssertEqual(UIApplication.shared.applicationIconBadgeNumber, 1)
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
