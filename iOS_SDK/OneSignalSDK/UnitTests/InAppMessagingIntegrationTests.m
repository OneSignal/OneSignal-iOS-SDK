/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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
#import "OneSignal.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalHelper.h"
#import "OneSignalUserDefaults.h"
#import "OSInAppMessage.h"
#import "OSTrigger.h"
#import "OSTriggerController.h"
#import "OSInAppMessagingDefines.h"
#import "OSDynamicTriggerController.h"
#import "NSTimerOverrider.h"
#import "UnitTestCommonMethods.h"
#import "OSInAppMessagingHelpers.h"
#import "OSMessagingController.h"
#import "OneSignalClientOverrider.h"
#import "UIApplicationOverrider.h"
#import "OneSignalHelperOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "NSUserDefaultsOverrider.h"
#import "NSBundleOverrider.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "Requests.h"
#import "OSMessagingControllerOverrider.h"
#import "OneSignalOverrider.h"
#import "OneSignalClientOverrider.h"
#import "NSLocaleOverrider.h"
#import "OSInAppMessageController.h"
#import "NSDateOverrider.h"
#import "OSInAppMessageTag.h"
#import "NSObjectOverrider.h"

@interface InAppMessagingIntegrationTests : XCTestCase

@end

@implementation InAppMessagingIntegrationTests

- (void)setUp {
    [super setUp];
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalClientOverrider reset:self];
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [UnitTestCommonMethods beforeEachTest:self];
    
    [OneSignalHelperOverrider reset];
    
    NSTimerOverrider.shouldScheduleTimers = false;
}

-(void)tearDown {
    OneSignalOverrider.shouldOverrideSessionLaunchTime = false;
    
    [OSMessagingController.sharedInstance resetState];
    
    NSTimerOverrider.shouldScheduleTimers = true;
    
    // Set to false so that we don't interfere with other tests
    [OneSignal pauseInAppMessages:false];
}

/**
 Make sure on_session IAMs are pulled for the specific app_id
 For this test we have mocked a single IAM in the on_session request
 After first on_session IAMs are setup to be used by controller
*/
- (void)testIAMsAvailable_afterOnSession {
    // 1. Make sure 0 IAMs are persisted
    NSArray *cachedMessages = [OneSignalUserDefaults.initStandard getSavedCodeableDataForKey:OS_IAM_MESSAGES_ARRAY defaultValue:nil];
    XCTAssertNil(cachedMessages);
    
    // 2. Open app
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Kill the app and wait 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 5. Ensure the last network call is an on_session
    // Total calls - 2 ios params + player create + on_session = 4 requests
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"players/1234/on_session"));
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    
    // 6. Make sure IAMs are available,but not in queue
    XCTAssertTrue([OSMessagingController.sharedInstance getInAppMessages].count > 0);
    
    // 7. Make sure 1 IAM is persisted
    cachedMessages = [OneSignalUserDefaults.initStandard getSavedCodeableDataForKey:OS_IAM_MESSAGES_ARRAY defaultValue:nil];
    XCTAssertEqual(1, cachedMessages.count);
}

/**
 Make sure on_session IAMs are pulled for the specific app_id
 For this test we have mocked a single IAM in the on_session request response
 After first on_session IAMs will be cached, now force quit app and return in less than 30 seconds to make sure cached IAMs are used instead
*/
- (void)testIAMsCacheAvailable_afterOnSession_andAppRestart {
    // 1. Make sure 0 IAMs are persisted
    NSArray *cachedMessages = [OneSignalUserDefaults.initStandard getSavedCodeableDataForKey:OS_IAM_MESSAGES_ARRAY defaultValue:nil];
    XCTAssertNil(cachedMessages);
    
    // 2. Open app
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // 3. Kill the app and wait 31 seconds
    [UnitTestCommonMethods backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 4. Open app
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 5. Ensure the last network call is an on_session
    // Total calls - 2 ios params + player create + on_session = 4 requests
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"players/1234/on_session"));
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    
    // 6. Make sure IAMs are available
    XCTAssertTrue([OSMessagingController.sharedInstance getInAppMessages].count > 0);
    
    // 7. Don't make an on_session call if only out of the app for 10 secounds
    [UnitTestCommonMethods backgroundApp];
    [NSDateOverrider advanceSystemTimeBy:10];
    
    // 8. Make sure no more IAMs exist
    // Make sure when the controller is reset and app is foregrounded we have messages still
    [OSMessagingController.sharedInstance reset];
    XCTAssertTrue([OSMessagingController.sharedInstance getInAppMessages].count == 0);
    
    // 9. Foreground the app
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // 10. Make sure IAMs are available and no extra requests exist
    XCTAssertTrue([OSMessagingController.sharedInstance getInAppMessages].count > 0);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
}

