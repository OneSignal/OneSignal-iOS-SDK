/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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

#import <XCTest/XCTest.h>
#import "OneSignalOutcomeEventsController.h"
#import "OneSignalSessionManager.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalOverrider.h"
#import "OSSessionResult.h"
#import "OSOutcomesUtils.h"
#import "OneSignalHelper.h"
#import "UnitTestCommonMethods.h"
#import "OneSignalNotificationServiceExtensionHandler.h"
  
@interface OutcomeTests<SessionStatusDelegate> : XCTestCase
@end

@implementation OutcomeTests {
    NSString *testNotificationId;
    OneSignalSessionManager *sessionManager;
    OneSignalOutcomeEventsController *outcomesController;
}

+ (void)onSessionEnding:(OSSessionResult * _Nonnull)sessionResult {}

- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    testNotificationId = @"test_notification_id";
    sessionManager = [[OneSignalSessionManager alloc] init:OutcomeTests.self];
    outcomesController = [[OneSignalOutcomeEventsController alloc] init:sessionManager];
}

- (void)setOutcomesParamsEnabled {
    [OSOutcomesUtils saveOutcomeParamsForApp:@{
        @"outcomes": @{
                @"direct": @{
                        @"enabled": @YES
                },
                @"indirect": @{
                        @"notification_attribution": @{
                                @"minutes_since_displayed": @1440,
                                @"limit": @10
                        },
                        @"enabled": @YES
                },
                @"unattributed" : @{
                        @"enabled": @YES
                }
        },
    }];
}

- (void)setOutcomesParamsDisabled {
    [OSOutcomesUtils saveOutcomeParamsForApp:@{
        @"outcomes": @{
                @"direct": @{
                        @"enabled": @NO
                },
                @"indirect": @{
                        @"notification_attribution": @{
                                @"minutes_since_displayed": @1440,
                                @"limit": @10
                        },
                        @"enabled": @NO
                },
                @"unattributed" : @{
                        @"enabled": @NO
                }
        },
    }];
}

- (void)testUnattributedSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];

    // 2. Make sure session is UNATTRIBUTED and has no notificationIds
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, UNATTRIBUTED);
    XCTAssertEqual(sessionResult.notificationIds, nil);
}

- (void)testIndirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive 3 notifications
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    // 3. Init sessionManager and attempt to restart the session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    // 4. Make sure session is INDIRECT and has 3 notifications
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 3);
}

- (void)testDirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive 1 notification and click it
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    
    // 3. Init sessionManager and attempt to restart the session
    [sessionManager initSessionFromCache];
    
    // 4. Make sure session is DIRECT and has 1 notification
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
}

- (void)testUnattributedSessionToIndirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    // 3. Make sure the session is UNATTRIBUTED and has no notifications
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, UNATTRIBUTED);
    XCTAssertEqual(sessionResult.notificationIds.count, 0);
    
    // 4. Rceive 3 notifications
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    // 5. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    // 6. Make sure the session is INDIRECT and has 3 notifications
    let sessionResult2 = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult2.session, INDIRECT);
    XCTAssertEqual(sessionResult2.notificationIds.count, 3);
}

- (void)testIndirectSession_wontOverrideIndirectSession_withoutNewSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive a notification
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    // 3. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    // 6. Make sure session is INDIRECT and has 1 notification
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    
    // 4. Receive 3 more notifications
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    // 5. Init sessionManager without new session
    [sessionManager initSessionFromCache];

    // 6. Make sure session is INDIRECT and has 1 notification
    let sessionResult2 = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult2.session, INDIRECT);
    XCTAssertEqual(sessionResult2.notificationIds.count, 1);
}

- (void)testUnattributedSessionToDirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive 2 notifications
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];

    // 3. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    // 4. Make sure session is INDIRECT and has 2 notification
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 2);

    // 5. Receive a notification and open it
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    
    // 6. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 7. Make sure session is DIRECT and has 1 notification
    let sessionResult2 = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult2.session, DIRECT);
    XCTAssertEqual(sessionResult2.notificationIds.count, 1);
}

- (void)testIndirectSessionToDirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive a notification and open it
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    
    // 3. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 4. Make sure session
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqualObjects(sessionResult.notificationIds, @[testNotificationId]);
}

- (void)testDirectSessionToDirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receieve a notification and open it
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    
    // 3. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 4. Receieve a notification and open it
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    
    // 5. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 6. Make sure session is DIRECT and has 1 notifciation
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqualObjects(sessionResult.notificationIds, @[testNotificationId]);
}

- (void)testUnattributedSession_whenOutcomesIsDisabled {
    // 1. Set outcome params disabled
    [self setOutcomesParamsDisabled];
    
    // 2. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    // 3. Make sure session is DISABLED and no notificationIds exist
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DISABLED);
    XCTAssertEqual(sessionResult.notificationIds, nil);
}

- (void)testIndirectSession_whenOutcomesIsDisabled {
    // 1. Set outcome params disabled
    [self setOutcomesParamsDisabled];
    
    // 2. Receive 2 notifications
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    // 3. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    // 4. Make sure session is DISABLED and no notifications exist
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DISABLED);
    XCTAssertEqual(sessionResult.notificationIds, nil);
}

- (void)testDirectSession_whenOutcomesIsDisabled {
    // 1. Set outcome params disabled
    [self setOutcomesParamsDisabled];
    
    // 2. Receieve a notification and open it
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    
    // 3. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 4. Make sure session is DISABLED and no notifications exist
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DISABLED);
    XCTAssertEqual(sessionResult.notificationIds, nil);
}

- (void)testIndirectSession_attributionNotificationLimit {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive 15 notifications
    NSMutableArray *recentNotifIds = [NSMutableArray new];
    for (int i = 0; i <= 15; i++) {
        NSString *notifId = [NSString stringWithFormat:@"test_notification_%i", i + 1];
        [OSOutcomesUtils saveReceivedNotificationFromBackground:notifId];
        
        // Add the most recent 10 notifications by removing 0 index after count passes 10
        [recentNotifIds addObject:notifId];
        if (recentNotifIds.count > 10)
            [recentNotifIds removeObjectAtIndex:0];
    }
    
    // 3. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    // 4. Make sure session is INDIRECT and only has the most recent 10 notifications
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 10);
    XCTAssertEqualObjects(sessionResult.notificationIds, recentNotifIds);
}

@end
