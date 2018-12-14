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
#import "OneSignalHelperOverrider.h"
#import "OneSignalCommonDefines.h"
#import "NSString+OneSignal.h"
#import "OneSignalOverrider.h"
#import "OSInAppMessageAction.h"
#import "OSInAppMessageBridgeEvent.h"

/**
 Test to make sure that OSInAppMessage correctly
 implements the OSJSONDecodable protocol
 and all properties are parsed correctly
 */

@interface InAppMessagingTests : XCTestCase
@property (strong, nonatomic) OSTriggerController *triggerController;
@end

@implementation InAppMessagingTests {
    OSInAppMessage *testMessage;
    OSInAppMessageAction *testAction;
    OSInAppMessageBridgeEvent *testBridgeEvent;
}

// called before each test
-(void)setUp {
    [super setUp];
    
    NSTimerOverrider.shouldScheduleTimers = false;
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    testMessage = [OSInAppMessageTestHelper testMessageWithTriggersJson:@[
        @[
            @{
                @"id" : @"test_trigger_id",
                @"property" : @"view_controller",
                @"operator" : OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeEqualTo),
                @"value" : @"home_vc"
            }
        ]
    ]];
    
    testBridgeEvent = [OSInAppMessageBridgeEvent instanceWithJson:@{
        @"type" : @"action_taken",
        @"body" : @{
            @"action_id" : @"test_id",
            @"url" : @"https://www.onesignal.com",
            @"url_target" : @"browser",
            @"close" : @false
        }
    }];
    
    testAction = testBridgeEvent.userAction;
    
    self.triggerController = [OSTriggerController new];
}

-(void)tearDown {
    NSTimerOverrider.shouldScheduleTimers = true;
}

#pragma mark Message JSON Parsing Tests
- (void)testCorrectlyParsedType {
    XCTAssertTrue(testMessage.type == OSInAppMessageDisplayTypeCenteredModal);
}

-(void)testCorrectlyParsedMessageId {
    XCTAssertTrue([testMessage.messageId containsString:OS_TEST_MESSAGE_ID]);
}

-(void)testCorrectlyParsedVariants {
    NSDictionary *appVariants = testMessage.variants[@"app"];
    XCTAssertTrue([appVariants[@"default"] isEqualToString:@"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba"]);
}

-(void)testCorrectlyParsedTriggers {
    XCTAssertTrue(testMessage.triggers.count == 1);
    XCTAssertEqual(testMessage.triggers.firstObject.firstObject.operatorType, OSTriggerOperatorTypeEqualTo);
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.property, @"view_controller");
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.value, @"home_vc");
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.triggerId, @"test_trigger_id");
}

- (void)testCorrectlyParsedActionId {
    XCTAssertEqualObjects(testAction.actionId, @"test_id");
}

- (void)testCorrectlyParsedActionUrl {
    XCTAssertEqualObjects(testAction.actionUrl.absoluteString, @"https://www.onesignal.com");
}

- (void)testCorrectlyParsedActionType {
    XCTAssertEqual(testAction.urlActionType, OSInAppMessageActionUrlTypeSafari);
}

- (void)testCorrectlyParsedActionClose {
    XCTAssertFalse(testAction.close);
}

- (void)testCorrectlyParsedActionBridgeEvent {
    XCTAssertEqual(testBridgeEvent.type, OSInAppMessageBridgeEventTypeActionTaken);
}

- (void)testCorrectlyParsedRenderingCompleteBridgeEvent {
    let type = [OSInAppMessageBridgeEvent instanceWithJson:@{@"type" : @"rendering_complete"}].type;
    XCTAssertEqual(type, OSInAppMessageBridgeEventTypePageRenderingComplete);
}

- (void)testHandlesInvalidBridgeEventType {
    
    // the SDK should simply return nil if it receives invalid event JSON
    let invalidJson = @{
        @"type" : @"action_taken",
        @"body" : @[@"test"]
    };
    
    XCTAssertNil([OSInAppMessageBridgeEvent instanceWithJson:invalidJson]);
}

#pragma mark Message Trigger Logic Tests
-(void)testTriggersWithOneCondition {
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self.triggerController addTriggers:@{@"prop1" : @1}];
    
    // since the local trigger for prop1 is 1, and the message filter requires >= 2,
    // the message should not match and should evaluate to false
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
}

