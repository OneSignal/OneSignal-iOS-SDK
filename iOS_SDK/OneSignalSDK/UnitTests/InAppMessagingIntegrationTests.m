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
#import "OneSignalHelper.h"
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

@interface InAppMessagingIntegrationTests : XCTestCase

@end

@implementation InAppMessagingIntegrationTests

- (void)setUp {
    [super setUp];
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [UnitTestCommonMethods beforeAllTest];
    
    NSTimerOverrider.shouldScheduleTimers = false;
}

-(void)tearDown {
    OneSignalOverrider.shouldOverrideSessionLaunchTime = false;
    
    [OSMessagingController.sharedInstance resetState];
    
    NSTimerOverrider.shouldScheduleTimers = true;
}

/**
    This test adds an in-app message with a dynamic trigger (session_duration = +30 seconds)
    When the SDK receives this message in the response to the registration request, that it
    correctly sets up a timer for the 30 seconds
*/
- (void)testMessageIsScheduled {
    let trigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@30];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
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
- (void)testMessageIsDisplayed {
    let trigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(OSMessagingControllerOverrider.displayedMessages.count == 1);
}

// if we have two messages that are both valid to displayed (triggers are all true),
- (void)testMessagesDontOverlap {
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop1" withValue:@2];
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop2" withValue:@3];
    
    let firstMessage = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"prop1" withId:@"test_id1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@0];
    let secondMessage = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"prop2" withId:@"test_id2" withOperator:OSTriggerOperatorTypeLessThan withValue:@4];
    
    let registrationJson = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[firstMessage, secondMessage]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationJson];
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(OSMessagingControllerOverrider.displayedMessages.count == 1);
}

- (void)testMessageDisplayedAfterTimer {
    
    NSTimerOverrider.shouldScheduleTimers = true;
    
    OneSignalOverrider.shouldOverrideSessionLaunchTime = true;
    
    let trigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withOperator:OSTriggerOperatorTypeGreaterThanOrEqualTo withValue:@0.05];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
    OneSignalOverrider.shouldOverrideSessionLaunchTime = false;
    
    let expectation = [self expectationWithDescription:@"wait for timed message to show"];
    expectation.expectedFulfillmentCount = 1;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertTrue(OSMessagingControllerOverrider.displayedMessages.count == 1);
        
        [expectation fulfill];
    });
    
    [self waitForExpectations:@[expectation] timeout:0.2];
}

// If a message has multiple triggers, and one of the triggers is time/duration based, the SDK
// will set up a timer. However, if a normal value-based trigger condition is not true, there is
// no point in setting up a timer until that condition changes.
- (void)testDelaysSettingUpTimers {
    let firstTrigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeExists withValue:nil];
    let secondTrigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withOperator:OSTriggerOperatorTypeGreaterThanOrEqualTo withValue:@15];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger, secondTrigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
    // the timer shouldn't be scheduled yet
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    
    [OneSignal setTriggerForKey:@"prop1" withValue:@2];
    
    // the timer should be scheduled now that the other trigger condition is true
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
}

// Tests adding & removing trigger values using the public OneSignal trigger methods
- (void)testRemoveTriggers {
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignal setTriggerForKey:@"test1" withValue:@"value1"];
    
    [OneSignal setTriggers:@{@"test2" : @33}];
    
    [OneSignal removeTriggerForKey:@"test1"];
    
    XCTAssertEqualObjects(OneSignal.getTriggers[@"test2"], @33);
    
    XCTAssertNil(OneSignal.getTriggers[@"test1"]);
    
    XCTAssertEqualObjects([OneSignal getTriggerValueForKey:@"test2"], @33);
}

- (void)testExactTimeTrigger {
    NSTimerOverrider.shouldScheduleTimers = false;
    
    let targetTimestamp = NSDate.date.timeIntervalSince1970 + 10.0f;
    
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@(targetTimestamp)];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
    // Check to make sure the timer was actually scheduled
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
    
    // check to make sure the timer was scheduled to fire at the desired time
    XCTAssertTrue(OS_ROUGHLY_EQUAL(NSDate.date.timeIntervalSince1970 + NSTimerOverrider.mostRecentTimerInterval, targetTimestamp));
}

