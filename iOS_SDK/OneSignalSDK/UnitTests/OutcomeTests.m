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
#import "OneSignalOutcomeController.h"
#import "OneSignalSessionManager.h"
#import "OneSignalSharedUserDefaults.h"
#import "OSSessionResult.h"
#import "OSOutcomesUtils.h"

#import "OneSignalHelper.h"

@interface OutcomeTests : XCTestCase

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
    OneSignalOutcomesController *outcomesController;

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
    outcomesController = [[OneSignalOutcomesController alloc] init];
    [OneSignalSessionManager clearSessionData];
    [OneSignalSharedUserDefaults saveCodeableData:nil withKey:LAST_NOTIFICATIONS_RECEIVED];
    [OSOutcomesUtils saveOpenedByNotification:nil];
}

- (void)setOutcomesParamsEnabled {
    [OSOutcomesUtils saveOutcomesParams:@{@"outcomes": @{
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
    [OSOutcomesUtils saveOutcomesParams:@{@"outcomes": @{
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
    
    [OneSignalSessionManager initLastSession];
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    
    XCTAssertTrue(sessionResult.session == UNATTRIBUTED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeLastSessionUnattributedToIndirect {
    [self setOutcomesParamsEnabled];
    [OneSignalSessionManager initLastSession];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    
    [OneSignalSessionManager initLastSession];
    [OneSignalSessionManager restartSessionIfNeeded];
    let sessionResult = [OneSignalSessionManager sessionResult];
    
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 3);
}

- (void)testOutcomeLastSessionIndirectToIndirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OneSignalSessionManager initLastSession];
    [OneSignalSessionManager restartSessionIfNeeded];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    
    [OneSignalSessionManager initLastSession];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
}

- (void)testOutcomeLastSessionIndirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    
    [OneSignalSessionManager initLastSession];
    [OneSignalSessionManager restartSessionIfNeeded];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 3);
}

- (void)testOutcomeLastSessionUnattributedToDirect {
    [self setOutcomesParamsEnabled];
    [OneSignalSessionManager initLastSession];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    
    [OneSignalSessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [OneSignalSessionManager initLastSession];
    
    let sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqual([sessionResult.notificationIds objectAtIndex:0], testNotificationId);
}

- (void)testOutcomeLastSessionIndirectToDirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OneSignalSessionManager initLastSession];
    [OneSignalSessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [OneSignalSessionManager initLastSession];
    
    let sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
}

- (void)testOutcomeLastSessionDirectToDirect {
    [self setOutcomesParamsEnabled];
    
    [OneSignalSessionManager onDirectSessionFromNotificationOpen:@"test"];
    [OneSignalSessionManager initLastSession];
    
    [OneSignalSessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [OneSignalSessionManager initLastSession];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertTrue(sessionResult.session == DIRECT);
    XCTAssertTrue([[sessionResult.notificationIds objectAtIndex:0] isEqualToString:testNotificationId]);
}

- (void)testOutcomeLastSessionDirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [self setOutcomesParamsEnabled];
    
    [OneSignalSessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [OneSignalSessionManager initLastSession];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertTrue(sessionResult.session == DIRECT);
    XCTAssertTrue([sessionResult.notificationIds count] == 1);
}

- (void)testOutcomeLastSessionUnattributedDisable {
    [self setOutcomesParamsDisabled];
    
    [OneSignalSessionManager initLastSession];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertTrue(sessionResult.session == DISABLED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeLastSessionIndirectDisable {
    [self setOutcomesParamsDisabled];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    
    [OSOutcomesUtils saveLastSession:INDIRECT notificationIds:[NSArray arrayWithObject:testNotificationId]];
    [OneSignalSessionManager initLastSession];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertTrue(sessionResult.session == DISABLED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeLastSessionDirectDisable {
    [self setOutcomesParamsDisabled];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    
    [OSOutcomesUtils saveLastSession:DIRECT notificationIds:[NSArray arrayWithObject:testNotificationId]];
    [OneSignalSessionManager initLastSession];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertTrue(sessionResult.session == DISABLED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeNewSessionUnattributed {
    [self setOutcomesParamsEnabled];
    
    [OneSignalSessionManager restartSessionIfNeeded];
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertTrue(sessionResult.session == UNATTRIBUTED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeNewSessionUnattributedToIndirect {
    [self setOutcomesParamsEnabled];
    [OneSignalSessionManager initLastSession];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    
    [OneSignalSessionManager restartSessionIfNeeded];
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    
    XCTAssertTrue(sessionResult.session == INDIRECT);
    XCTAssertTrue([sessionResult.notificationIds count] == 3);
}

- (void)testOutcomeNewSessionUnattributedToDirect {
    [self setOutcomesParamsEnabled];
    [OneSignalSessionManager initLastSession];
    
    [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    
    [OneSignalSessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [OneSignalSessionManager attemptSessionUpgrade];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqual([sessionResult.notificationIds objectAtIndex:0], testNotificationId);
}

- (void)testOutcomeNewSessionDirect {
    [self setOutcomesParamsEnabled];
    [OneSignalSessionManager onDirectSessionFromNotificationOpen:@"test"];
    [OneSignalSessionManager initLastSession];
    
    OSSessionResult *sessionResult = [OneSignalSessionManager sessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqual([sessionResult.notificationIds objectAtIndex:0], @"test");
    
    [OneSignalSessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [OneSignalSessionManager attemptSessionUpgrade];
    
    OSSessionResult *sessionResult2 = [OneSignalSessionManager sessionResult];
    
    XCTAssertEqual(sessionResult2.session, DIRECT);
    XCTAssertEqual(sessionResult2.notificationIds.count, 1);
    XCTAssertEqual([sessionResult2.notificationIds objectAtIndex:0], testNotificationId);
}

- (void)testOutcomeSessionIndirectQuantity {
    [self setOutcomesParamsEnabled];
    
    for (int i = 0; i <= 15; i++) {
        [OSOutcomesUtils saveLastNotificationWithBackground:testNotificationId wasOnBackground:YES];
    }
    
    [OneSignalSessionManager restartSessionIfNeeded];
    
    OSSessionResult *sessionResult2 = [OneSignalSessionManager sessionResult];
    XCTAssertTrue(sessionResult2.session == INDIRECT);
    XCTAssertTrue([sessionResult2.notificationIds count] == 10);
}

@end