/**
    This test adds an in-app message with a dynamic trigger (session_duration = +30 seconds)
    When the SDK receives this message in the response to the registration request, that it
    correctly sets up a timer for the 30 seconds
*/
- (void)testIAMIsScheduled {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withOperator:OSTriggerOperatorTypeEqualTo withValue:@30];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    // Because the SDK can take a while to initialize, especially on slower machines, we only
    // check to make sure the timer was scheduled within ~3/4ths of a second to the correct time
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(fabs(NSTimerOverrider.mostRecentTimerInterval - 30.0f) < 0.75f);
}

/**
    Once on_session API request is complete, if the SDK receives a message with valid triggers
    (all the triggers for the message evaluate to true), the SDK should display the message. This
    test verifies that the message actually gets displayed.
*/
- (void)testIAMIsDisplayed {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    XCTAssertEqual(OSMessagingControllerOverrider.messageDisplayQueue.count, 1);
}

// if we have two messages that are both valid to displayed add them to the queue (triggers are all true),
- (void)testIAMsDontOverlap {
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop1" withValue:@2];
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop2" withValue:@3];
    
    let firstMessage = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"prop1" withId:@"test_id1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@0];
    let secondMessage = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"prop2" withId:@"test_id2" withOperator:OSTriggerOperatorTypeLessThan withValue:@4];
    
    let registrationJson = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[firstMessage, secondMessage]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationJson];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    XCTAssertEqual(2, OSMessagingControllerOverrider.messageDisplayQueue.count);
}

- (void)testIAMDisplayedAfterTimer {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withOperator:OSTriggerOperatorTypeGreaterThanOrEqualTo withValue:@0];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    OneSignalOverrider.shouldOverrideSessionLaunchTime = false;
    
    let expectation = [self expectationWithDescription:@"wait for timed message to show"];
    expectation.expectedFulfillmentCount = 1;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertEqual(OSMessagingControllerOverrider.messageDisplayQueue.count, 1);
        
        [expectation fulfill];
    });
    
    [self waitForExpectations:@[expectation] timeout:0.2];
}

// If a message has multiple triggers, and one of the triggers is time/duration based, the SDK
// will set up a timer. However, if a normal value-based trigger condition is not true, there is
// no point in setting up a timer until that condition changes.
- (void)testDelaysSettingUpTimers {
    let firstTrigger = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeExists withValue:nil];
    let secondTrigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withOperator:OSTriggerOperatorTypeGreaterThanOrEqualTo withValue:@15];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger, secondTrigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    // the timer shouldn't be scheduled yet
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    
    [OneSignal addTrigger:@"prop1" withValue:@2];
    
    // the timer should be scheduled now that the other trigger condition is true
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
}

- (void)testIAMWithRedisplay {
    let limit = 5;
    let delay = 60;
    let firstTrigger = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeExists withValue:nil];

    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger]] withRedisplayLimit:limit delay:@(delay)];
    
    //Time interval mock
    NSDateComponents* comps = [[NSDateComponents alloc]init];
    comps.year = 2019;
    comps.month = 6;
    comps.day = 10;
    comps.hour = 10;
    comps.minute = 1;

    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate* date = [calendar dateFromComponents:comps];
    NSTimeInterval firstInterval = [date timeIntervalSince1970];
    
    [self initOneSignalWithInAppMessage:message];
    [OSMessagingControllerOverrider setMockDateGenerator: ^NSTimeInterval(void) {
        return firstInterval;
    }];
    
    [OneSignal addTrigger:@"prop1" withValue:@2];
    
    // IAM should be shown instantly and be within the messageDisplayQueue
    XCTAssertEqual(1, OSMessagingControllerOverrider.messageDisplayQueue.count);
    
    // The display should cause an "viewed" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageViewed class]));
    
    let iamDisplayed = [[OSMessagingControllerOverrider messageDisplayQueue] objectAtIndex:0];
    XCTAssertEqual(-1, iamDisplayed.displayStats.lastDisplayTime);
    
    [OSMessagingControllerOverrider dismissCurrentMessage];
    [OneSignalClientOverrider reset:self];
    
    XCTAssertNotNil([[OSMessagingControllerOverrider messagesForRedisplay] objectForKey:message.messageId]);
    OSInAppMessage *dismissedMessage = [[OSMessagingControllerOverrider messagesForRedisplay] objectForKey:message.messageId];
    let lastDisplayTime = dismissedMessage.displayStats.lastDisplayTime;
    XCTAssertEqual(1, dismissedMessage.displayStats.displayQuantity);
    XCTAssertEqual(firstInterval, lastDisplayTime);
    
    XCTAssertEqual(0, OSMessagingControllerOverrider.messageDisplayQueue.count);
    
    comps.minute = 1 + delay/60; // delay/60 -> minutes

    NSDate* secondDate = [calendar dateFromComponents:comps];
    NSTimeInterval secondInterval = [secondDate timeIntervalSince1970];
   
    [OSMessagingControllerOverrider setMockDateGenerator: ^NSTimeInterval(void) {
        return secondInterval;
    }];
    
    [OneSignal addTrigger:@"prop1" withValue:@2];
    
    XCTAssertEqual(1, OSMessagingControllerOverrider.messageDisplayQueue.count);
    // The display should cause an new "viewed" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageViewed class]));
    
    [OSMessagingControllerOverrider dismissCurrentMessage];
    
    XCTAssertNotNil([[OSMessagingControllerOverrider messagesForRedisplay] objectForKey:message.messageId]);
    OSInAppMessage *secondDismissedMessage = [[OSMessagingControllerOverrider messagesForRedisplay] objectForKey:message.messageId];
    let secondLastDisplayTime = secondDismissedMessage.displayStats.lastDisplayTime;
    XCTAssertEqual(2, secondDismissedMessage.displayStats.displayQuantity);
    XCTAssertEqual(secondInterval, secondLastDisplayTime);
    XCTAssertTrue(secondLastDisplayTime - firstInterval >= delay);
}

