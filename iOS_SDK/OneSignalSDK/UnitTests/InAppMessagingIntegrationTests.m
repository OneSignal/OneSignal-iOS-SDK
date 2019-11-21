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
#import "NSLocaleOverrider.h"
#import "OSInAppMessageController.h"
#import "NSDateOverrider.h"

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
    This test adds an in-app message with a dynamic trigger (session_duration = +30 seconds)
    When the SDK receives this message in the response to the registration request, that it
    correctly sets up a timer for the 30 seconds
*/
- (void)testMessageIsScheduled {
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
- (void)testMessageIsDisplayed {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    XCTAssertEqual(OSMessagingControllerOverrider.messageDisplayQueue.count, 1);
}

// if we have two messages that are both valid to displayed add them to the queue (triggers are all true),
- (void)testMessagesDontOverlap {
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop1" withValue:@2];
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop2" withValue:@3];
    
    let firstMessage = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"prop1" withId:@"test_id1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@0];
    let secondMessage = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"prop2" withId:@"test_id2" withOperator:OSTriggerOperatorTypeLessThan withValue:@4];
    
    let registrationJson = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[firstMessage, secondMessage]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationJson];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(OSMessagingControllerOverrider.messageDisplayQueue.count == 2);
}

- (void)testMessageDisplayedAfterTimer {
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

// Tests adding & removing trigger values using the public OneSignal trigger methods
- (void)testRemoveTriggers {
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    [OneSignal addTrigger:@"test1" withValue:@"value1"];
    XCTAssertTrue([OneSignal getTriggers].count == 1);
    
    [OneSignal addTriggers:@{@"test2" : @33}];
    XCTAssertEqualObjects(OneSignal.getTriggers[@"test2"], @33);
    XCTAssertTrue([OneSignal getTriggers].count == 2);
    
    [OneSignal addTriggers:@{@"test2" : @"44"}];
    XCTAssertTrue([OneSignal getTriggers].count == 2);
    
    [OneSignal addTriggers:@{@"test3" : @""}];
    XCTAssertTrue([OneSignal getTriggers].count == 3);
    
    [OneSignal removeTriggerForKey:@"test1"];
    XCTAssertNil(OneSignal.getTriggers[@"test1"]);
    XCTAssertNil([OneSignal getTriggerValueForKey:@"test1"]);
    
    XCTAssertEqualObjects(OneSignal.getTriggers[@"test2"], @"44");
    XCTAssertEqualObjects([OneSignal getTriggerValueForKey:@"test3"], @"");

    [OneSignal removeTriggerForKey:@"test2"];
    [OneSignal removeTriggerForKey:@"test3"];
    
    XCTAssertTrue([OneSignal getTriggers].count == 0);
}

- (void)testTimeSinceLastInAppMessageTrigger_withNoPreviousInAppMessages {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE withOperator:OSTriggerOperatorTypeGreaterThan withValue:@10];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    // Check to make sure the timer was not scheduled since the IAM should just show instantly
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    
    // IAM should be shown instantly and be within the messageDisplayQueue
    XCTAssertTrue(OSMessagingControllerOverrider.messageDisplayQueue.count == 1);
}

// If a message is scheduled to be displayed in the past, it should not be shown at all.
- (void)testExpiredExactTimeTrigger {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE withOperator:OSTriggerOperatorTypeGreaterThan withValue:@-10];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self initOneSignalWithInAppMessage:message];
    
    // Check to make sure the timer was not scheduled since the IAM should just show instantly
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    
    // IAM should be shown instantly and be within the messageDisplayQueue essentially ignoring the negative number in seconds
    XCTAssertTrue(OSMessagingControllerOverrider.messageDisplayQueue.count == 1);
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
- (void)testMessageViewedLaunchesViewedAPIRequest {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // the message should now be displayed
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestInAppMessageViewed class]));
}

- (void)testMessageClickedLaunchesAPIRequest {
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

- (void)testDisablingMessagesPreventsDisplay {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id1" withOperator:OSTriggerOperatorTypeLessThan withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    // this should prevent message from being shown
    [OneSignal pauseInAppMessages:true];
    
    // the trigger should immediately evaluate to true and should
    // be shown once the SDK is fully initialized.
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];

    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // no message should have been shown
    XCTAssertEqual(OSMessagingControllerOverrider.messageDisplayQueue.count, 0);
}

/**
 This tests to make sure that:
    (A) The SDK picks the correct language variant to use for in-app messages.
    (B) The SDK loads HTML content with the correct URL
*/
- (void)testMessageHTMLLoadWithCorrectLanguage {
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
- (void)testMessageHTMLLoadWithDefaultLanguage {
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

    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationJson];

    [UnitTestCommonMethods initOneSignalAndThreadWait];
}

@end
