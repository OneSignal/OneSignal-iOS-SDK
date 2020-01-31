/*
 Modified MIT License
 
 Copyright 2019 OneSignal
 
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

#import <XCTest/XCTest.h>
#import "OneSignalOutcomeEventsController.h"
#import "OneSignalSessionManager.h"
#import "OneSignalUserDefaults.h"
#import "OSSessionResult.h"
#import "OSOutcomesUtils.h"
#import "OneSignalHelper.h"
#import "OneSignalTracker.h"
#import "OneSignalOverrider.h"
#import "UnitTestCommonMethods.h"
#import "OneSignalClientOverrider.h"
#import "Requests.h"
#import "NSDateOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "RestClientAsserts.h"
#import "OSOutcomesUtils.h"
#import "NSUserDefaultsOverrider.h"
#import "OneSignalClientOverrider.h"
#import "UIApplicationOverrider.h"
#import "OneSignalNotificationServiceExtensionHandler.h"
#import "NSTimerOverrider.h"

@interface OneSignal ()
+ (OneSignalSessionManager*)sessionManager;
+ (OneSignalOutcomeEventsController*)outcomeEventsController;
@end

@interface OutcomeIntergrationTests<SessionStatusDelegate> : XCTestCase
@end

@implementation OutcomeIntergrationTests {
    
}

+ (void)onSessionEnding:(OSSessionResult * _Nonnull)sessionResult {}

/*
 Put setup code here
 This method is called before the invocation of each test method in the class
 */
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    [OneSignalClientOverrider enableOutcomes];
}

/*
 Put teardown code here
 This method is called after the invocation of each test method in the class
 */
- (void)tearDown {
    [super tearDown];
}

- (void)testUnattributedSession_onAppColdStart {
    // 1. Open App
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Make sure the session is UNATTRIBUTED and has 0 notifications
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 0);
}

- (void)testUnattributedSession_onFocusUnattributed {
    // 1. Open App
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 2. Wait 60 secounds
    [NSDateOverrider advanceSystemTimeBy:60];
    
    // 3. Background app
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 4. Ensure onFocus is made right away.
    [RestClientAsserts assertOnFocusAtIndex:2 withTime:60];
}

- (void)testIndirectSession_onFocusAttributed {
    // 1. Open App and wait for 5 secounds
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    [NSDateOverrider advanceSystemTimeBy:5];
    
    // 2. Background app and receive notification
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    
    // 3. Swipe away app and reopen it 31 secounds later.
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [NSDateOverrider advanceSystemTimeBy:31];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 4. Wait 15 secounds
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 5. Background app
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 6. Force kick off our pending 30 secound on_focus job
    [NSTimerOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 7. Ensure onFocus is sent in the background.
    [RestClientAsserts assertOnFocusAtIndex:4 withTime:15];
}

- (void)testDirectSession_onFocusAttributed {
    // 1. Open App and wait for 5 secounds
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    [NSDateOverrider advanceSystemTimeBy:5];
    
    // 2. Background app, receive notification, and open notification
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 3. Swipe away app and reopen it 31 secounds later.
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [NSDateOverrider advanceSystemTimeBy:31];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 4. Wait 15 secounds
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 5. Background app
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 6. Force kick off our pending 30 secound on_focus job
    [NSTimerOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 7. Ensure onFocus is sent in the background.
    [RestClientAsserts assertOnFocusAtIndex:4 withTime:15];
}

- (void)testDirectSession_overridesIndirectSession_andSendsOnFocus {
    // 1. Open App and wait for 5 secounds
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    [NSDateOverrider advanceSystemTimeBy:5];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 5. Make sure the session is INDIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
    XCTAssertEqualObjects(OneSignal.sessionManager.getNotificationIds, @[@"test_notification_1"]);
    
    // 6. Close the app for less than 30 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 7. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    
    // 8. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 7. Ensure onFocus is made to end the indirect session in this upgrade
    [NSTimerOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [RestClientAsserts assertOnFocusAtIndex:4 payload:@{
        @"active_time": @(15),
        @"notification_ids": @[@"test_notification_1"],
        @"direct": @(false)
    }];
    
    // 9. Make sure the session is DIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
    XCTAssertEqualObjects(OneSignal.sessionManager.getNotificationIds, @[@"test_notification_2"]);
}

- (void)testSavingNullReceivedNotificationId {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 2 notifications, one blank id and one null id
    [UnitTestCommonMethods receiveNotification:@"" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:nil wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 5. Make sure the session is UNATTRIBUTED and has 0 notifications
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 0);
    
    // 6. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 7. Receive 1 notification
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    
    // 8. Open app
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 9. Make sure the session is INDIRECT and has 1 notifications
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
}

- (void)testIndirectSession_afterReceiveingNotifications {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 3 notifications in background
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 5. Make sure the session is INDIRECT and has 3 notifications
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 3);
}

- (void)testDirectSession_afterReceiveingNotifications {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 3 notifications in background
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];
    
    // 4. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_4" wasOpened:YES];
    
    // 5. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 6. Make sure the session is DIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
}

- (void)testUnattributedSession_afterAllNotificationsPastAttributionWindow {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification in background
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 5. Make sure the session is DIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
    
    // 6. Close the app for 24 hours and 1 minute
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:1441 * 60];
    
    // 7. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 8. Make sure the session is UNATTRIBUTED and has 0 notifications
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 0);
}

