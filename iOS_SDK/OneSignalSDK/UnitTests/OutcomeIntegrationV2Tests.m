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
#import "OSSessionManager.h"
#import "OneSignalUserDefaults.h"
#import "OSInfluence.h"
#import "OSOutcomeEventsCache.h"
#import "OneSignalHelper.h"
#import "OneSignalTracker.h"
#import "OneSignalOverrider.h"
#import "UnitTestCommonMethods.h"
#import "OneSignalClientOverrider.h"
#import "OSRequests.h"
#import "NSDateOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "RestClientAsserts.h"
#import "CommonAsserts.h"
#import "OneSignalClientOverrider.h"
#import "UIApplicationOverrider.h"
#import "OneSignalNotificationServiceExtensionHandler.h"
#import "NSTimerOverrider.h"

@interface OneSignal ()
+ (OSOutcomeEventsCache*)outcomeEventsCache;
+ (OSSessionManager*)sessionManager;
+ (OSTrackerFactory*)trackerFactory;
+ (OneSignalOutcomeEventsController*)outcomeEventsController;
@end

@interface OutcomeIntergrationV2Tests<SessionStatusDelegate> : XCTestCase
@end

@implementation OutcomeIntergrationV2Tests {
    
}

+ (void)onSessionEnding:(OSInfluence * _Nonnull)sessionResult {}

- (void)setUp {
    
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    [OneSignalClientOverrider enableOutcomes];
}

