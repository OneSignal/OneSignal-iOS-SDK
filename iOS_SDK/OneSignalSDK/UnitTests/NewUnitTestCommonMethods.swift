import Foundation
import XCTest
import OneSignalCoreMocks
// import OneSignalFramework

public class NewUnitTestCommonMethods: NSObject {
    static var currentXCTestCase: XCTestCase?

    
    /*
     Init OneSignal with default appId (@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba") and launchOptions (nil)
     */
    static func initOneSignal_andThreadWait() {
        // OneSignal.initialize("b2f7f966-d8cc-11e4-bed1-df8f05be55ba")
        self.runBackgroundThreads()
    }
    
    /*
     Runs any blocks passed to dispatch_async()
     */
    static func runBackgroundThreads() {
        print("START runBackgroundThreads")
        
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        for _ in 1...10 {
            NewUnitTestCommonMethods.runThreadsOnEachQueue()
        }

        print("END runBackgroundThreads")
    }
    
    static func runThreadsOnEachQueue() {
        // TODO: unit-test-todo This method
        // ...
        // [OneSignalClientOverrider runBackgroundThreads];
        // (OneSignalCore.sharedClient() as? MockOneSignalClient)?.runBackgroundThreads()
        // ...
    }
    
    static func beforeAllTest() {
        
    }
    
    static func beforeEachTest(testCase: XCTestCase) {
        currentXCTestCase = testCase
        self.beforeAllTest()
        self.clearStateForAppRestart(testCase)
        self.clearUserDefaults()
//        [NSDateOverrider reset];
//        [OneSignalOverrider reset];
//        [OneSignalClientOverrider reset:testCase];
//        UNUserNotificationCenterOverrider.notifTypesOverride = 7;
//        UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    }
    
    static func clearStateForAppRestart(_ testCase: XCTestCase) {
        
    }
    
    static func clearUserDefaults() {
        
    }
    
}