- (void)testDirectSession_overridesDirectSession {
    // 1. Open app
    //    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 5. Make sure the session is INDIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
    XCTAssertEqualObjects(OneSignal.sessionManager.getNotificationIds, @[@"test_notification_1"]);
    
    // 6. Close the app for less than 30 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 7. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    
    // 8. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 9. Make sure the session is DIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
    XCTAssertEqualObjects(OneSignal.sessionManager.getNotificationIds, @[@"test_notification_2"]);
}

- (void)testDirectSession_overridesIndirectSession {
    // 1. Open app
    //    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 5. Make sure the session is INDIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
    XCTAssertEqualObjects(OneSignal.sessionManager.getNotificationIds, @[@"test_notification_1"]);
    
    // 6. Close the app for less than 30 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 7. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    
    // 8. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 9. Make sure the session is DIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
    XCTAssertEqualObjects(OneSignal.sessionManager.getNotificationIds, @[@"test_notification_2"]);
}

- (void)testIndirectSession_overridesUnattributedSession {
    // 1. Open app
    //    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Make sure the session is UNATTRIBUTED and has 0 notifications
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 0);
    
    // 6. Close the app for less than 30 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 4. Receive 1 notification
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    
    // 5. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 6. Make sure the session is INDIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
}

- (void)testDirectSession_overridesUnattributedSession {
    // 1. Open app
    //    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Make sure the session is UNATTRIBUTED and has 0 notifications
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 0);
    
    // 6. Close the app for less than 30 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 4. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 5. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 6. Make sure the session is DIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
}

- (void)testIndirectSessionWontOverrideDirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 5. Make sure the session is DIRECT and has 1 notification
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
    
    // 6. Close the app for less than 30 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:15];
    
    // 7. Receive 3 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_4" wasOpened:NO];
    
    // 8. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 9. Make sure the session is still DIRECT and has 1 notification since session has not ended
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    XCTAssertEqual(OneSignal.sessionManager.getNotificationIds.count, 1);
}

