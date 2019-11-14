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
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    let sessionResult = [sessionManager getSessionResult];
    
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 3);
}

- (void)testOutcomeLastSessionIndirectToIndirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    [sessionManager initSessionFromCache];

    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
}

- (void)testOutcomeLastSessionIndirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];

    XCTAssertEqual(sessionResult.session, INDIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 3);
}

- (void)testOutcomeLastSessionUnattributedToDirect {
    [self setOutcomesParamsEnabled];

    [sessionManager initSessionFromCache];

    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];

    [sessionManager onDirectSessionFromNotificationOpen:testNotificationId];
    [sessionManager initSessionFromCache];
    
    let sessionResult = [sessionManager getSessionResult];
    XCTAssertEqual(sessionResult.session, DIRECT);
    XCTAssertEqual(sessionResult.notificationIds.count, 1);
    XCTAssertEqual([sessionResult.notificationIds objectAtIndex:0], testNotificationId);
}

- (void)testOutcomeLastSessionIndirectToDirect {
    [self setOutcomesParamsEnabled];
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
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
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
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
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    [OSOutcomesUtils saveSession:INDIRECT];
    [OSOutcomesUtils saveIndirectNotificationIds:[NSArray arrayWithObject:testNotificationId]];
    [sessionManager initSessionFromCache];
    
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult.session == DISABLED);
    XCTAssertTrue(sessionResult.notificationIds == nil);
}

- (void)testOutcomeLastSessionDirectDisable {
    [self setOutcomesParamsDisabled];
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
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
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
    [sessionManager restartSessionIfNeeded];
    OSSessionResult *sessionResult = [sessionManager getSessionResult];
    
    XCTAssertTrue(sessionResult.session == INDIRECT);
    XCTAssertTrue([sessionResult.notificationIds count] == 3);
}

- (void)testOutcomeNewSessionUnattributedToDirect {
    [self setOutcomesParamsEnabled];
    [sessionManager initSessionFromCache];
    
    [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    
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
        [OSOutcomesUtils saveReceivedNotificationFromBackground:testNotificationId];
    }
    
    [sessionManager restartSessionIfNeeded];
    
    OSSessionResult *sessionResult2 = [sessionManager getSessionResult];
    XCTAssertTrue(sessionResult2.session == INDIRECT);
    XCTAssertTrue([sessionResult2.notificationIds count] == 10);
}

@end
