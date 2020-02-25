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
#import "UIDeviceOverrider.h"
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
    OSInAppMessage *testMessageRedisplay;
    OSInAppMessageAction *testAction;
    OSInAppMessageBridgeEvent *testBridgeEvent;
}

NSInteger const LIMIT = 5;
NSInteger const DELAY = 60;

// called before each test
-(void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    NSTimerOverrider.shouldScheduleTimers = false;
    
    let trigger = @[
        @[
            @{
                @"id" : @"test_trigger_id",
                @"kind" : @"view_controller",
                @"property" : @"view_controller",
                @"operator" : OS_OPERATOR_TO_STRING(OSTriggerOperatorTypeEqualTo),
                @"value" : @"home_vc"
            }
        ]
    ];
    
    testMessage = [OSInAppMessageTestHelper testMessageWithTriggersJson:trigger];
    testMessageRedisplay = [OSInAppMessageTestHelper testMessageWithTriggersJson:trigger redisplayLimit:LIMIT delay:[NSNumber numberWithInteger:DELAY]];
    
    testBridgeEvent = [OSInAppMessageBridgeEvent instanceWithJson:@{
        @"type" : @"action_taken",
        @"body" : @{
            @"id" : @"test_id",
            @"url" : @"https://www.onesignal.com",
            @"url_target" : @"browser",
            @"close" : @false
        }
    }];
    
    testAction = testBridgeEvent.userAction;
    
    self.triggerController = [OSTriggerController new];
    
    [OneSignalHelperOverrider reset];
    
    [UIDeviceOverrider reset];
}

-(void)tearDown {
    NSTimerOverrider.shouldScheduleTimers = true;
}

-(void)testIphoneSimulator {
    OneSignalHelperOverrider.mockIOSVersion = 10;
    [OSMessagingController removeInstance];
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, OSMessagingController.class);
}

-(void)testIpadSimulator {
    OneSignalHelperOverrider.mockIOSVersion = 10;
    [OSMessagingController removeInstance];
    [UIDeviceOverrider setModel:@"iPad"];
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, OSMessagingController.class);
}

-(void)testOldUnsupportedIphoneSimulator {
    OneSignalHelperOverrider.mockIOSVersion = 9;
    [OSMessagingController removeInstance];
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, DummyOSMessagingController.class); // sharedInstance should be dummy controller
}

-(void)testOldUnsupportedIpadSimulator {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [OSMessagingController removeInstance];
    [UIDeviceOverrider setModel:@"iPad"];
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, DummyOSMessagingController.class); // sharedInstance should be dummy controller
}

-(void)testUnsupportedCatalyst {
    OneSignalHelperOverrider.mockIOSVersion = 10;
    [OSMessagingController removeInstance];
    [OneSignalHelperOverrider setSystemInfoMachine:@"x86_64"];
    [UIDeviceOverrider setSystemName:@"Mac OS X"]; // e.g. @"Mac OS X" @"iOS"
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, DummyOSMessagingController.class); // sharedInstance should be dummy controller
}

-(void)testRealIphone {
    OneSignalHelperOverrider.mockIOSVersion = 10;
    [OSMessagingController removeInstance];
    [OneSignalHelperOverrider setSystemInfoMachine:@"iPhone9,3"];
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, OSMessagingController.class);
}

-(void)testRealUnsupportedIphone {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [OSMessagingController removeInstance];
    [OneSignalHelperOverrider setSystemInfoMachine:@"iPhone9,3"];
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, DummyOSMessagingController.class); // sharedInstance should be dummy controller
}

-(void)testRealIpad {
    OneSignalHelperOverrider.mockIOSVersion = 13;
    [OSMessagingController removeInstance];
    [OneSignalHelperOverrider setSystemInfoMachine:@"iPad6,7"];
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, OSMessagingController.class);
}

-(void)testRealUnsupportedIpad {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [OSMessagingController removeInstance];
    [OneSignalHelperOverrider setSystemInfoMachine:@"iPad6,7"];
    let sharedInstance = OSMessagingController.sharedInstance;
    XCTAssertEqualObjects(sharedInstance.class, DummyOSMessagingController.class); // sharedInstance should be dummy controller
}