- (void)testSendingOutcome_inUnattributedSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Validate all influences are UNATTRIBUTED and send 2 outcomes
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
        XCTAssertEqual(influence.ids, nil);
    }
    [OneSignal sendOutcome:@"normal_1"];
    [OneSignal sendOutcome:@"normal_2"];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:2 payload:@{
        @"id" : @"normal_1"
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"id" : @"normal_2"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcome_inNotificationIndirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds to trigger a new session
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 2 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 5. Validate NOTIFICATION influence is INDIRECT and send 2 outcomes
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 2);
        }
    }
    [OneSignal sendOutcome:@"normal_1"];
    [OneSignal sendOutcome:@"normal_2"];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
                },
        },
        @"id" : @"normal_1"
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:4 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
                },
        },
        @"id" : @"normal_2"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcome_inNotificationDirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    
    // 5. Validate NOTIFICATION influence is DIRECT and send 2 outcomes
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_1"]];
        }
    }
    [OneSignal sendOutcome:@"normal_1"];
    [OneSignal sendOutcome:@"normal_2"];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:4 payload:@{
        @"sources": @{
                @"direct": @{
                        @"notification_ids" : @[@"test_notification_1"],
                },
        },
        @"id" : @"normal_1"
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:5 payload:@{
       @"sources": @{
                @"direct": @{
                        @"notification_ids" : @[@"test_notification_1"],
                },
        },
        @"id" : @"normal_2"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcomeWithValue_inUnattributedSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Validate all influences are UNATTRIBUTED and send 2 outcomes with values
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
        XCTAssertEqual(influence.ids, nil);
    }
    [OneSignal sendOutcomeWithValue:@"value_1" value:@3.4];
    [OneSignal sendOutcomeWithValue:@"value_2" value:@9.95];

    // 3. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:2 payload:@{
        @"id" : @"value_1"
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"id" : @"value_2"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcomeWithValue_inNotificationIndirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds to trigger a new session
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 2 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    
    // 5. Validate NOTIFICATION influence INDIRECT and send 2 outcomes with values
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 2);
        }
    }
    let val1 = [NSNumber numberWithDouble:3.4];
    [OneSignal sendOutcomeWithValue:@"value_1" value:val1];
    let val2 = [NSNumber numberWithDouble:9.95];
    [OneSignal sendOutcomeWithValue:@"value_2" value:val2];

    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
                },
        },
        @"id" : @"value_1",
        @"weight" : val1
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:4 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
                },
        },
        @"id" : @"value_2",
        @"weight" : val2
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcomeWithValue_inNotificationDirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 5. Validate NOTIFICATION influence is DIRECT and send 2 outcomes with values
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_1"]];
        }
    }
    let val1 = [NSNumber numberWithDouble:3.4];
    [OneSignal sendOutcomeWithValue:@"value_1" value:val1];
    let val2 = [NSNumber numberWithDouble:9.95];
    [OneSignal sendOutcomeWithValue:@"value_2" value:val2];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:4 payload:@{
        @"sources": @{
                @"direct": @{
                        @"notification_ids" : @[@"test_notification_1"],
                },
        },
        @"id" : @"value_1",
        @"weight" : val1
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:5 payload:@{
        @"sources": @{
                @"direct": @{
                        @"notification_ids" : @[@"test_notification_1"],
                },
        },
        @"id" : @"value_2",
        @"weight" : val2
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testUnattributedSession_cachedUniqueOutcomeCleanedOnNewSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Validate all influences are UNATTRIBUTED and send 2 of the same unique outcomes
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
        XCTAssertEqual(influence.ids, nil);
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 3. Make sure only 1 measure request is made
    [RestClientAsserts assertMeasureSourcesAtIndex:2 payload:@{
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:1];

    // 4. Close the app for 31 seconds to trigger a new session
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 5. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 6. Make sure a on_session request is made
    [RestClientAsserts assertOnSessionAtIndex:3];

    // 7. Validate new influences are UNATTRIBUTED and send the same 2 unique outcomes
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
        XCTAssertEqual(influence.ids, nil);
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 8. Make sure 2 measure requests have been made in total
    [RestClientAsserts assertMeasureSourcesAtIndex:4 payload:@{
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testAttributedIndirectSession_cachedUniqueOutcomeNotificationsCleanedAfter7Days {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive 3 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 5. Validate new NOTIFICATION influence is INDIRECT and send 2 of the same unique outcomes
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 3);
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2", @"test_notification_3"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:1];
    
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
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 10. Validate new NOTIFICATION influence is INDIRECT and send the same 2 unique outcomes
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 3);
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total
    [RestClientAsserts assertMeasureSourcesAtIndex:6 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2", @"test_notification_3"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testAttributedDirectSession_cachedUniqueOutcomeNotificationsCleanedAfter7Days {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive a few notifications and open 1
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 5. Validate new influences are ATTRIBUTED (DIRECT or INDIRECT) and send 2 of the same unique outcomes
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_2"]];
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureSourcesAtIndex:4 payload:@{
        @"sources": @{
                @"direct": @{
                        @"notification_ids" : @[@"test_notification_2"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:1];
    
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
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_2"]];
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total
    [RestClientAsserts assertMeasureSourcesAtIndex:7 payload:@{
        @"sources": @{
                @"direct": @{
                        @"notification_ids" : @[@"test_notification_2"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testAttributedIndirectSession_sendsUniqueOutcomeForNewNotifications_andNotCachedNotifications {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive 2 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 5. Validate new NOTIFICATION influence is ATTRIBUTED (DIRECT or INDIRECT) and send 1 unique outcome
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 2);
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:1];
    
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

    // 10. Validate new NOTIFICATION influence is ATTRIBUTED (DIRECT or INDIRECT) and send the same unique outcome
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 5);
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total and does not include already sent notification ids for the unique outcome
    [RestClientAsserts assertMeasureSourcesAtIndex:6 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_3"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcome_inIAMIndirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Receive 2 iam
    [[OneSignal sessionManager] onInAppMessageReceived:@"test_in_app_message_1"];
    [[OneSignal sessionManager] onInAppMessageReceived:@"test_in_app_message_2"];
    // 3. Dismiss iam
    [[OneSignal sessionManager] onDirectInfluenceFromIAMClickFinished];
    
    // 4. Validate IN_APP_MESSAGE influence is INDIRECT and send 2 outcomes
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 2);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
        }
    }
    [OneSignal sendOutcome:@"normal_1"];
    [OneSignal sendOutcome:@"normal_2"];
    
    // 5. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:2 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"in_app_message_ids" : @[@"test_in_app_message_1", @"test_in_app_message_2"],
                },
        },
        @"id" : @"normal_1"
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"in_app_message_ids" : @[@"test_in_app_message_1", @"test_in_app_message_2"],
                },
        },
        @"id" : @"normal_2"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcome_inIAMDirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Receive 1 IAM and send outcomes from action
    [[OneSignal sessionManager] onDirectInfluenceFromIAMClick:@"test_in_app_message_1"];
    
    [OneSignal sendOutcome:@"normal_1"];
    [OneSignal sendOutcome:@"normal_2"];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:2 payload:@{
        @"sources": @{
                @"direct": @{
                        @"in_app_message_ids" : @[@"test_in_app_message_1"],
                },
        },
        @"id" : @"normal_1"
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
       @"sources": @{
                @"direct": @{
                        @"in_app_message_ids" : @[@"test_in_app_message_1"],
                },
        },
        @"id" : @"normal_2"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcomeWithValue_inIAMIndirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Receive 2 iam
    [[OneSignal sessionManager] onInAppMessageReceived:@"test_in_app_message_1"];
    [[OneSignal sessionManager] onInAppMessageReceived:@"test_in_app_message_2"];
    // 3. Dismiss iam
    [[OneSignal sessionManager] onDirectInfluenceFromIAMClickFinished];
    
    // 4. Validate IN_APP_MESSAGE influence is INDIRECT and send 2 outcomes
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 2);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
        }
    }
    let val1 = [NSNumber numberWithDouble:3.4];
    [OneSignal sendOutcomeWithValue:@"value_1" value:val1];
    let val2 = [NSNumber numberWithDouble:9.95];
    [OneSignal sendOutcomeWithValue:@"value_2" value:val2];

    // 5. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:2 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"in_app_message_ids" : @[@"test_in_app_message_1", @"test_in_app_message_2"],
                },
        },
        @"id" : @"value_1",
        @"weight" : val1
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"in_app_message_ids" : @[@"test_in_app_message_1", @"test_in_app_message_2"],
                },
        },
        @"id" : @"value_2",
        @"weight" : val2
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcomeWithValue_inIAMDirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Receive 1 IAM and send outcomes from action
    [[OneSignal sessionManager] onDirectInfluenceFromIAMClick:@"test_in_app_message_1"];
    
    let val1 = [NSNumber numberWithDouble:3.4];
    [OneSignal sendOutcomeWithValue:@"value_1" value:val1];
    let val2 = [NSNumber numberWithDouble:9.95];
    [OneSignal sendOutcomeWithValue:@"value_2" value:val2];
    
    // 6. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:2 payload:@{
        @"sources": @{
                @"direct": @{
                       @"in_app_message_ids" : @[@"test_in_app_message_1"],
                },
        },
        @"id" : @"value_1",
        @"weight" : val1
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"direct": @{
                        @"in_app_message_ids" : @[@"test_in_app_message_1"],
                },
        },
        @"id" : @"value_2",
        @"weight" : val2
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testSendingOutcome_inIAMDirectSession_SaveIndirectSession {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Receive 1 IAM and send outcomes from action
    [[OneSignal sessionManager] onInAppMessageReceived:@"test_in_app_message_1"];
    [[OneSignal sessionManager] onDirectInfluenceFromIAMClick:@"test_in_app_message_1"];
    
    let val1 = [NSNumber numberWithDouble:3.4];
    [OneSignal sendOutcomeWithValue:@"value_1" value:val1];
    let val2 = [NSNumber numberWithDouble:9.95];
    [OneSignal sendOutcomeWithValue:@"value_2" value:val2];
    
    // 3. Make sure 2 measure requests were made with correct params
    [RestClientAsserts assertMeasureSourcesAtIndex:2 payload:@{
        @"sources": @{
                @"direct": @{
                       @"in_app_message_ids" : @[@"test_in_app_message_1"],
                },
        },
        @"id" : @"value_1",
        @"weight" : val1
    }];
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"direct": @{
                        @"in_app_message_ids" : @[@"test_in_app_message_1"],
                },
        },
        @"id" : @"value_2",
        @"weight" : val2
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
    
    // 4. If we don't dissmiss IAM indirect session shoud be cached
    [[OneSignal sessionManager] initSessionFromCache];
    let sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
        }
    }
}


