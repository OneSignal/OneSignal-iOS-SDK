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
#import "OneSignalSharedUserDefaults.h"
#import "OSSessionResult.h"
#import "OSOutcomesUtils.h"
#import "OneSignalHelper.h"

@interface OutcomeTests : XCTestCase

@end

@implementation OutcomeTests (SessionStatusDelegate)

+ (void)onSessionEnding:(OSSessionResult * _Nonnull)sessionResult {

}

@end

@implementation OutcomeTests {
    NSString *testAppId;
    NSString *testUserId;
    NSString *testEmailUserId;
    NSString *testEmailAddress;
    NSString *testMessageId;
    NSString *testNotificationId;
    NSString *testOutcomeId;
    NSNumber *testDeviceType;
    OneSignalSessionManager *sessionManager;
    OneSignalOutcomeEventsController *outcomesController;

}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    testAppId = @"test_app_id";
    testUserId = @"test_user_id";
    testEmailUserId = @"test_email_user_id";
    testEmailAddress = @"test@test.com";
    testMessageId = @"test_message_id";
    testNotificationId = @"test_notification_id";
    testOutcomeId = @"test_outcome_id";
    testDeviceType = @0;

    sessionManager = [[OneSignalSessionManager alloc] init:(id<SessionStatusDelegate>)self];
    outcomesController = [[OneSignalOutcomeEventsController alloc] init:sessionManager];

    [OneSignalSharedUserDefaults saveString:nil withKey:CACHED_SESSION];
    [OneSignalSharedUserDefaults saveObject:nil withKey:CACHED_DIRECT_NOTIFICATION_ID];
    [OneSignalSharedUserDefaults saveObject:nil withKey:CACHED_INDIRECT_NOTIFICATION_IDS];
    [OneSignalSharedUserDefaults saveObject:nil withKey:CACHED_RECEIVED_NOTIFICATION_IDS];
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

- (void)testOutcomeLastSessionUnattributed {
    [self setOutcomesParamsEnabled];
    
    [sessionManager initSessionFromCache];
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    
    XCTAssertTrue(sessionResult.session == UNATTRIBUTED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeLastSessionUnattributedToIndirect {
    [self setOutcomesParamsEnabled];
    [sessionManager initSessionFromCache];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    let sessionResult = [sessionManager getSessionResult];
    
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 3);
}

- (void)testOutcomeLastSessionIndirectToIndirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    
    [sessionManager initSessionFromCache];

    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
}

- (void)testOutcomeLastSessionIndirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];

    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 3);
}

- (void)testOutcomeLastSessionUnattributedToDirect {
    [self setOutcomesParamsEnabled];

    [sessionManager initSessionFromCache];

    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];

    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [sessionManager initSessionFromCache];
    
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqual([sessionResult.notificationIds objectAtIndex:0], testNotificationId);
}

- (void)testOutcomeLastSessionIndirectToDirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [sessionManager initSessionFromCache];
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [sessionManager initSessionFromCache];
    
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
}

- (void)testOutcomeLastSessionDirectToDirect {
    [self setOutcomesParamsEnabled];
    
    [sessionManager onDirectSessionFromNotificationOpen:@"test"];
    [sessionManager initSessionFromCache];
    
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [sessionManager initSessionFromCache];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult.session == DIRECT);
    XCTAssertTrue([[sessionResult.notificationIds objectAtIndex:0] isEqualToString:testNotificationId]);
}

- (void)testOutcomeLastSessionDirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [self setOutcomesParamsEnabled];
    
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [sessionManager initSessionFromCache];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult.session == DIRECT);
    XCTAssertTrue([sessionResult.notificationIds count] == 1);
}

- (void)testOutcomeLastSessionUnattributedDisable {
    [self setOutcomesParamsDisabled];
    
    [sessionManager initSessionFromCache];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult.session == DISABLED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeLastSessionIndirectDisable {
    [self setOutcomesParamsDisabled];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    
    [OSOutcomesUtils saveSession:INDIRECT];
    [OSOutcomesUtils saveIndirectNotifications:[NSArray arrayWithObject:testNotificationId]];
    [sessionManager initSessionFromCache];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult.session == DISABLED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeLastSessionDirectDisable {
    [self setOutcomesParamsDisabled];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    
    [OSOutcomesUtils saveSession:DIRECT];
    [OSOutcomesUtils saveDirectNotificationId:testNotificationId];
    [sessionManager initSessionFromCache];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult.session == DISABLED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeNewSessionUnattributed {
    [self setOutcomesParamsEnabled];
    
    [sessionManager restartSessionIfNeeded];
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult.session == UNATTRIBUTED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeNewSessionUnattributedToIndirect {
    [self setOutcomesParamsEnabled];
    [sessionManager initSessionFromCache];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    
    [sessionManager restartSessionIfNeeded];
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    
    XCTAssertTrue(sessionResult.session == INDIRECT);
    XCTAssertTrue([sessionResult.notificationIds count] == 3);
}

- (void)testOutcomeNewSessionUnattributedToDirect {
    [self setOutcomesParamsEnabled];
    [sessionManager initSessionFromCache];
    
    [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [sessionManager attemptSessionUpgrade];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];

    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqual([sessionResult.notificationIds objectAtIndex:0], testNotificationId);
}

- (void)testOutcomeNewSessionDirect {
    [self setOutcomesParamsEnabled];
    [sessionManager onDirectSessionFromNotificationOpen:@"test"];
    [sessionManager initSessionFromCache];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqual([sessionResult.notificationIds objectAtIndex:0], @"test");
    
    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [sessionManager attemptSessionUpgrade];
    
    OSSessionResult *sessionResult2 = [sessionManager getSessionResult];

    XCTAssertEqual(sessionResult2.session, DIRECT);
    XCTAssertEqual(sessionResult2.notificationIds.count, 1);
    XCTAssertEqual([sessionResult2.notificationIds objectAtIndex:0], testNotificationId);
}

- (void)testOutcomeSessionIndirectQuantity {
    [self setOutcomesParamsEnabled];
    
    for (int i = 0; i <= 15; i++) {
        [OSOutcomesUtils saveReceivedNotificationWithBackground:testNotificationId fromBackground:YES];
    }
    
    [sessionManager restartSessionIfNeeded];
    
    OSSessionResult *sessionResult2 = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult2.session == INDIRECT);
    XCTAssertTrue([sessionResult2.notificationIds count] == 10);
}

@end