#pragma mark Message JSON Parsing Tests
-(void)testCorrectlyParsedMessageId {
    XCTAssertTrue([testMessage.messageId containsString:OS_TEST_MESSAGE_ID]);
    XCTAssertTrue([testMessageRedisplay.messageId containsString:OS_TEST_MESSAGE_ID]);
}

-(void)testCorrectlyParsedVariants {
    NSDictionary *appVariants = testMessage.variants[@"ios"];
    XCTAssertTrue([appVariants[@"default"] isEqualToString:OS_TEST_MESSAGE_VARIANT_ID]);
}

-(void)testCorrectlyParsedTriggers {
    XCTAssertEqual(1, testMessage.triggers.count);
    XCTAssertEqual(testMessage.triggers.firstObject.firstObject.operatorType, OSTriggerOperatorTypeEqualTo);
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.kind, @"view_controller");
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.value, @"home_vc");
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.triggerId, @"test_trigger_id");
}

- (void)testCorrectlyParsedDisplayStats {
    XCTAssertEqual(testMessageRedisplay.displayStats.displayLimit, LIMIT);
    XCTAssertEqual(testMessageRedisplay.displayStats.displayDelay, DELAY);
    XCTAssertEqual(testMessageRedisplay.displayStats.displayQuantity, 0);
    XCTAssertEqual(testMessageRedisplay.displayStats.lastDisplayTime, -1);
    XCTAssertTrue(testMessageRedisplay.displayStats.isRedisplayEnabled);
    
    XCTAssertEqual(testMessage.displayStats.displayLimit, NSIntegerMax);
    XCTAssertEqual(testMessage.displayStats.displayDelay, 0);
    XCTAssertEqual(testMessage.displayStats.displayQuantity, 0);
    XCTAssertEqual(testMessage.displayStats.lastDisplayTime, -1);
    XCTAssertFalse(testMessage.displayStats.isRedisplayEnabled);
}

- (void)testCorrectlyDisplayStatsLimit {
    for (int i = 0; i < LIMIT; i++) {
        XCTAssertTrue([testMessageRedisplay.displayStats shouldDisplayAgain]);
        [testMessageRedisplay.displayStats incrementDisplayQuantity];
    }
    
    [testMessageRedisplay.displayStats incrementDisplayQuantity];
    XCTAssertFalse([testMessageRedisplay.displayStats shouldDisplayAgain]);
}

- (void)testCorrectlyDisplayStatsDelay {
    NSDateComponents* comps = [[NSDateComponents alloc]init];
    comps.year = 2019;
    comps.month = 6;
    comps.day = 10;
    comps.hour = 10;
    comps.minute = 1;

    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate* date = [calendar dateFromComponents:comps];
    NSTimeInterval currentTime = [date timeIntervalSince1970];
       
    XCTAssertTrue([testMessageRedisplay.displayStats isDelayTimeSatisfied:currentTime]);
    
    testMessageRedisplay.displayStats.lastDisplayTime = currentTime - DELAY;
    XCTAssertTrue([testMessageRedisplay.displayStats isDelayTimeSatisfied:currentTime]);
    
    testMessageRedisplay.displayStats.lastDisplayTime = currentTime - DELAY + 1;
    XCTAssertFalse([testMessageRedisplay.displayStats isDelayTimeSatisfied:currentTime]);
}

- (void)testCorrectlyClickIds {
    let clickId = @"click_id";
    XCTAssertTrue([testMessageRedisplay isClickAvailable:clickId]);
    
    [testMessageRedisplay addClickId:clickId];
    XCTAssertFalse([testMessageRedisplay isClickAvailable:clickId]);

    [testMessageRedisplay clearClickIds];
    XCTAssertTrue([testMessageRedisplay isClickAvailable:clickId]);
   
    // Test on a IAM without redisplay
    XCTAssertTrue([testMessage isClickAvailable:clickId]);
    
    [testMessage addClickId:clickId];
    XCTAssertFalse([testMessage isClickAvailable:clickId]);

    [testMessage clearClickIds];
    XCTAssertTrue([testMessage isClickAvailable:clickId]);
}

