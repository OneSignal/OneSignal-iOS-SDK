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
#import "OSMessagingTriggerController.h"

@interface OSTrigger (Test)
+ (instancetype)triggerWithProperty:(NSString *)property withOperator:(OSTriggerOperatorType)type withValue:(id)value;
@end

@implementation OSTrigger (Test)

+ (instancetype)triggerWithProperty:(NSString *)property withOperator:(OSTriggerOperatorType)type withValue:(id)value {
    OSTrigger *trigger = [OSTrigger new];
    trigger.property = property;
    trigger.operatorType = type;
    trigger.value = value;
    
    return trigger;
}

@end


/**
 Test to make sure that OSInAppMessage correctly
 implements the OSJSONDecodable protocol
 and all properties are parsed correctly
 */

@interface InAppMessagingTests : XCTestCase
@property (strong, nonatomic) OSMessagingTriggerController *triggerController;
@end

@implementation InAppMessagingTests {
    OSInAppMessage *testMessage;
}

-(void)setUp {
    [super setUp];
    testMessage = [self messageWithTriggers:@[
        @[
            @{
                @"property" : @"view_controller",
                @"operator" : @"==",
                @"value" : @"home_vc"
            }
        ]
    ]];
    
    self.triggerController = [OSMessagingTriggerController new];
}

- (OSInAppMessage *)messageWithTriggers:(NSArray *)triggers {
    let messageJson = @{
        @"type" : @"centered_modal",
        @"id" : @"a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba",
        @"content_id" : @"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba",
        @"triggers" : triggers
    };
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    return [[OSInAppMessage alloc] initWithData:data];
}

- (void)testCorrectlyParsedType {
    XCTAssertTrue(testMessage.type == OSInAppMessageDisplayTypeCenteredModal);
}

-(void)testCorrectlyParsedMessageId {
    XCTAssertTrue([testMessage.messageId isEqualToString:@"a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba"]);
}

-(void)testCorrectlyParsedContentId {
    XCTAssertTrue([testMessage.contentId isEqualToString:@"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba"]);
}

-(void)testCorrectlyParsedTriggers {
    XCTAssertTrue(testMessage.triggers.count == 1);
    XCTAssertEqual(testMessage.triggers.firstObject.firstObject.operatorType, OSTriggerOperatorTypeEqualTo);
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.property, @"view_controller");
    XCTAssertEqualObjects(testMessage.triggers.firstObject.firstObject.value, @"home_vc");
}

-(void)testTriggersWithOneCondition {
    let testMessage = [self messageWithTriggers:@[]];
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@2];
    testMessage.triggers = @[@[trigger]];
    
    [self.triggerController addTriggerWithKey:@"prop1" withValue:@1];
    
    // since the local trigger for prop1 is 1, and the message filter requires >= 2,
    // the message should not match and should evaluate to false
    XCTAssertFalse([self.triggerController messageMatchesTriggers:testMessage]);
}

-(void)testTriggersWithTwoConditions {
    let testMessage = [self messageWithTriggers:@[]];
    let trigger1 = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeLessThanOrEqualTo withValue:@-3];
    let trigger2 = [OSTrigger triggerWithProperty:@"prop2" withOperator:OSTriggerOperatorTypeEqualTo withValue:@2];
    testMessage.triggers = @[@[trigger1, trigger2]];
    
    [self.triggerController addTriggers:@{
        @"prop1" : @-4.3,
        @"prop2" : @2
    }];
    
    // Both triggers should evaluate to true
    XCTAssertTrue([self.triggerController messageMatchesTriggers:testMessage]);
}

-(void)testTriggersWithOrCondition {
    let testMessage = [self messageWithTriggers:@[]];
    let trigger1 = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeLessThanOrEqualTo withValue:@-3];
    let trigger2 = [OSTrigger triggerWithProperty:@"prop2" withOperator:OSTriggerOperatorTypeEqualTo withValue:@2];
    testMessage.triggers = @[@[trigger1], @[trigger2]];
    
    // The first trigger should evaluate to false, but since the first level array
    // represents OR conditions and the second trigger array evaluates to true,
    // the whole result should be true
    [self.triggerController addTriggers:@{
        @"prop1" : @7.3,
        @"prop2" : @2
    }];
    
    XCTAssertTrue([self.triggerController messageMatchesTriggers:testMessage]);
}

-(void)testTriggerWithMissingValue {
    let testMessage = [self messageWithTriggers:@[]];
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeGreaterThan withValue:@2];
    testMessage.triggers = @[@[trigger]];
    
    // the trigger controller will have no value for 'prop1'
    XCTAssertFalse([self.triggerController messageMatchesTriggers:testMessage]);
}

- (void)testExistsOperator {
    let testMessage = [self messageWithTriggers:@[]];
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:OSTriggerOperatorTypeExists withValue:nil];
    testMessage.triggers = @[@[trigger]];
    
    // the property 'prop1' has not been set on local triggers, so the
    // Exists operator should return false
    XCTAssertFalse([self.triggerController messageMatchesTriggers:testMessage]);
    
    [self.triggerController addTriggerWithKey:@"prop1" withValue:@"test"];
    
    // Now that we have set a value for 'prop1', the check should return true
    XCTAssertTrue([self.triggerController messageMatchesTriggers:testMessage]);
}

- (BOOL)setupComparativeOperatorTest:(OSTriggerOperatorType)operator withTrigger:(NSNumber *)triggerValue withLocalValue:(NSNumber *)localValue {
    let testMessage = [self messageWithTriggers:@[]];
    let trigger = [OSTrigger triggerWithProperty:@"prop1" withOperator:operator withValue:triggerValue];
    testMessage.triggers = @[@[trigger]];
    
    [self.triggerController addTriggerWithKey:@"prop1" withValue:localValue];
    
    return [self.triggerController messageMatchesTriggers:testMessage];
}

- (void)testGreaterThan {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThan withTrigger:@3 withLocalValue:@3.1]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThan withTrigger:@2.1 withLocalValue:@2]);
}

- (void)testGreaterThanOrEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTrigger:@3 withLocalValue:@3]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTrigger:@2 withLocalValue:@2.9]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeGreaterThanOrEqualTo withTrigger:@5 withLocalValue:@4]);
}

- (void)testEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTrigger:@0.1 withLocalValue:@0.1]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeEqualTo withTrigger:@0.0 withLocalValue:@2]);
}

- (void)testLessThan {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTrigger:@2 withLocalValue:@1.9]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThan withTrigger:@3 withLocalValue:@4]);
}

- (void)testLessThanOrEqualTo {
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTrigger:@5 withLocalValue:@4]);
    XCTAssertTrue([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTrigger:@3 withLocalValue:@3]);
    XCTAssertFalse([self setupComparativeOperatorTest:OSTriggerOperatorTypeLessThanOrEqualTo withTrigger:@3 withLocalValue:@4]);
}

@end