- (void)testIAMClickLaunchesAPIRequestMultipleTimes_Redisplay {
    let limit = 5;
    let delay = 60;
    let firstTrigger = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeExists withValue:nil];

    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger]] withRedisplayLimit:limit delay:@(delay)];
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message.jsonRepresentation]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    // simulate a button press (action) on the in app message
    let action = [OSInAppMessageAction new];
    action.clickType = @"button";
    action.clickId = @"test_action_id";
    
    [OSMessagingController.sharedInstance messageViewDidSelectAction:message withAction:action];
    // The action should cause an "opened" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageClicked class]));
    
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    let clickedClickIds = [standardUserDefaults getSavedSetForKey:OS_IAM_CLICKED_SET_KEY defaultValue:[NSMutableSet new]];
    
    XCTAssertEqual(1, clickedClickIds.count);
    NSString *clickedId = [[clickedClickIds allObjects] objectAtIndex:0];
    
    XCTAssertEqual(action.clickId, clickedId);
    XCTAssertEqual(1, message.getClickedClickIds.count);
    XCTAssertEqual(action.clickId, [[message.getClickedClickIds allObjects] objectAtIndex:0]);
    
    [message clearClickIds];
    [OneSignalClientOverrider reset:self];
    XCTAssertEqual(0, message.getClickedClickIds.count);
    XCTAssertEqualObjects(nil, OneSignalClientOverrider.lastHTTPRequestType);
    
    [OSMessagingController.sharedInstance messageViewDidSelectAction:message withAction:action];
    // The action should cause an "opened" API request again
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageClicked class]));
    
    let secondClickedClickIds = [standardUserDefaults getSavedSetForKey:OS_IAM_CLICKED_SET_KEY defaultValue:nil];
    
    XCTAssertEqual(1, secondClickedClickIds.count);
    NSString *secondClickedId = [[secondClickedClickIds allObjects] objectAtIndex:0];
       
    XCTAssertEqual(action.clickId, secondClickedId);
    XCTAssertEqual(1, message.getClickedClickIds.count);
    XCTAssertEqual(action.clickId, [[message.getClickedClickIds allObjects] objectAtIndex:0]);
}

// Tests adding & removing trigger values using the public OneSignal trigger methods
- (void)testRemoveTriggers {
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    [OneSignal addTrigger:@"test1" withValue:@"value1"];
    XCTAssertEqual(1, [OneSignal getTriggers].count);
    
    [OneSignal addTriggers:@{@"test2" : @33}];
    XCTAssertEqualObjects(OneSignal.getTriggers[@"test2"], @33);
    XCTAssertEqual(2, [OneSignal getTriggers].count);
    
    [OneSignal addTriggers:@{@"test2" : @"44"}];
    XCTAssertEqual(2, [OneSignal getTriggers].count);
    
    [OneSignal addTriggers:@{@"test3" : @""}];
    XCTAssertEqual(3, [OneSignal getTriggers].count);
    
    [OneSignal removeTriggerForKey:@"test1"];
    XCTAssertNil(OneSignal.getTriggers[@"test1"]);
    XCTAssertNil([OneSignal getTriggerValueForKey:@"test1"]);
    
    XCTAssertEqualObjects(OneSignal.getTriggers[@"test2"], @"44");
    XCTAssertEqualObjects([OneSignal getTriggerValueForKey:@"test3"], @"");

    [OneSignal removeTriggerForKey:@"test2"];
    [OneSignal removeTriggerForKey:@"test3"];
    
    XCTAssertEqual(0, [OneSignal getTriggers].count);
}