- (void)testCorrectlyParsedActionId {
    XCTAssertEqualObjects(testAction.clickId, @"test_id");
}

- (void)testCorrectlyParsedActionUrl {
    XCTAssertEqualObjects(testAction.clickUrl.absoluteString, @"https://www.onesignal.com");
}

- (void)testCorrectlyParsedActionType {
    XCTAssertEqual(testAction.urlActionType, OSInAppMessageActionUrlTypeSafari);
}

- (void)testCorrectlyParsedActionClose {
    XCTAssertFalse(testAction.closesMessage);
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
    let trigger = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    [self.triggerController addTriggers:@{@"prop1" : @1}];
    
    // since the local trigger for prop1 is 1, and the message filter requires >= 2,
    // the message should not match and should evaluate to false
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
}

-(void)testTriggersWithTwoConditions {
    let trigger1 = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeLessThanOrEqualTo withValue:@-3];
    let trigger2 = [OSTrigger customTriggerWithProperty:@"prop2" withOperator:OSTriggerOperatorTypeEqualTo withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger1, trigger2]]];
    
    [self.triggerController addTriggers:@{
        @"prop1" : @-4.3,
        @"prop2" : @2
    }];
    
    // Both triggers should evaluate to true
    XCTAssertTrue([self.triggerController messageMatchesTriggers:message]);
}

-(void)testTriggersWithOrCondition {
    let trigger1 = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeLessThanOrEqualTo withValue:@-3];
    let trigger2 = [OSTrigger customTriggerWithProperty:@"prop2" withOperator:OSTriggerOperatorTypeEqualTo withValue:@2];
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
    let trigger = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@2];
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[trigger]]];
    
    // the trigger controller will have no value for 'prop1'
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
    
    [self.triggerController addTriggers:@{
        @"prop1" : @7,
    }];
    
    XCTAssertTrue([self.triggerController messageMatchesTriggers:message]);
    
    [self.triggerController removeTriggersForKeys:@[@"prop1"]];
    
    // the trigger controller will have no value for 'prop1'
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
}

- (BOOL)setupComparativeOperatorTest:(OSTriggerOperatorType)operator withTriggerValue:(id)triggerValue withLocalValue:(id)localValue {
    let trigger = [OSTrigger customTriggerWithProperty:@"prop1" withOperator:operator withValue:triggerValue];
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
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThan withTriggerValue:@3 withLocalValue:@"3.1"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThan withTriggerValue:@2.1 withLocalValue:@"2"]);
}

- (void)testGreaterThanOrEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@3 withLocalValue:@3]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@2 withLocalValue:@2.9]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@5 withLocalValue:@4]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@3 withLocalValue:@"3"]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@2 withLocalValue:@"2.9"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTriggerValue:@5 withLocalValue:@"4"]);
}

- (void)testEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@0.1 withLocalValue:@0.1]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@0.0 withLocalValue:@2]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@0.1 withLocalValue:@"0.1"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@0.0 withLocalValue:@"2"]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@"0.1" withLocalValue:@"0.1"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@"0.0" withLocalValue:@"2"]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@"0.1" withLocalValue:@0.1]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTriggerValue:@"0.0" withLocalValue:@2]);
}

- (void)testLessThan {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTriggerValue:@2 withLocalValue:@1.9]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTriggerValue:@3 withLocalValue:@4]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTriggerValue:@2 withLocalValue:@"1.9"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTriggerValue:@3 withLocalValue:@"4"]);
}

- (void)testLessThanOrEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@5 withLocalValue:@4]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@3 withLocalValue:@3]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@3 withLocalValue:@4]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@5 withLocalValue:@"4"]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@3 withLocalValue:@"3"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTriggerValue:@3 withLocalValue:@"4"]);
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
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeExists withTriggerValue:nil withLocalValue:@"3"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeExists withTriggerValue:nil withLocalValue:nil]);
}

- (void)testNotExistsOperator {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotExists withTriggerValue:nil withLocalValue:nil]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotExists withTriggerValue:nil withLocalValue:@4]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotExists withTriggerValue:nil withLocalValue:@"4"]);
}

