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
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"os_session_duration" withOperator:@"==" withValue:@30];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(fabs(NSTimerOverrider.mostRecentTimerInterval - 30.0f) < 0.3f);
}

/**
    Once on_session API request is complete, if the SDK receives a message with valid triggers
    (all the triggers for the message evaluate to true), the SDK should display the message. This
    test verifies that the message actually gets displayed.
*/
- (void)testMessageIsDisplayed {
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"os_session_duration" withOperator:@"<" withValue:@10.0];
    
    let registrationResponse = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationResponse];
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(OSMessagingControllerOverrider.displayedMessages.count == 1);
}

// if we have two messages that are both valid to displayed (triggers are all true),
- (void)testMessagesDontOverlap {
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop1" withValue:@2];
    [OSMessagingController.sharedInstance setTriggerWithName:@"prop2" withValue:@3];
    
    let firstMessage = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"prop1" withOperator:@">" withValue:@0];
    let secondMessage = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"prop2" withOperator:@"<" withValue:@4];
    
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
    
    let message = [OSInAppMessageTestHelper testMessageJsonWithTriggerPropertyName:@"os_session_duration" withOperator:@">=" withValue:@0.05];
    
    let registrationJson = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationJson];
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    OneSignalOverrider.shouldOverrideSessionLaunchTime = false;
    
    let expectation = [self expectationWithDescription:@"wait for timed message to show"];
    expectation.expectedFulfillmentCount = 1;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XCTAssertTrue(OSMessagingControllerOverrider.displayedMessages.count == 1);
        
        [expectation fulfill];
    });
    
    [self waitForExpectations:@[expectation] timeout:0.1];
}

// If a message has multiple triggers, and one of the triggers is time/duration based, the SDK
// will set up a timer. However, if a normal value-based trigger condition is not true, there is
// no point in setting up a timer until that condition changes.
- (void)testDelaysSettingUpTimers {
    let firstTrigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeExists withValue:nil];
    let secondTrigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withOperator:OSTriggerOperatorTypeGreaterThanOrEqualTo withValue:@15];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger, secondTrigger]]];
    
    let registrationJson = [OSInAppMessageTestHelper testRegistrationJsonWithMessages:@[message.jsonRepresentation]];
    
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestRegisterUser class]) withResponse:registrationJson];
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
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

@end