- (void)testIAMWithNoTriggersDisplayOnePerSession_Redisplay {
    let limit = 5;
    let delay = 60;

    let message = [OSInAppMessageTestHelper testMessageWithRedisplayLimit:limit delay:@(delay)];
    message.isDisplayedInSession = true;
    //Time interval mock
    NSDateComponents* comps = [[NSDateComponents alloc]init];
    comps.year = 2019;
    comps.month = 6;
    comps.day = 10;
    comps.hour = 10;
    comps.minute = 1;
    
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate* date = [calendar dateFromComponents:comps];
    NSTimeInterval firstInterval = [date timeIntervalSince1970];
    NSMutableDictionary <NSString *, OSInAppMessage *> *redisplayedInAppMessages = [NSMutableDictionary new];
    [redisplayedInAppMessages setObject:message forKey:message.messageId];
    NSMutableSet <NSString *> *seenMessages = [NSMutableSet new];
    [seenMessages addObject:message.messageId];
    
    message.displayStats.lastDisplayTime = firstInterval - delay;
    // Save IAM for redisplay
    [OneSignalUserDefaults.initStandard saveDictionaryForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:redisplayedInAppMessages];
    // Set data for redisplay
    [OSMessagingControllerOverrider setMessagesForRedisplay:redisplayedInAppMessages];
    // Save IAM for dismiss
    [OSMessagingControllerOverrider setSeenMessages:seenMessages];
    [OSMessagingControllerOverrider setMockDateGenerator: ^NSTimeInterval(void) {
        return firstInterval;
    }];
    [self initOneSignalWithInAppMessage:message];
    
    XCTAssertEqual(1, OSMessagingControllerOverrider.messagesForRedisplay.count);
    // IAM should be shown instantly and be within the messageDisplayQueue
    XCTAssertEqual(1, OSMessagingControllerOverrider.messageDisplayQueue.count);
    [OSMessagingControllerOverrider dismissCurrentMessage];
    XCTAssertEqual(0, OSMessagingControllerOverrider.messageDisplayQueue.count);
    
    // Time travel for delay
    comps.minute = 1 + delay/60; // delay/60 -> minutes
    NSDate* secondDate = [calendar dateFromComponents:comps];
    NSTimeInterval secondInterval = [secondDate timeIntervalSince1970];
     
    [OSMessagingControllerOverrider setMockDateGenerator: ^NSTimeInterval(void) {
        return secondInterval;
    }];
    
    // Add trigger to call evaluateInAppMessage
    [OneSignal addTrigger:@"prop1" withValue:@2];
    // IAM shouldn't display again because It don't have triggers
    XCTAssertEqual(0, OSMessagingControllerOverrider.messageDisplayQueue.count);
}