- (void)testAttributedIndirectSession_cachedUniqueOutcomeIAMsCleanedAfter7Days {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive 3 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 5. Validate new NOTIFICATION influence is INDIRECT and send 2 of the same unique outcomes
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 3);
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2", @"test_notification_3"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:1];
    
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
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 10. Validate new NOTIFICATION influence is INDIRECT and send the same 2 unique outcomes
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 3);
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total
    [RestClientAsserts assertMeasureSourcesAtIndex:6 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2", @"test_notification_3"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testAttributedDirectSession_cachedUniqueOutcomeIAMsCleanedAfter7Days {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive a few notifications and open 1
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    [UnitTestCommonMethods receiveNotification:@"test_notification_3" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 5. Validate new influences are ATTRIBUTED (DIRECT or INDIRECT) and send 2 of the same unique outcomes
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_2"]];
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureSourcesAtIndex:4 payload:@{
        @"sources": @{
                @"direct": @{
                        @"notification_ids" : @[@"test_notification_2"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:1];
    
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
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_2"]];
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total
    [RestClientAsserts assertMeasureSourcesAtIndex:7 payload:@{
        @"sources": @{
                @"direct": @{
                        @"notification_ids" : @[@"test_notification_2"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}

- (void)testAttributedIndirectSession_sendsUniqueOutcomeForNewNIAMs_andNotCachedIAMs {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Close the app for 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:31];

    // 3. Receive 2 notifications
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:NO];

    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];

    // 5. Validate new NOTIFICATION influence is ATTRIBUTED (DIRECT or INDIRECT) and send 1 unique outcome
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 2);
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];
    
    // 6. Make sure only 1 measure request has been made
    [RestClientAsserts assertMeasureSourcesAtIndex:3 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_1", @"test_notification_2"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:1];
    
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

    // 10. Validate new NOTIFICATION influence is ATTRIBUTED (DIRECT or INDIRECT) and send the same unique outcome
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 5);
        }
    }
    [OneSignal sendUniqueOutcome:@"unique"];

    // 11. Make sure 2 measure requests have been made in total and does not include already sent notification ids for the unique outcome
    [RestClientAsserts assertMeasureSourcesAtIndex:6 payload:@{
        @"sources": @{
                @"indirect": @{
                        @"notification_ids" : @[@"test_notification_3"],
                },
        },
        @"id" : @"unique"
    }];
    [RestClientAsserts assertNumberOfMeasureSourcesRequests:2];
}


- (void)testUnattributedSessionToDirectSessionWhileInactive {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // 2. Make sure IN_APP_MESSAGE influence is UNATTRIBUTED and Notifications is UNATTRIBUTED
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
        }
    }

    //Make app inactive. This actually involves backgrounding foregroudning backgrounding and then inactive.
    [UnitTestCommonMethods pullDownNotificationCenter];

    // 3. Receive 1 notification and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    
    // 5. Make sure IN_APP_MESSAGE influence is UNATTRIBUTED and Notifications is direct
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_1"]];
                break;
        }
    }
}

