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
#import "OSSessionManager.h"
#import "OSTrackerFactory.h"
#import "OSOutcomeEventsCache.h"
#import "OSOutcomeEventsFactory.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalOverrider.h"
#import "OSInfluence.h"
#import "OneSignalHelper.h"
#import "UnitTestCommonMethods.h"
#import "CommonAsserts.h"
#import "OneSignalNotificationServiceExtensionHandler.h"
  
@interface OutcomeTests<SessionStatusDelegate> : XCTestCase
@end

@implementation OutcomeTests {
    NSString *testNotificationId;
    OSSessionManager *sessionManager;
    OSTrackerFactory *trackerFactory;
    OSOutcomeEventsCache *outcomeEventsCache;
    OSOutcomeEventsFactory *outcomeTrackerFactory;
    OneSignalOutcomeEventsController *outcomesController;
}

+ (void)onSessionEnding:(NSArray<OSInfluence *> * _Nonnull)lastInfluences {}

/*
 Put setup code here
 This method is called before the invocation of each test method in the class
 */
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    testNotificationId = @"test_notification_id";
    trackerFactory = [[OSTrackerFactory alloc] initWithRepository:[[OSInfluenceDataRepository alloc] init]];
    sessionManager = [[OSSessionManager alloc] init:OutcomeTests.self withTrackerFactory:trackerFactory];
    outcomeTrackerFactory = [[OSOutcomeEventsFactory alloc] initWithCache:outcomeEventsCache];
    outcomesController = [[OneSignalOutcomeEventsController alloc] initWithSessionManager:sessionManager outcomeEventsFactory:outcomeTrackerFactory];
}

/*
 Put teardown code here
 This method is called after the invocation of each test method in the class
 */
- (void)tearDown {
    [super tearDown];
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

- (void)testUnattributedSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];

    // 2. Make sure all influences are UNATTRIBUTED and has no ids
    let sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
        XCTAssertEqual(influence.ids, nil);
    }
}

- (void)testIndirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive 3 notifications
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onNotificationReceived:testNotificationId];
    
    // 3. Init sessionManager and attempt to restart the session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    // 4. Make sure NOTIFICATION influence is INDIRECT and has 3 notifications
    let sessionInfluences = [sessionManager getInfluences];
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
}

- (void)testDirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive 1 notification and click it
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];
    
    // 3. Init sessionManager and attempt to restart the session
    [sessionManager initSessionFromCache];
    
    // 4. Make sure NOTIFICATION influence is DIRECT and has 1 notification
    let sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
        }
    }
}

- (void)testUnattributedSessionToIndirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    // 3. Make sure all influences are UNATTRIBUTED and has no ids
    NSArray<OSInfluence *> *sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
        XCTAssertEqual(influence.ids, nil);
    }
    
    // 4. Receive 3 notifications
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onNotificationReceived:testNotificationId];
    
    // 5. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    // 6. Make sure NOTIFICATION influence is INDIRECT and has 3 notifications
    sessionInfluences = [sessionManager getInfluences];
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
}

- (void)testIndirectSession_wontOverrideIndirectSession_withoutNewSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive a notification
    [sessionManager onNotificationReceived:testNotificationId];
    
    // 3. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    // 6. Make sure NOTIFICATION influence is INDIRECT and has 1 notification
    NSArray<OSInfluence *> *sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 1);
        }
    }
    
    // 4. Receive 3 more notifications
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onNotificationReceived:testNotificationId];
    
    // 5. Init sessionManager without new session
    [sessionManager initSessionFromCache];

    // 6. Make sure NOTIFICATION influence is INDIRECT and has 1 notification
    sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 1);
        }
    }
}

- (void)testUnattributedSessionToDirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive a notification and open it
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];
    
    // 3. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 4. Make sure session
    let sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[testNotificationId]];
        }
    }
}