- (void)testIAMShowAfterRemoveTrigger_Redisplay {
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop1" withValue:@2];
    let limit = 5;
    let delay = 60;
    let firstTrigger = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeNotExists withValue:@(2)];

    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger]] withRedisplayLimit:limit delay:@(delay)];
      
    //Time interval mock
    NSDateComponents* comps = [[NSDateComponents alloc]init];
    comps.year = 2019;
    comps.month = 6;
    comps.day = 10;
    comps.hour = 10;
    comps.minute = 1;
    
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate* date = [calendar dateFromComponents:comps];
    NSTimeInterval firstInterval = [date timeIntervalSince1970];
      
    [self initOneSignalWithInAppMessage:message];
    [OSMessagingControllerOverrider setMockDateGenerator: ^NSTimeInterval(void) {
        return firstInterval;
    }];
    
    XCTAssertEqual(0, OSMessagingControllerOverrider.messagesForRedisplay.count);
    [OneSignal removeTriggerForKey:@"prop1"];
      
    // IAM should be shown instantly and be within the messageDisplayQueue
    XCTAssertEqual(1, OSMessagingControllerOverrider.messageDisplayQueue.count);
      
    let iamDisplayed = [OSMessagingControllerOverrider.messageDisplayQueue objectAtIndex:0];
    XCTAssertEqual(-1, iamDisplayed.displayStats.lastDisplayTime);
      
    [OSMessagingControllerOverrider dismissCurrentMessage];
    
    XCTAssertEqual(1, OSMessagingControllerOverrider.messagesForRedisplay.count);
    
    OSInAppMessage *dismissedMessage = [[OSMessagingControllerOverrider messagesForRedisplay] objectForKey:message.messageId];
    let lastDisplayTime = dismissedMessage.displayStats.lastDisplayTime;
    XCTAssertEqual(1, dismissedMessage.displayStats.displayQuantity);
    XCTAssertEqual(firstInterval, lastDisplayTime);
      
    comps.minute = 1 + delay/60; // delay/60 -> minutes

    NSDate* secondDate = [calendar dateFromComponents:comps];
    NSTimeInterval secondInterval = [secondDate timeIntervalSince1970];
     
    [OSMessagingControllerOverrider setMockDateGenerator: ^NSTimeInterval(void) {
        return secondInterval;
    }];
    
    [OneSignal addTrigger:@"prop1" withValue:@2];
    XCTAssertEqual(0, OSMessagingControllerOverrider.messageDisplayQueue.count);
    [OneSignal removeTriggerForKey:@"prop1"];
    XCTAssertEqual(1, OSMessagingControllerOverrider.messageDisplayQueue.count);
      
    [OSMessagingControllerOverrider dismissCurrentMessage];
      
    XCTAssertNotNil([[OSMessagingControllerOverrider messagesForRedisplay] objectForKey:message.messageId]);
    OSInAppMessage *secondDismissedMessage = [[OSMessagingControllerOverrider messagesForRedisplay] objectForKey:message.messageId];
    let secondLastDisplayTime = secondDismissedMessage.displayStats.lastDisplayTime;
    XCTAssertEqual(2, secondDismissedMessage.displayStats.displayQuantity);
    XCTAssertEqual(secondInterval, secondLastDisplayTime);
    XCTAssertTrue(secondLastDisplayTime - firstInterval >= delay);
}

- (void)testIAMRemoveFromCache_Redisplay {
    //Time interval mock
    NSDateComponents* comps = [[NSDateComponents alloc]init];
    comps.year = 2019;
    comps.month = 6;
    comps.day = 10;
    comps.hour = 10;
    comps.minute = 1;
      
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate* date = [calendar dateFromComponents:comps];
    NSTimeInterval firstInterval = [date timeIntervalSince1970];
       
    [OSMessagingControllerOverrider setMockDateGenerator: ^NSTimeInterval(void) {
        return firstInterval;
    }];
    
    let maxCacheTime = 6 * 30 * 24 * 60 * 60; // Six month in seconds
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop1" withValue:@2];
    let limit = 5;
    let delay = 60;
    let firstTrigger = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeNotExists withValue:@(2)];

    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger]] withRedisplayLimit:limit delay:@(delay)];
    let message1 = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger]] withRedisplayLimit:limit delay:@(delay)];
    message1.displayStats.lastDisplayTime = firstInterval - maxCacheTime + 1;
    let message2 = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger]] withRedisplayLimit:limit delay:@(delay)];
    message2.displayStats.lastDisplayTime = firstInterval - maxCacheTime - 1;
    
    NSMutableDictionary <NSString *, OSInAppMessage *> * redisplayedInAppMessages = [NSMutableDictionary new];
    [redisplayedInAppMessages setObject:message1 forKey:message1.messageId];
    [redisplayedInAppMessages setObject:message2 forKey:message2.messageId];
    
    [OSMessagingControllerOverrider setMessagesForRedisplay:redisplayedInAppMessages];
    [standardUserDefaults saveDictionaryForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:redisplayedInAppMessages];
    
    [self initOneSignalWithInAppMessage:message];
    
    let redisplayMessagesCache = [standardUserDefaults getSavedDictionaryForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:nil];
    XCTAssertTrue([redisplayMessagesCache objectForKey:message1.messageId]);
    XCTAssertFalse([redisplayMessagesCache objectForKey:message2.messageId]);
}

- (void)testTimeSinceLastInAppMessageTrigger_withNoPreviousInAppMessages {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE withOperator:OSTriggerOperatorTypeGreaterThan withValue:@10];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    // Check to make sure the timer was not scheduled since the IAM should just show instantly
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    
    // IAM should be shown instantly and be within the messageDisplayQueue
    XCTAssertEqual(1, OSMessagingControllerOverrider.messageDisplayQueue.count);
}

