//
//  OneSignalNotificationsTests.swift
//  OneSignalNotificationsTests
//
//  Created by Elliot Mawby on 6/17/24.
//  Copyright © 2024 Hiptic. All rights reserved.
//

import XCTest

final class OneSignalNotificationsTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testClearBadgesWhenAppEntersForeground() throws {
        // NotificationManager Start? Or Mock NotificationManager start
        // Mock receive a notification or have badge count > 0
        
        // Then background the app
        
        // Foreground the app
        
        // Ensure that badge count == 0
    }
    
    func testDontclearBadgesWhenAppBecomesActive() throws {
        // NotificationManager Start? Or Mock NotificationManager start
        // Mock receive a notification or have badge count > 0
        
        // Then resign active
        
        // App becomes active the app
        
        // Ensure that badge count == previous badge count
    }
    
    func testUpdateNotificationTypesOnAppEntersForeground() throws {
        // NotificationManager Start? Or Mock NotificationManager start
        // Deny notification permission
        
        // Then background the app
        
        // Change app notification permissions
        
        // Foreground the app for within 30 seconds
        
        // Ensure that we update the notification types
    }
    

}