-(void)testTriggersWithTwoConditions {
    let trigger1 = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeLessThanOrEqualTo withValue:@-3];
    let trigger2 = [OSTrigger triggerWithProperty:@"prop2" withOperator:OSTriggerOperatorTypeEqualTo withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger1, trigger2]]];
    
    [self.triggerController addTriggers:@{
        @"prop1" : @-4.3,
        @"prop2" : @2
    }];
    
    // Both triggers should evaluate to true
    XCTAssertTrue([self.triggerController messageMatchesTriggers:message]);
}

-(void)testTriggersWithOrCondition {
    let trigger1 = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeLessThanOrEqualTo withValue:@-3];
    let trigger2 = [OSTrigger triggerWithProperty:@"prop2" withOperator:OSTriggerOperatorTypeEqualTo withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger1], @[trigger2]]];
    
    // The first trigger should evaluate to false, but since the first level array
    // represents OR conditions and the second trigger array evaluates to true,
    // the whole result should be true
    [self.triggerController addTriggers:@{
        @"prop1" : @7.3,
        @"prop2" : @2
    }];
    
    XCTAssertTrue([self.triggerController messageMatchesTriggers:message]);
}

-(void)testTriggerWithMissingValue {
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    // the trigger controller will have no value for 'prop1'
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
}

- (BOOL)setupComparativeOperatorTest:(OSTriggerOperatorType)operator withTriggerValue:(id)triggerValue withLocalValue:(id)localValue {
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:operator withValue:triggerValue];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    if (localValue)
        [self.triggerController addTriggers:@{@"prop1" : localValue}];
    else
        [self.triggerController removeTriggersForKeys:@[@"prop1"]];
    
    return [self.triggerController messageMatchesTriggers:message];
}

// tests operators to make sure they correctly handle cases where the local value is not set
- (void)testNilLocalValuesForOperators {
    
    let operatorStrings = @[
        OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeGreaterThan),
        OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeLessThan),
        OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeEqualTo),
        OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeLessThanOrEqualTo),
        OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeGreaterThanOrEqualTo),
        OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeContains),
        OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeExists)
    ];
    
    // all of these trigger evaluations should return false if the local value is nil.
    // The only special cases are the "not_exists" and "not_equal" operators.
    for (NSString *operatorString in operatorStrings) {
        let operator = (OSTriggerOperatorType)OS_OPERATOR_FROM_STRING(operatorString);
        XCTAssertFalse([self setupComparativeOperatorTest:operator withTriggerValue:@3 withLocalValue:nil]);
    }
}

- (void)testGreaterThan {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThan withTriggerValue:@3 withLocalValue:@3.1]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThan withTriggerValue:@2.1 withLocalValue:@2]);
}

- (void)testGreaterThanOrEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@3 withLocalValue:@3]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@2 withLocalValue:@2.9]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@5 withLocalValue:@4]);
}

- (void)testEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@0.1 withLocalValue:@0.1]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@0.0 withLocalValue:@2]);
}

- (void)testLessThan {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTriggerValue:@2 withLocalValue:@1.9]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTriggerValue:@3 withLocalValue:@4]);
}

- (void)testLessThanOrEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@5 withLocalValue:@4]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@3 withLocalValue:@3]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@3 withLocalValue:@4]);
}

- (void)testNumericContainsOperator {
    let localArray = @[@1, @2, @3];
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeContains withTriggerValue:@2 withLocalValue:localArray]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeContains withTriggerValue:@4 withLocalValue:localArray]);
}

- (void)testStringContainsOperator {
    let localArray = @[@"test1", @"test2", @"test3"];
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeContains withTriggerValue:@"test2" withLocalValue:localArray]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeContains withTriggerValue:@"test5" withLocalValue:localArray]);
}

- (void)testExistsOperator {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeExists withTriggerValue:nil withLocalValue:@3]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeExists withTriggerValue:nil withLocalValue:nil]);
}

- (void)testNotExistsOperator {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotExists withTriggerValue:nil withLocalValue:nil]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotExists withTriggerValue:nil withLocalValue:@4]);
}

- (void)testNotEqualToOperator {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:nil]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:@2]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:@3]);
}