// If a message is scheduled to be displayed in the past, it should not be shown at all.
- (void)testExpiredExactTimeTrigger {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE withOperator:OSTriggerOperatorTypeGreaterThan withValue:@-10];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    // Check to make sure the timer was not scheduled since the IAM should just show instantly
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    
    // IAM should be shown instantly and be within the messageDisplayQueue essentially ignoring the negative number in seconds
    XCTAssertEqual(1, OSMessagingControllerOverrider.messageDisplayQueue.count);
}

// This test checks to make sure that if you are using the > operator for an exact time trigger,
// the message is still displayed even after the time is passed. For example, if you set a message
// to be displayed at OR after April 11th @ 10AM PST, but it is currently April 12th, the message
// should still be shown since you used the > (greater than) operator.
- (void)testPastButValidExactTimeTrigger {
    NSTimerOverrider.shouldScheduleTimers = false;
    
    let targetTimestamp = NSDate.date.timeIntervalSince1970 - 1000.0f;
    
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE withOperator:OSTriggerOperatorTypeGreaterThan withValue:@(targetTimestamp)];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    
    XCTAssertEqual(OSMessagingControllerOverrider.messageDisplayQueue.count, 1);
}

// when an in-app message is displayed to the user, the SDK should launch an API request
- (void)testIAMViewedLaunchesViewedAPIRequest {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageViewed class]));
}

- (void)testIAMClickedLaunchesAPIRequest {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction new];
    action.clickType = @"button";
    action.clickId = @"test_action_id";
    
    let testMessage = [OSInAppMessage instanceWithJson:message];
    
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
    // The action should cause an "opened" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageClicked class]));
}

- (void)testIAMClickedLaunchesOutcomeAPIRequest {
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_UNATTRIBUTED_SESSION_ENABLED withValue:YES];
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let outcomeName = @"test_outcome";
    NSDictionary *outcomeJson = @{
        @"name" : outcomeName
    };
    NSMutableDictionary *actionJson = [OSInAppMessageTestHelper.testActionJson mutableCopy];
    [actionJson setValue:@[outcomeJson] forKey:@"outcomes"];
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction instanceWithJson: actionJson];
    let testMessage = [OSInAppMessage instanceWithJson:message];
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
    // The action should cause an "outcome" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestSendOutcomesToServer class]));
    XCTAssertEqual(outcomeName, [OneSignalClientOverrider.lastHTTPRequest objectForKey:@"id"]);
    XCTAssertFalse([OneSignalClientOverrider.lastHTTPRequest objectForKey:@"weight"]);
}

- (void)testIAMClickedLaunchesOutcomeWithValueAPIRequest {
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_UNATTRIBUTED_SESSION_ENABLED withValue:YES];
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let outcomeName = @"test_outcome";
    int outcomeWeight = 10;
    NSDictionary *outcomeWithWeightJson = @{
        @"name" : outcomeName,
        @"weight" : @(outcomeWeight)
    };
    NSMutableDictionary *actionJson = [OSInAppMessageTestHelper.testActionJson mutableCopy];
    [actionJson setValue:@[outcomeWithWeightJson] forKey:@"outcomes"];
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction instanceWithJson: actionJson];
    let testMessage = [OSInAppMessage instanceWithJson:message];
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
    // The action should cause an "outcome" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestSendOutcomesToServer class]));
    XCTAssertEqual(outcomeName, [OneSignalClientOverrider.lastHTTPRequest objectForKey:@"id"]);
    XCTAssertEqual(outcomeWeight, [[OneSignalClientOverrider.lastHTTPRequest objectForKey:@"weight"] intValue]);
}

