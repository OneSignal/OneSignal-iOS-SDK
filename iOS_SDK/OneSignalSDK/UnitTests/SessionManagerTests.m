/**
 * Modified MIT License
 *
 * Copyright 2020 OneSignal
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
#import <Foundation/Foundation.h>

#import "OSSessionManager.h"
#import "OSTrackerFactory.h"
#import "OSOutcomeEventsCache.h"
#import "OSOutcomeEventsFactory.h"

#import "OneSignalOutcomeEventsController.h"
#import "OneSignalHelper.h"

#import "UnitTestCommonMethods.h"
#import "CommonAsserts.h"

@interface SessionManagerTests<SessionStatusDelegate> : XCTestCase
@end

@implementation SessionManagerTests {
    NSString *testGenericId;
    NSString *testNotificationId;
    NSString *testIAMId;
    OSTrackerFactory *trackerFactory;
    OSSessionManager *sessionManager;
}

int INFLUENCE_ID_LIMIT = 10;
NSArray<OSInfluence *> *lastInfluencesBySessionEnding;

+ (void)onSessionEnding:(NSArray<OSInfluence *> * _Nonnull)lastInfluences {
    lastInfluencesBySessionEnding = lastInfluences;
}

- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    lastInfluencesBySessionEnding = nil;
    testGenericId = @"test_testGenericId";
    testNotificationId = @"test_testNotificationId";
    testIAMId = @"test_iam_id";
    trackerFactory = [[OSTrackerFactory alloc] initWithRepository:[[OSInfluenceDataRepository alloc] init]];
    sessionManager = [[OSSessionManager alloc] init:SessionManagerTests.self withTrackerFactory:trackerFactory];
}

- (void)setOutcomesParamsEnabled {
    [trackerFactory saveInfluenceParams:@{
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
    [trackerFactory saveInfluenceParams:@{
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

- (void)testUnattributedInitInfluence {
    [self setOutcomesParamsEnabled];
    
    let sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
        XCTAssertEqual(influence.ids, nil);
    }
}

- (void)testInfluenceIdsSaved {
    [self setOutcomesParamsEnabled];
    [trackerFactory initFromCache];
    
    XCTAssertEqual(0, [[trackerFactory notificationChannelTracker] lastReceivedIds].count);
    XCTAssertEqual(0, [[trackerFactory iamChannelTracker] lastReceivedIds].count);

    [[trackerFactory notificationChannelTracker] saveLastId:testNotificationId];
    [[trackerFactory iamChannelTracker] saveLastId:testIAMId];

    let lastNotificationIds = [[trackerFactory notificationChannelTracker] lastReceivedIds];
    let lastIAMIds = [[trackerFactory iamChannelTracker] lastReceivedIds];

    XCTAssertEqual(1, lastNotificationIds.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:lastNotificationIds];
    XCTAssertEqual(1, lastIAMIds.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:lastIAMIds];
}

- (void)testIndirectInfluence {
    [self setOutcomesParamsEnabled];
    [sessionManager onInAppMessageReceived:testGenericId];
    [sessionManager onNotificationReceived:testGenericId];
    [sessionManager restartSessionIfNeeded:APP_OPEN];

    for (OSInfluence *influence in [sessionManager getInfluences]) {
        XCTAssertTrue([influence isIndirectInfluence]);
        XCTAssertEqual(1, influence.ids.count);
        [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:influence.ids];
    }
}

- (void)testIndirectNotificationInitInfluence {
    [self setOutcomesParamsEnabled];
    
    OSChannelTracker *notificationTracker = [trackerFactory notificationChannelTracker];
    XCTAssertEqual(0, [notificationTracker lastReceivedIds].count);
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager attemptSessionUpgrade:APP_OPEN];

    notificationTracker = [trackerFactory notificationChannelTracker];
    OSInfluence *influence = [notificationTracker currentSessionInfluence];

    XCTAssertEqual(INDIRECT, notificationTracker.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:notificationTracker.lastReceivedIds];
    XCTAssertEqual(NOTIFICATION, influence.influenceChannel);
    XCTAssertEqual(INDIRECT, influence.influenceType);
    XCTAssertEqual(1, influence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:influence.ids];
}


- (void)testDirectNotificationInitInfluence {
    [self setOutcomesParamsEnabled];

    OSChannelTracker *notificationTracker = [trackerFactory notificationChannelTracker];
    XCTAssertEqual(0, [notificationTracker lastReceivedIds].count);
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];

    notificationTracker = [trackerFactory notificationChannelTracker];
    OSInfluence *influence = [notificationTracker currentSessionInfluence];

    XCTAssertEqual(DIRECT, notificationTracker.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:notificationTracker.lastReceivedIds];
    XCTAssertEqual(NOTIFICATION, influence.influenceChannel);
    XCTAssertEqual(DIRECT, influence.influenceType);
    XCTAssertEqual(1, influence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:influence.ids];
}

- (void)testIndirectIAMInitInfluence {
    [self setOutcomesParamsEnabled];

    OSChannelTracker *iamTracker = [trackerFactory iamChannelTracker];
    XCTAssertEqual(0, [iamTracker lastReceivedIds].count);

    [sessionManager onInAppMessageReceived:testIAMId];
    [sessionManager attemptSessionUpgrade:APP_OPEN];

    iamTracker = [trackerFactory iamChannelTracker];
    OSInfluence *influence = [iamTracker currentSessionInfluence];

    XCTAssertEqual(INDIRECT, [iamTracker influenceType]);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:iamTracker.lastReceivedIds];
    XCTAssertEqual(IN_APP_MESSAGE, influence.influenceChannel);
    XCTAssertEqual(INDIRECT, influence.influenceType);
    XCTAssertEqual(1, influence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:influence.ids];
}

- (void)testDirectIAMInitInfluence {
    [self setOutcomesParamsEnabled];

    OSChannelTracker *iamTracker = [trackerFactory iamChannelTracker];
    XCTAssertEqual(0, [iamTracker lastReceivedIds].count);

    [sessionManager onInAppMessageReceived:testIAMId];
    [sessionManager onDirectInfluenceFromIAMClick:testIAMId];

    iamTracker = [trackerFactory iamChannelTracker];
    OSInfluence *influence = [iamTracker currentSessionInfluence];

    XCTAssertEqual(DIRECT, iamTracker.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:iamTracker.lastReceivedIds];
    XCTAssertEqual(IN_APP_MESSAGE, influence.influenceChannel);
    XCTAssertEqual(DIRECT, influence.influenceType);
    XCTAssertEqual(1, influence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:influence.ids];
}

- (void)testDirectIAMResetInfluence {
    [self setOutcomesParamsEnabled];

    OSChannelTracker *iamTracker = [trackerFactory iamChannelTracker];
    XCTAssertEqual(0, [iamTracker lastReceivedIds].count);

    [sessionManager onInAppMessageReceived:testIAMId];
    [sessionManager onDirectInfluenceFromIAMClick:testIAMId];
    [sessionManager onDirectInfluenceFromIAMClickFinished];

    iamTracker = [trackerFactory iamChannelTracker];
    OSInfluence *influence = [iamTracker currentSessionInfluence];

    XCTAssertEqual(INDIRECT, iamTracker.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:iamTracker.lastReceivedIds];
    XCTAssertEqual(IN_APP_MESSAGE, influence.influenceChannel);
    XCTAssertEqual(INDIRECT, influence.influenceType);
    XCTAssertEqual(1, influence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:influence.ids];
}

- (void)testDirectWithnilNotification {
    [self setOutcomesParamsEnabled];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wnonnull"
    [sessionManager onNotificationReceived:nil];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:nil];
    #pragma clang diagnostic pop
    OSInfluence *influence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(UNATTRIBUTED, influence.influenceType);
    XCTAssertNil(influence.ids);
}

- (void)testDirectWithEmptyNotification {
    [self setOutcomesParamsEnabled];

    [sessionManager onNotificationReceived:@""];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:@""];

    OSInfluence *influence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(UNATTRIBUTED, influence.influenceType);
    XCTAssertNil(influence.ids);
}

- (void)testSessionUpgradeFromAppClosed {
    [self setOutcomesParamsEnabled];

    NSArray<OSInfluence *> *influences = [sessionManager getInfluences];

    for (OSInfluence *influence in influences) {
        XCTAssertEqual(UNATTRIBUTED, influence.influenceType);
        XCTAssertNil(influence.ids);
    }

    [sessionManager onNotificationReceived:testGenericId];
    [sessionManager onInAppMessageReceived:testGenericId];
    [sessionManager attemptSessionUpgrade:APP_CLOSE];

    influences = [sessionManager getInfluences];

    for (OSInfluence *influence in influences) {
        switch (influence.influenceChannel) {
            case NOTIFICATION:
                XCTAssertEqual(UNATTRIBUTED, influence.influenceType);
                XCTAssertNil(influence.ids);
                break;
            default:
                break;
        }
    }

    // We test that channel ending is working
    XCTAssertNil(lastInfluencesBySessionEnding);
}

- (void)testSessionUpgradeFromUnattributedToIndirect {
    [self setOutcomesParamsEnabled];

    NSArray<OSInfluence *> *influences = [sessionManager getInfluences];

    for (OSInfluence *influence in influences) {
        XCTAssertEqual(UNATTRIBUTED, influence.influenceType);
        XCTAssertNil(influence.ids);
    }

    [sessionManager onNotificationReceived:testGenericId];
    [sessionManager onInAppMessageReceived:testGenericId];
    [sessionManager onDirectInfluenceFromIAMClickFinished];
    
    [sessionManager attemptSessionUpgrade:APP_OPEN];

    influences = [sessionManager getInfluences];

    for (OSInfluence *influence in influences) {
        XCTAssertEqual(INDIRECT, influence.influenceType);
        XCTAssertEqual(1, influence.ids.count);
        [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:influence.ids];
    }

    // We test that channel ending is working for Notification
    // IAM was already indirect
    XCTAssertEqual(1, lastInfluencesBySessionEnding.count);
    OSInfluence *endingNotificationInfluence = [lastInfluencesBySessionEnding objectAtIndex:0];

    XCTAssertEqual(NOTIFICATION, endingNotificationInfluence.influenceChannel);
    XCTAssertEqual(UNATTRIBUTED, endingNotificationInfluence.influenceType);
    XCTAssertNil(endingNotificationInfluence.ids);
}

- (void)testSessionUpgradeFromUnattributedToDirectNotification {
    [self setOutcomesParamsEnabled];

    OSInfluence *iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    OSInfluence *notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(UNATTRIBUTED, iamInfluence.influenceType);
    XCTAssertEqual(UNATTRIBUTED, notificationInfluence.influenceType);

    [sessionManager onNotificationReceived:testGenericId];
    [sessionManager onInAppMessageReceived:testGenericId];
    [sessionManager onDirectInfluenceFromIAMClickFinished];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testGenericId];

    iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(INDIRECT, iamInfluence.influenceType);
    XCTAssertEqual(1, [iamInfluence ids].count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:iamInfluence.ids];

    XCTAssertEqual(DIRECT, notificationInfluence.influenceType);
    XCTAssertEqual(1, [notificationInfluence ids].count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:notificationInfluence.ids];

    // We test that channel ending is working for Notification
    // IAM was already indirect
    XCTAssertEqual(1, lastInfluencesBySessionEnding.count);
    OSInfluence *endingNotificationInfluence = [lastInfluencesBySessionEnding objectAtIndex:0];

    XCTAssertEqual(NOTIFICATION, endingNotificationInfluence.influenceChannel);
    XCTAssertEqual(UNATTRIBUTED, endingNotificationInfluence.influenceType);
    XCTAssertNil(endingNotificationInfluence.ids);
}

- (void)testSessionUpgradeFromIndirectToDirect {
    [self setOutcomesParamsEnabled];

    [sessionManager onNotificationReceived:testGenericId];
    [sessionManager onInAppMessageReceived:testGenericId];
    [sessionManager attemptSessionUpgrade:APP_OPEN];

    OSInfluence *iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    OSInfluence *notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];
    
    XCTAssertEqual(INDIRECT, iamInfluence.influenceType);
    XCTAssertEqual(INDIRECT, notificationInfluence.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:notificationInfluence.ids];

    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];

    iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(INDIRECT, iamInfluence.influenceType);
    XCTAssertEqual(1, [iamInfluence ids].count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:iamInfluence.ids];

    XCTAssertEqual(DIRECT, notificationInfluence.influenceType);
    XCTAssertEqual(1, [notificationInfluence ids].count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:notificationInfluence.ids];

    // We test that channel ending is working for both IAM and Notification
    XCTAssertEqual(1, lastInfluencesBySessionEnding.count);
    OSInfluence *endingNotificationInfluence = [lastInfluencesBySessionEnding objectAtIndex:0];

    XCTAssertEqual(NOTIFICATION, endingNotificationInfluence.influenceChannel);
    XCTAssertEqual(INDIRECT, endingNotificationInfluence.influenceType);
    XCTAssertEqual(1, endingNotificationInfluence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:endingNotificationInfluence.ids];
}

- (void)testSessionUpgradeFromDirectToDirectDifferentID {
    [self setOutcomesParamsEnabled];

    [sessionManager onNotificationReceived:testGenericId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testGenericId];

    OSInfluence *notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(DIRECT, notificationInfluence.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:notificationInfluence.ids];

    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];

    notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(DIRECT, notificationInfluence.influenceType);
    XCTAssertEqual(1, [notificationInfluence ids].count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:notificationInfluence.ids];

    // We test that channel ending is working
    XCTAssertEqual(1, lastInfluencesBySessionEnding.count);
    XCTAssertEqual(NOTIFICATION, [lastInfluencesBySessionEnding objectAtIndex:0].influenceChannel);
    XCTAssertEqual(DIRECT, [lastInfluencesBySessionEnding objectAtIndex:0].influenceType);
    XCTAssertEqual(1, [lastInfluencesBySessionEnding objectAtIndex:0].ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:[lastInfluencesBySessionEnding objectAtIndex:0].ids];
}

- (void)testSessionUpgradeFromDirectToDirectSameID {
    [self setOutcomesParamsEnabled];

    [sessionManager onNotificationReceived:testGenericId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testGenericId];

    OSInfluence *notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(DIRECT, notificationInfluence.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:notificationInfluence.ids];

    [sessionManager attemptSessionUpgrade:NOTIFICATION_CLICK];

    notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(DIRECT, notificationInfluence.influenceType);
    XCTAssertEqual(1, notificationInfluence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:notificationInfluence.ids];

    // We test that channel ending is working
    XCTAssertEqual(1, lastInfluencesBySessionEnding.count);
    XCTAssertEqual(NOTIFICATION, [lastInfluencesBySessionEnding objectAtIndex:0].influenceChannel);
    XCTAssertEqual(UNATTRIBUTED, [lastInfluencesBySessionEnding objectAtIndex:0].influenceType);
    XCTAssertNil([lastInfluencesBySessionEnding objectAtIndex:0].ids);
}

- (void)testSessionUpgradeFromDirectToDirectEndChannelsDirect {
    [self setOutcomesParamsEnabled];

    [sessionManager onNotificationReceived:testGenericId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testGenericId];
    [sessionManager onInAppMessageReceived:testIAMId];
    [sessionManager onDirectInfluenceFromIAMClick:testIAMId];

    OSInfluence *iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    OSInfluence *notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(DIRECT, iamInfluence.influenceType);
    XCTAssertEqual(DIRECT, notificationInfluence.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:iamInfluence.ids];
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:notificationInfluence.ids];

    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];

    iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(DIRECT, notificationInfluence.influenceType);
    XCTAssertEqual(1, notificationInfluence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:notificationInfluence.ids];
    XCTAssertEqual(INDIRECT, iamInfluence.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:iamInfluence.ids];

    // We test that channel ending is working for both IAM and Notification
    XCTAssertEqual(2, lastInfluencesBySessionEnding.count);
    OSInfluence *endingNotificationInfluence = [lastInfluencesBySessionEnding objectAtIndex:0];
    OSInfluence *endingIAMInfluence = [lastInfluencesBySessionEnding objectAtIndex:1];

    XCTAssertEqual(NOTIFICATION, endingNotificationInfluence.influenceChannel);
    XCTAssertEqual(DIRECT, endingNotificationInfluence.influenceType);
    XCTAssertEqual(1, endingNotificationInfluence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testGenericId] actual:endingNotificationInfluence.ids];

    XCTAssertEqual(IN_APP_MESSAGE, endingIAMInfluence.influenceChannel);
    XCTAssertEqual(DIRECT, endingIAMInfluence.influenceType);
    XCTAssertEqual(1, endingIAMInfluence.ids.count);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:endingIAMInfluence.ids];
}

- (void)testRestartSessionIfNeededFromOpen {
    [self setOutcomesParamsEnabled];

    [sessionManager onInAppMessageReceived:testIAMId];
    [sessionManager onDirectInfluenceFromIAMClickFinished];
    [sessionManager onNotificationReceived:testNotificationId];

    [sessionManager restartSessionIfNeeded:APP_OPEN];

    OSInfluence *iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    OSInfluence *notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(INDIRECT, iamInfluence.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:iamInfluence.ids];
    XCTAssertEqual(INDIRECT, notificationInfluence.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testNotificationId] actual:notificationInfluence.ids];
}

- (void)testRestartSessionIfNeededFromClose {
    [self setOutcomesParamsEnabled];

    [sessionManager onInAppMessageReceived:testIAMId];
    [sessionManager onDirectInfluenceFromIAMClickFinished];
    [sessionManager onNotificationReceived:testNotificationId];

    [sessionManager restartSessionIfNeeded:APP_CLOSE];

    OSInfluence *iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    OSInfluence *notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(INDIRECT, iamInfluence.influenceType);
    XCTAssertEqual(1, iamInfluence.ids.count);
    XCTAssertEqual(UNATTRIBUTED, notificationInfluence.influenceType);
    XCTAssertNil(notificationInfluence.ids);
}

- (void)testRestartSessionIfNeededFromNotification {
    [self setOutcomesParamsEnabled];

    [sessionManager onInAppMessageReceived:testIAMId];
    [sessionManager onNotificationReceived:testNotificationId];

    [sessionManager restartSessionIfNeeded:NOTIFICATION_CLICK];

    OSInfluence *iamInfluence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    OSInfluence *notificationInfluence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];

    XCTAssertEqual(INDIRECT, iamInfluence.influenceType);
    [CommonAsserts assertArrayEqualsWithExpected:@[testIAMId] actual:iamInfluence.ids];
    XCTAssertEqual(UNATTRIBUTED, notificationInfluence.influenceType);
    XCTAssertNil(notificationInfluence.ids);
}

- (void)testIndirectNotificationQuantityInfluence {
    [self setOutcomesParamsEnabled];

    for (int i = 0; i < INFLUENCE_ID_LIMIT + 5; i++) {
        [sessionManager onNotificationReceived:[NSString stringWithFormat:@"%@%d", testGenericId, i]];
    }

    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    OSInfluence *influence = [[trackerFactory notificationChannelTracker] currentSessionInfluence];
    XCTAssertTrue([influence isIndirectInfluence]);
    XCTAssertEqual(INFLUENCE_ID_LIMIT, influence.ids.count);
    let expectId = [NSString stringWithFormat:@"%@%d", testGenericId, 5];
    XCTAssertTrue([expectId isEqualToString:[[influence.ids objectAtIndex:0] description]]);
}

- (void)testIndirectIAMQuantityInfluence {
    [self setOutcomesParamsEnabled];

    for (int i = 0; i < INFLUENCE_ID_LIMIT + 5; i++) {
        [sessionManager onInAppMessageReceived:[NSString stringWithFormat:@"%@%d", testGenericId, i]];
    }

    [sessionManager restartSessionIfNeeded:APP_OPEN];

    OSInfluence *influence = [[trackerFactory iamChannelTracker] currentSessionInfluence];
    XCTAssertTrue([influence isIndirectInfluence]);
    XCTAssertEqual(INFLUENCE_ID_LIMIT, influence.ids.count);
    let expectId = [NSString stringWithFormat:@"%@%d", testGenericId, 5];
    XCTAssertTrue([expectId isEqualToString:[[influence.ids objectAtIndex:0] description]]);
}

@end