// If a message is scheduled to be displayed in the past, it should not be shown at all.
- (void)testExpiredExactTimeTrigger {
    
    // This prevents timers from actually being scheduled. But if a timer is created,
    // this doesn't prevent the NSTimerOverrider.hasScheduledTimer from being set to true
    NSTimerOverrider.shouldScheduleTimers = false;
    
    // some time in the past, the exact offset doesn't matter
    let targetTimestamp = NSDate.date.timeIntervalSince1970 - 1000.0f;
    
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@(targetTimestamp)];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
}

// This test checks to make sure that if you are using the > operator for an exact time trigger,
// the message is still displayed even after the time is passed. For example, if you set a message
// to be displayed at OR after April 11th @ 10AM PST, but it is currently April 12th, the message
// should still be shown since you used the > (greater than) operator.
- (void)testPastButValidExactTimeTrigger {
    NSTimerOverrider.shouldScheduleTimers = false;
    
    let targetTimestamp = NSDate.date.timeIntervalSince1970 - 1000.0f;
    
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeGreaterThan withValue:@(targetTimestamp)];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    
    XCTAssertEqual(OSMessagingControllerOverrider.displayedMessages.count, 1);
}

// Tests a message with a more complex set of triggers specifying that the message should be
// shown between a window of dates, and that the session duration should be > 30 seconds
- (void)testWindowedMessage {
    NSTimerOverrider.shouldScheduleTimers = false;
    
    OneSignalOverrider.shouldOverrideSessionLaunchTime = true;
    
    let beginWindowTimestamp = NSDate.date.timeIntervalSince1970 - 1000.0f;
    let endWindowTimestamp = NSDate.date.timeIntervalSince1970 + 1000.0f;
    
    let beginWindowTrigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeGreaterThan withValue:@(beginWindowTimestamp)];
    let endWindowTrigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeLessThan withValue:@(endWindowTimestamp)];
    let sessionDurationTrigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withOperator:OSTriggerOperatorTypeGreaterThanOrEqualTo withValue:@30.0f];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[beginWindowTrigger, endWindowTrigger, sessionDurationTrigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
    
    // Two timers should be scheduled for this message, one for the end window trigger (T+1000 seconds) and another for
    // the session duration trigger (T+30 seconds). Which timer gets scheduled first doesn't really matter, we only care
    // to make sure that one of the timers was for 30 seconds.
    XCTAssertTrue(OS_ROUGHLY_EQUAL(NSTimerOverrider.mostRecentTimerInterval, 30.0f) || OS_ROUGHLY_EQUAL(NSTimerOverrider.previousMostRecentTimeInterval, 30.0f));
}

// Tests to make sure that the "os_viewed_message" trigger works correctly.
// It is used to limit how many times a message is shown
- (void)testDisplayLimitMessage {
    let trigger = [OSTrigger triggerWithProperty:OS_VIEWED_MESSAGE withOperator:OSTriggerOperatorTypeLessThan withValue:@1];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initializeOnesignalWithMessage:message];
    
    XCTAssertEqual(OSMessagingControllerOverrider.displayedMessages.count, 1);
    
    [OSMessagingController.sharedInstance didUpdateMessagesForSession:@[message]];
    
    // the message should not have been shown.
    XCTAssertEqual(OSMessagingControllerOverrider.displayedMessages.count, 1);
}

// helper method that adds an OSInAppMessage to the registration
// mock response JSON and initializes the OneSignal SDK
- (void)initializeOnesignalWithMessage:(OSInAppMessage *)message {
    let registrationJson = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message.jsonRepresentation]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationJson];
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
}

// when an in-app message is displayed to the user, the SDK should launch an API request
- (void)testMessageViewedLaunchesViewedAPIRequest {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"os_session_duration" withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // the message should now be displayed
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageViewed class]));
}

- (void)testMessageOpenedLaunchesAPIRequest {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"os_session_duration" withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // the message should now be displayed
    // simulate a button press (action) on the inapp message
    let action = [OSInAppMessageAction new];
    action.actionId = @"test_action_id";
    
    [OSMessagingController.sharedInstance messageViewDidSelectAction:action withMessageId:message[@"id"]];
    
    // The action should cause an "opened" API request
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageOpened class]));
}

@end