- (void)testIAMClickedLaunchesMultipleOutcomesAPIRequest {
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_UNATTRIBUTED_SESSION_ENABLED withValue:YES];
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let outcomeName = @"test_outcome";
    int outcomeWeight = 10;
    NSDictionary *outcomeWithWeightJson = @{
        @"name" : outcomeName,
        @"weight" : @(outcomeWeight)
    };
    NSDictionary *outcomeJson = @{
        @"name" : outcomeName
    };
    NSMutableDictionary *actionJson = [OSInAppMessageTestHelper.testActionJson mutableCopy];
    [actionJson setValue:@[outcomeJson, outcomeWithWeightJson] forKey:@"outcomes"];
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction instanceWithJson: actionJson];
    let testMessage = [OSInAppMessage instanceWithJson:message];
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
    // The action should cause an "outcome" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestSendOutcomesToServer class]));
    XCTAssertEqual(outcomeName, [OneSignalClientOverrider.lastHTTPRequest objectForKey:@"id"]);
    XCTAssertEqual(outcomeWeight, [[OneSignalClientOverrider.lastHTTPRequest objectForKey:@"weight"] intValue]);
    
    let lenght = OneSignalClientOverrider.executedRequests.count;
    XCTAssertEqual(@"outcomes/measure", [OneSignalClientOverrider.executedRequests objectAtIndex:lenght - 1].path);
    XCTAssertEqual(@"outcomes/measure", [OneSignalClientOverrider.executedRequests objectAtIndex:lenght - 2].path);
    XCTAssertNotEqual(@"outcomes/measure", [OneSignalClientOverrider.executedRequests objectAtIndex:lenght - 3].path);
    
    XCTAssertEqual(outcomeName, [[OneSignalClientOverrider.executedRequests objectAtIndex:lenght - 2].parameters objectForKey:@"id"]);
    XCTAssertFalse([[[OneSignalClientOverrider.executedRequests objectAtIndex:lenght - 2].parameters objectForKey:@"weight"] intValue]);
}

- (void)testIAMClickedNoLaunchesOutcomesAPIRequestWhenDisabled {
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_UNATTRIBUTED_SESSION_ENABLED withValue:YES];
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_UNATTRIBUTED_SESSION_ENABLED withValue:NO];
    
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    NSDictionary *outcomeJson = @{
        @"name" :  @"test_outcome"
    };
    NSMutableDictionary *actionJson = [OSInAppMessageTestHelper.testActionJson mutableCopy];
    [actionJson setValue:@[outcomeJson] forKey:@"outcomes"];
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction instanceWithJson: actionJson];
    let testMessage = [OSInAppMessage instanceWithJson:message];
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
    // With unattributed outcomes disable no outcome request should happen
    XCTAssertNotEqual(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestSendOutcomesToServer class]));
}

- (void)testIAMClickedLaunchesUniqueOutcomeAPIRequest {
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_UNATTRIBUTED_SESSION_ENABLED withValue:YES];
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    let outcomeName = @"test_outcome";
    NSDictionary *outcomeJson = @{
        @"name" : outcomeName,
        @"unique" : @(YES)
    };
    NSMutableDictionary *actionJson = [OSInAppMessageTestHelper.testActionJson mutableCopy];
    [actionJson setValue:@[outcomeJson] forKey:@"outcomes"];
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction instanceWithJson: actionJson];
    let testMessage = [OSInAppMessage instanceWithJson:message];
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
    // The action should cause an "outcome" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestSendOutcomesToServer class]));
    XCTAssertEqual(outcomeName, [OneSignalClientOverrider.lastHTTPRequest objectForKey:@"id"]);
    XCTAssertFalse([OneSignalClientOverrider.lastHTTPRequest objectForKey:@"weight"]);

    [OneSignalClientOverrider reset:self];
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
    // The action shouldn't cause an "outcome" API request
    XCTAssertFalse(OneSignalClientOverrider.lastHTTPRequestType);
}

- (void)testIAMClickedLaunchesTagSendPIRequest {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let tagKey = @"test1";
    let tagsJson = @{
                     @"adds" : @{
                             tagKey : tagKey
                             }
                     };
    
    NSMutableDictionary *actionJson = [OSInAppMessageTestHelper.testActionJson mutableCopy];
    [actionJson setValue:tagsJson forKey:@"tags"];
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction instanceWithJson: actionJson];
    let testMessage = [OSInAppMessage instanceWithJson:message];

    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
     // Make sure all 3 sets of tags where send in 1 network call.
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    // The action should cause an "send tag" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestSendTagsToServer class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][tagKey], tagKey);
}

- (void)testIAMClickedLaunchesTagRemoveAPIRequest {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    let tagKey = @"test1";
    let tagsJson = @{
                     @"removes" :  @[tagKey]
                     };
    
    NSMutableDictionary *actionJson = [OSInAppMessageTestHelper.testActionJson mutableCopy];
    [actionJson setValue:tagsJson forKey:@"tags"];
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction instanceWithJson: actionJson];
    let testMessage = [OSInAppMessage instanceWithJson:message];
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
     // Make sure all 3 sets of tags where send in 1 network call.
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    // The action should cause an "send tag" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestSendTagsToServer class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][tagKey], @"");
}