- (void)testIndirectSessionToDirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive 2 notifications
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onNotificationReceived:testNotificationId];

    // 3. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    // 4. Make sure NOTIFICATION influence is INDIRECT and has 2 notification
    NSArray<OSInfluence *> *sessionInfluences = [sessionManager getInfluences];
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
    
    // 5. Receive a notification and open it
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];
    
    // 6. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 7. Make sure NOTIFICATION influence is DIRECT and has 1 notification
    sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
        }
    }
}

- (void)testDirectSessionToDirectSession {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    let firstTestNotificationId = @"test";
    // 2. Receieve a notification and open it
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:firstTestNotificationId];
    
    // 3. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    NSArray<OSInfluence *> *sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[firstTestNotificationId]];
        }
    }

    // 4. Receieve a notification and open it
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];
    
    // 5. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 6. Make sure NOTIFICATION influence is DIRECT and has 1 notifciation
    sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DIRECT);
                XCTAssertEqual(influence.ids.count, 1);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:@[testNotificationId]];
        }
    }
}

- (void)testUnattributedSession_whenOutcomesIsDisabled {
    // 1. Set outcome params disabled
    [self setOutcomesParamsDisabled];
    
    // 2. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    // 3. Make sure all influences are DISABLED and no ids exist
    let sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, DISABLED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DISABLED);
                XCTAssertEqual(influence.ids, nil);
        }
    }
}

- (void)testIndirectSession_whenOutcomesIsDisabled {
    // 1. Set outcome params disabled
    [self setOutcomesParamsDisabled];
    
    // 2. Receive 2 notifications
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onNotificationReceived:testNotificationId];
    
    // 3. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    // 4. Make sure all influences are DISABLED and no ids exist
    let sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, DISABLED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DISABLED);
                XCTAssertEqual(influence.ids, nil);
        }
    }
}

- (void)testDirectSession_whenOutcomesIsDisabled {
    // 1. Set outcome params disabled
    [self setOutcomesParamsDisabled];
    
    // 2. Receieve a notification and open it
    [sessionManager onNotificationReceived:testNotificationId];
    [sessionManager onDirectInfluenceFromNotificationOpen:NOTIFICATION_CLICK withNotificationId:testNotificationId];
    
    // 3. Init sessionManager without new session
    [sessionManager initSessionFromCache];
    
    // 4. Make sure all influences are DISABLED and no ids exist
    let sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, DISABLED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, DISABLED);
                XCTAssertEqual(influence.ids, nil);
        }
    }
}

- (void)testIndirectSession_attributionNotificationLimit {
    // 1. Set outcome params enabled
    [self setOutcomesParamsEnabled];
    
    // 2. Receive 15 notifications
    NSMutableArray *recentNotifIds = [NSMutableArray new];
    for (int i = 0; i <= 15; i++) {
        NSString *notifId = [NSString stringWithFormat:@"test_notification_%i", i + 1];
        [sessionManager onNotificationReceived:notifId];
        
        // Add the most recent 10 notifications by removing 0 index after count passes 10
        [recentNotifIds addObject:notifId];
        if (recentNotifIds.count > 10)
            [recentNotifIds removeObjectAtIndex:0];
    }
    
    // 3. Init sessionManager and attempt to start a new session
    [sessionManager initSessionFromCache];
    [sessionManager restartSessionIfNeeded:APP_OPEN];
    
    // 4. Make sure session is INDIRECT and only has the most recent 10 notifications
    let sessionInfluences = [sessionManager getInfluences];
    for (OSInfluence *influence in sessionInfluences) {
        switch (influence.influenceChannel) {
            case IN_APP_MESSAGE:
                XCTAssertEqual(influence.influenceType, UNATTRIBUTED);
                XCTAssertEqual(influence.ids, nil);
                break;
            case NOTIFICATION:
                XCTAssertEqual(influence.influenceType, INDIRECT);
                XCTAssertEqual(influence.ids.count, 10);
                [CommonAsserts assertArrayEqualsWithExpected:influence.ids actual:recentNotifIds];
        }
    }
}

@end