- (void)testInvalidOperator {
    let triggerJson = @{
                        @"property" : @"prop1",
                        @"operator" : @"<<<",
                        @"value" : @2
                        };
    
    // When invalid JSON is encountered, the in-app message should
    // not initialize and should return nil
    XCTAssertNil([OSInAppMessageTestHelper testMessageWithTriggersJson:@[@[triggerJson]]]);
}

// Tests the macro that gets the Display Type's equivalent OSInAppMessageDisplayPosition
- (void)testDisplayTypeConversion {
    let top = OS_DISPLAY_POSITION_FOR_TYPE(OSInAppMessageDisplayTypeTopBanner);
    let bottom = OS_DISPLAY_POSITION_FOR_TYPE(OSInAppMessageDisplayTypeBottomBanner);
    let modal = OS_DISPLAY_POSITION_FOR_TYPE(OSInAppMessageDisplayTypeCenteredModal);
    let full = OS_DISPLAY_POSITION_FOR_TYPE(OSInAppMessageDisplayTypeFullScreen);
    
    XCTAssertTrue(top == OSInAppMessageDisplayPositionTop);
    XCTAssertTrue(bottom == OSInAppMessageDisplayPositionBottom);
    XCTAssertTrue(modal == OSInAppMessageDisplayPositionCentered);
    XCTAssertTrue(full == OSInAppMessageDisplayPositionCentered);
}

// Tests the macro to convert strings to OSInAppMessageDisplayType
- (void)testStringToDisplayTypeConversion {
    let top = OS_DISPLAY_TYPE_FOR_STRING(@"top_banner");
    let bottom = OS_DISPLAY_TYPE_FOR_STRING(@"bottom_banner");
    let modal = OS_DISPLAY_TYPE_FOR_STRING(@"centered_modal");
    let full = OS_DISPLAY_TYPE_FOR_STRING(@"full_screen");
    
    XCTAssertTrue(top == OSInAppMessageDisplayTypeTopBanner);
    XCTAssertTrue(bottom == OSInAppMessageDisplayTypeBottomBanner);
    XCTAssertTrue(modal == OSInAppMessageDisplayTypeCenteredModal);
    XCTAssertTrue(full == OSInAppMessageDisplayTypeFullScreen);
}

- (void)testDynamicTriggerWithExactTimeTrigger {
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@([[NSDate date] timeIntervalSince1970])];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertTrue(triggered);
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
}

- (void)testDynamicTriggerSchedulesExactTimeTrigger {
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@([[NSDate date] timeIntervalSince1970] + 5.0f)];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertFalse(triggered);
    XCTAssertTrue(OS_ROUGHLY_EQUAL(NSTimerOverrider.mostRecentTimerInterval, 5.0f));
}

// Ensure that the Exact Time trigger will not fire after the date has passed
- (void)testDynamicTriggerDoesntTriggerPastTime {
    let trigger = [OSTrigger triggerWithProperty:OS_TIME_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@([[NSDate date] timeIntervalSince1970] - 5.0f)];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertFalse(triggered);
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
}

// The session duration trigger is set to fire in 30 seconds into the session
- (void)testDynamicTriggerSessionDurationLaunchesTimer {
    let trigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withOperator:OSTriggerOperatorTypeEqualTo withValue:@30];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];
    
    XCTAssertFalse(triggered);
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(fabs(NSTimerOverrider.mostRecentTimerInterval - 30.0f) < 0.1f);
}


// test to ensure that time-based triggers don't schedule timers
// until all other triggers evaluate to true.
- (void)testHandlesMultipleMixedTriggers {
    let firstTrigger = [OSTrigger triggerWithProperty:@"prop1" withId:@"test_id_1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@3];
    let secondTrigger = [OSTrigger triggerWithProperty:OS_SESSION_DURATION_TRIGGER withId:@"test_id_2" withOperator:OSTriggerOperatorTypeGreaterThanOrEqualTo withValue:@3.0];
    let thirdTrigger = [OSTrigger triggerWithProperty:@"prop2" withId:@"test_id_3" withOperator:OSTriggerOperatorTypeNotExists withValue:nil];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger, secondTrigger, thirdTrigger]]];
    
    [self.triggerController addTriggers:@{@"prop1" : @4}];
    
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
}

@end