- (void)testDirectSessionToDirectSessionWhileInactive {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    [UnitTestCommonMethods pullDownNotificationCenter];
    
    // 2. Make sure IN_APP_MESSAGE influence is UNATTRIBUTED and Notifications is UNATTRIBUTED
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];

    // 3. Receive notification 1 and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:YES];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    
    // 5. Make sure IN_APP_MESSAGE influence is UNATTRIBUTED and Notifications is direct
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_1"]];
                break;
        }
    }
    
    //Make app inactive. This actually involves backgrounding foregroudning backgrounding and then inactive.
    [UnitTestCommonMethods pullDownNotificationCenter];
    
    // 6. Receive notification 2 and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    
    // 7. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    
    // 8. Make sure IN_APP_MESSAGE influence is UNATTRIBUTED and Notifications is direct
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_2"]];
                break;
        }
    }
}

- (void)testIndirectSessionToDirectSessionWhileInactive {
    // 1. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    [[OneSignal outcomeEventsCache] saveOutcomesV2ServiceEnabled:YES];
    
    // Background app
    [UnitTestCommonMethods backgroundApp];
    
    // 2. Make sure IN_APP_MESSAGE influence is UNATTRIBUTED and Notifications is UNATTRIBUTED
    NSArray<OSInfluence *> *sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];

    // 3. Receive notification 1 and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_1" wasOpened:NO];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    
    // 5. Make sure IN_APP_MESSAGE influence is UNATTRIBUTED and Notifications is INDIRECT
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_1"]];
                break;
        }
    }
    
    //Make app inactive. This actually involves backgrounding foregroudning backgrounding and then inactive.
    [UnitTestCommonMethods pullDownNotificationCenter];
    
    // 6. Receive notification 2 and open it
    [UnitTestCommonMethods receiveNotification:@"test_notification_2" wasOpened:YES];
    
    // 7. Open app
    [UnitTestCommonMethods initOneSignal_andThreadWaitWithForeground];
    
    // 8. Make sure IN_APP_MESSAGE influence is UNATTRIBUTED and Notifications is direct
    sessionInfluences = [[OSSessionManager sharedSessionManager] getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[@"test_notification_2"]];
                break;
        }
    }
}

@end