- (void)testSendingOutcome_inUnattributedSession {
    // 1. Open app
    //    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    // 2. Validate session is UNATTRIBUTED and send 2 outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    [OneSignal sendOutcome:@"normal_1"];
    [OneSignal sendOutcome:@"normal_2"];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureAtIndex:2 payload:@{
        @"id" : @"normal_1"
    }];
    [RestClientAsserts assertMeasureAtIndex:3 payload:@{
        @"id" : @"normal_2"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testSendingOutcome_inIndirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 2. Close the app for 31 seconds to trigger a new session
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 2 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 5. Validate session is INDIRECT and send 2 outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    [OneSignal sendOutcome:@"normal_1"];
    [OneSignal sendOutcome:@"normal_2"];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureAtIndex:3 payload:@{
        @"direct" : @(false),
        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
        @"id" : @"normal_1"
    }];
    [RestClientAsserts assertMeasureAtIndex:4 payload:@{
        @"direct" : @(false),
        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
        @"id" : @"normal_2"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testSendingOutcome_inDirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 5. Validate session is DIRECT and send 2 outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    [OneSignal sendOutcome:@"normal_1"];
    [OneSignal sendOutcome:@"normal_2"];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureAtIndex:4 payload:@{
        @"direct" : @(true),
        @"notification_ids" : @[@"test_notification_1"],
        @"id" : @"normal_1"
    }];
    [RestClientAsserts assertMeasureAtIndex:5 payload:@{
        @"direct" : @(true),
        @"notification_ids" : @[@"test_notification_1"],
        @"id" : @"normal_2"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testSendingOutcomeWithValue_inUnattributedSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];

    // 2. Validate session is UNATTRIBUTED and send 2 outcomes with values
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    [OneSignal sendOutcomeWithValue:@"value_1" value:@3.4];
    [OneSignal sendOutcomeWithValue:@"value_2" value:@9.95];

    // 3. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureAtIndex:2 payload:@{
        @"id" : @"value_1"
    }];
    [RestClientAsserts assertMeasureAtIndex:3 payload:@{
        @"id" : @"value_2"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testSendingOutcomeWithValue_inIndirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 2. Close the app for 31 seconds to trigger a new session
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 2 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 5. Validate session is INDIRECT and send 2 outcomes with values
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    let val1 = [NSNumber numberWithDouble:3.4];
    [OneSignal sendOutcomeWithValue:@"value_1" value:val1];
    let val2 = [NSNumber numberWithDouble:9.95];
    [OneSignal sendOutcomeWithValue:@"value_2" value:val2];

    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureAtIndex:3 payload:@{
        @"direct" : @(false),
        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
        @"id" : @"value_1",
        @"weight" : val1
    }];
    [RestClientAsserts assertMeasureAtIndex:4 payload:@{
        @"direct" : @(false),
        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
        @"id" : @"value_2",
        @"weight" : val2
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testSendingOutcomeWithValue_inDirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 5. Validate session is DIRECT and send 2 outcomes with values
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    let val1 = [NSNumber numberWithDouble:3.4];
    [OneSignal sendOutcomeWithValue:@"value_1" value:val1];
    let val2 = [NSNumber numberWithDouble:9.95];
    [OneSignal sendOutcomeWithValue:@"value_2" value:val2];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureAtIndex:4 payload:@{
        @"direct" : @(true),
        @"notification_ids" : @[@"test_notification_1"],
        @"id" : @"value_1",
        @"weight" : val1
    }];
    [RestClientAsserts assertMeasureAtIndex:5 payload:@{
        @"direct" : @(true),
        @"notification_ids" : @[@"test_notification_1"],
        @"id" : @"value_2",
        @"weight" : val2
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testUnattributedSession_cachedUniqueOutcomeCleanedOnNewSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 2. Validate session is UNATTRIBUTED and send 2 of the same unique outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 3. Make sure only 1 measure request is made
    [RestClientAsserts assertMeasureAtIndex:2 payload:@{
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:1];

    // 4. Close the app for 31 seconds to trigger a new session
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 5. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 6. Make sure a on_session request is made
    [RestClientAsserts assertOnSessionAtIndex:3];

    // 7. Validate new session is UNATTRIBUTED and send the same 2 unique outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, UNATTRIBUTED);
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 8. Make sure 2 measure requests have been made in total
    [RestClientAsserts assertMeasureAtIndex:4 payload:@{
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testAttributedIndirectSession_cachedUniqueOutcomeNotificationsCleanedAfter7Days {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive 3 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 5. Validate new session is INDIRECT and send 2 of the same unique outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureAtIndex:3 payload:@{
        @"direct" : @(false),
        @"notification_ids" : @[@"test_notification_1", @"test_notification_2", @"test_notification_3"],
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:1];
    
    // 7. Close the app again, but for a week to clean out all outdated unique outcome notifications
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:7 * 1441 * 60];
    [UnitTestCommonMethods runBackgroundThreads];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    // 8. Receive 3 more notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];

    // 9. Open app again
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 10. Validate new session is INDIRECT and send the same 2 unique outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total
    [RestClientAsserts assertMeasureAtIndex:6 payload:@{
        @"direct" : @(false),
        @"notification_ids" : @[@"test_notification_1", @"test_notification_2", @"test_notification_3"],
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testAttributedDirectSession_cachedUniqueOutcomeNotificationsCleanedAfter7Days {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive a few notifications and open 1
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 5. Validate new session is ATTRIBUTED (DIRECT or INDIRECT) and send 2 of the same unique outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureAtIndex:4 payload:@{
        @"direct" : @(true),
        @"notification_ids" : @[@"test_notification_2"],
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:1];
    
    // 7. Close the app again, but for a week to clean out all outdated unique outcome notifications
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:7 * 1441 * 60];
    [UnitTestCommonMethods runBackgroundThreads];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    // 8. Open app again
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods backgroundApp];
    
    // 9. Receive 1 more notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    [UnitTestCommonMethods foregroundApp];

    // 10. Validate new session is DIRECT and send the same 2 unique outcomes
    XCTAssertEqual(OneSignal.sessionManager.getSession, DIRECT);
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total
    [RestClientAsserts assertMeasureAtIndex:8 payload:@{
        @"direct" : @(true),
        @"notification_ids" : @[@"test_notification_2"],
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

- (void)testAttributedIndirectSession_sendsUniqueOutcomeForNewNotifications_andNotCachedNotifications {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive 2 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 5. Validate new session is ATTRIBUTED (DIRECT or INDIRECT) and send 1 unique outcome
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureAtIndex:3 payload:@{
        @"direct" : @(false),
        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:1];
    
    // 7. Close the app again, but for a week to clean out all outdated unique outcome notifications
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 8. Receive 2 of the same notifications and 1 new one
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];

    // 9. Open app again
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];

    // 10. Validate new session is ATTRIBUTED (DIRECT or INDIRECT) and send the same unique outcome
    XCTAssertEqual(OneSignal.sessionManager.getSession, INDIRECT);
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total and does not include already sent notification ids for the unique outcome
    [RestClientAsserts assertMeasureAtIndex:6 payload:@{
        @"direct" : @(false),
        @"notification_ids" : @[@"test_notification_3"],
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureRequests:2];
}

@end