- (void)testIAMClickedLaunchesTagSendAndRemoveAPIRequest {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let tagKey = @"test1";
    let tagsJson =  @{
                @"adds" : @{
                        tagKey : tagKey
                },
                @"removes" : @[tagKey]
        };
    NSMutableDictionary *actionJson = [OSInAppMessageTestHelper.testActionJson mutableCopy];
    [actionJson setValue:tagsJson forKey:@"tags"];
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction instanceWithJson: actionJson];
    let testMessage = [OSInAppMessage instanceWithJson:message];
    [OSMessagingController.sharedInstance messageViewDidSelectAction:testMessage withAction:action];
     // Make sure all 3 sets of tags where send in 1 network call.
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    // The action should cause an "send tag" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestSendTagsToServer class]));
    XCTAssertEqual(0 ,[OneSignalClientOverrider.lastHTTPRequest[@"tags"] count]);
}

- (void)testDisablingIAMs_stillCreatesMessageQueue_butPreventsMessageDisplay {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // this should prevent message from being shown
    [OneSignal pauseInAppMessages:true];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];

    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // Make sure no IAM is showing, but the queue has any IAMs
    XCTAssertFalse(OSMessagingControllerOverrider.isInAppMessageShowing);
    XCTAssertEqual(OSMessagingControllerOverrider.messageDisplayQueue.count, 1);
}

/**
 This tests to make sure that:
    (A) The SDK picks the correct language variant to use for in-app messages.
    (B) The SDK loads HTML content with the correct URL
*/
- (void)testIAMHTMLLoadWithCorrectLanguage {
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    let htmlContents = [OSInAppMessageTestHelper testInAppMessageGetContainsWithHTML:OS_DUMMY_HTML];
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestLoadInAppMessageContent class]) withResponse:htmlContents];
    
    let messageJson = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let message = [OSInAppMessage instanceWithJson:messageJson];
    
    [NSLocaleOverrider setPreferredLanguagesArray:@[@"es", @"en"]];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    let expectation = [self expectationWithDescription:@"wait_for_message_html"];
    expectation.expectedFulfillmentCount = 1;
    expectation.assertForOverFulfill = true;
    
    [message loadMessageHTMLContentWithResult:^(NSDictionary *data) {
        XCTAssertNotNil(data);
        
        NSLog(@"HERE: %@", data);
        
        XCTAssertEqualObjects(data[@"html"], OS_DUMMY_HTML);
        
        [expectation fulfill];
    } failure:^(NSError *error) {
        XCTFail(@"Failure occurred: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestLoadInAppMessageContent class]));
    
    let url = OneSignalClientOverrider.lastUrl;
    
    XCTAssertTrue([url containsString:OS_TEST_ENGLISH_VARIANT_ID]);
    XCTAssertTrue([url containsString:OS_TEST_MESSAGE_ID]);
}

/**
    This test doesn't check the actual load result (the above test already does this),
    this test makes sure that if there is no matching preferred language that the
    SDK will use the 'default' variant.
*/
- (void)testIAMHTMLLoadWithDefaultLanguage {
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    let htmlContents = [OSInAppMessageTestHelper testInAppMessageGetContainsWithHTML:OS_DUMMY_HTML];
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestLoadInAppMessageContent class]) withResponse:htmlContents];
    
    let messageJson = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let message = [OSInAppMessage instanceWithJson:messageJson];
    
    [NSLocaleOverrider setPreferredLanguagesArray:@[@"kl"]]; //kl = klingon

    let expectation = [self expectationWithDescription:@"wait_for_message_html"];
    expectation.expectedFulfillmentCount = 1;
    expectation.assertForOverFulfill = true;
    
    [message loadMessageHTMLContentWithResult:^(NSDictionary *data) {
        [expectation fulfill];
    } failure:^(NSError *error) {
        XCTFail(@"Failure occurred: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestLoadInAppMessageContent class]));
    
    let url = OneSignalClientOverrider.lastUrl;
    
    XCTAssertTrue([url containsString:OS_TEST_MESSAGE_VARIANT_ID]);
    XCTAssertTrue([url containsString:OS_TEST_MESSAGE_ID]);
}

// Helper method that adds an OSInAppMessage to the IAM messageDisplayQueue
// Mock response JSON and initializes the OneSignal SDK
- (void)initOneSignalWithInAppMessage:(OSInAppMessage *)message {
    let registrationJson = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message.jsonRepresentation]];
    [self initOneSignalWithRegistrationJSON:registrationJson];
}

- (void)initOneSignalWithInAppMessageArray:(NSArray<NSDictionary *> *)messages {
    let registrationJson = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:messages];
    [self initOneSignalWithRegistrationJSON:registrationJson];
}

- (void)initOneSignalWithRegistrationJSON:(NSDictionary *)registrationJson {
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationJson];

    [UnitTestCommonMethods initOneSignalAndThreadWait];
}

@end