- (void)testNotEqualToOperator {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:nil]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:@2]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:@3]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@"3" withLocalValue:nil]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@"3" withLocalValue:@2]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@"3" withLocalValue:@3]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@"3" withLocalValue:nil]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@"3" withLocalValue:@"2"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@"3" withLocalValue:@"3"]);
    
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:nil]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:@"2"]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeNotEqualTo withTriggerValue:@3 withLocalValue:@"3"]);
}

- (void)testInvalidOperator {
    let triggerJson = @{
                        @"kind" : @"prop1",
                        @"operator" : @"<<<",
                        @"value" : @2
                        };
    
    // When invalid JSON is encountered, the in-app message should
    // not initialize and should return nil
    XCTAssertNil([OSInAppMessageTestHelper testMessageWithTriggersJson:@[@[triggerJson]]]);
}

- (void)testDynamicTriggerWithExactTimeTrigger {
    let trigger = [OSTrigger
        dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE
                  withOperator:OSTriggerOperatorTypeEqualTo
                     withValue:@([[NSDate date] timeIntervalSince1970])
    ];
    
    OSDynamicTriggerController *controller = [OSDynamicTriggerController new];
    controller.timeSinceLastMessage = [NSDate dateWithTimeIntervalSince1970:1];
    let triggered = [controller dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertTrue(triggered);
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
}

- (void)testDynamicTriggerSchedulesExactTimeTrigger {
    let difference = 10;
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE withOperator:OSTriggerOperatorTypeEqualTo withValue:@([[NSDate date] timeIntervalSince1970])];
    
    OSDynamicTriggerController *controller = [OSDynamicTriggerController new];
    controller.timeSinceLastMessage = [NSDate dateWithTimeIntervalSince1970:difference];
    let triggered = [controller dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertFalse(triggered);
    XCTAssertTrue(NSTimerOverrider.mostRecentTimerInterval < difference);
}

// Ensure that the Exact Time trigger will not fire after the date has passed
- (void)testDynamicTriggerDoesntTriggerPastTime {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_MIN_TIME_SINCE withOperator:OSTriggerOperatorTypeEqualTo withValue:@([[NSDate date] timeIntervalSince1970] - 5.0f)];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];

    XCTAssertFalse(triggered);
    XCTAssertFalse(NSTimerOverrider.hasScheduledTimer);
}

// The session duration trigger is set to fire in 30 seconds into the session
- (void)testDynamicTriggerSessionDurationLaunchesTimer {
    let trigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withOperator:OSTriggerOperatorTypeEqualTo withValue:@30];
    let triggered = [[OSDynamicTriggerController new] dynamicTriggerShouldFire:trigger withMessageId:@"test_id"];
    
    XCTAssertFalse(triggered);
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
    XCTAssertTrue(fabs(NSTimerOverrider.mostRecentTimerInterval - 30.0f) < 0.1f);
}


// test to ensure that time-based triggers don't schedule timers
// until all other triggers evaluate to true.
- (void)testHandlesMultipleMixedTriggers {
    let firstTrigger = [OSTrigger customTriggerWithProperty:@"prop1" withId:@"test_id_1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@3];
    let secondTrigger = [OSTrigger dynamicTriggerWithKind:OS_DYNAMIC_TRIGGER_KIND_SESSION_TIME withId:@"test_id_2" withOperator:OSTriggerOperatorTypeGreaterThanOrEqualTo withValue:@3.0];
    let thirdTrigger = [OSTrigger customTriggerWithProperty:@"prop2" withId:@"test_id_3" withOperator:OSTriggerOperatorTypeNotExists withValue:nil];
    
    let message = [OSInAppMessageTestHelper testMessageWithTriggers:@[@[firstTrigger, secondTrigger, thirdTrigger]]];
    
    [self.triggerController addTriggers:@{@"prop1" : @4}];
    
    XCTAssertFalse([self.triggerController messageMatchesTriggers:message]);
    XCTAssertTrue(NSTimerOverrider.hasScheduledTimer);
}

@end

