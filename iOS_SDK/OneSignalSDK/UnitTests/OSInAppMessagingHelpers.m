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

#import "OSInAppMessagingHelpers.h"
#import "OneSignalHelper.h"
#import "OSTriggerController.h"
#import "OSMessagingController.h"

@implementation OSTrigger (Test)

+ (instancetype)triggerWithKind:(NSString *)kind withProperty:(NSString *)property withId:(NSString *)triggerId withOperator:(OSTriggerOperatorType)type withValue:(id)value {
    OSTrigger *trigger = [OSTrigger new];
    trigger.kind = kind;
    trigger.property = property;
    trigger.operatorType = type;
    trigger.value = value;
    trigger.triggerId = triggerId;
    
    return trigger;
}

+ (instancetype)dynamicTriggerWithKind:(NSString *)kind withId:(NSString *)triggerId withOperator:(OSTriggerOperatorType)type withValue:(id _Nullable)value {
    return [OSTrigger triggerWithKind:kind withProperty:@"dynamic" withId:triggerId withOperator:type withValue:value];
}

+ (instancetype)dynamicTriggerWithKind:(NSString *)kind withOperator:(OSTriggerOperatorType)type withValue:(id _Nullable)value {
    return [OSTrigger triggerWithKind:kind withProperty:@"dynamic" withId:@"test_trigger_id" withOperator:type withValue:value];
}

+ (instancetype)customTriggerWithProperty:(NSString *)property withId:(NSString *)triggerId withOperator:(OSTriggerOperatorType)type withValue:(id)value {
    return [OSTrigger triggerWithKind:@"custom" withProperty:property withId:triggerId withOperator:type withValue:value];
}

+ (instancetype)customTriggerWithProperty:(NSString *)property withOperator:(OSTriggerOperatorType)type withValue:(id)value {
    return [OSTrigger triggerWithKind:@"custom" withProperty:property withId:@"test_trigger_id" withOperator:type withValue:value];
}

@end

@implementation OSInAppMessageTestHelper

int messageIdIncrementer = 0;

+ (NSDictionary * _Nonnull)testActionJson {
    return @{
        @"click_type" : @"button",
        @"id" : @"test_action_id",
        @"close" : @NO,
        @"url" : @"",
        @"url_target" : @"browser",
    };
}

+ (NSDictionary * _Nonnull)testMessageJson {
    return @{
        @"type" : @"centered_modal", // Prevents issues with the "os_viewed_message" count trigger that lets us prevent a message from being shown > than X times
        @"id" : [NSString stringWithFormat:@"%@_%i", OS_TEST_MESSAGE_ID, ++messageIdIncrementer],
        @"variants" : @{
            @"ios" : @{
                @"default" : OS_TEST_MESSAGE_VARIANT_ID,
                @"en" : OS_TEST_ENGLISH_VARIANT_ID
            },
            @"all" : @{
                @"default" : @"should_never_be_used_by_any_test"
            }
        },
        @"triggers" : @[],
    };
}

+ (NSDictionary * _Nonnull)testMessageJsonRedisplay {
    return @{
        @"type" : @"centered_modal", // Prevents issues with the "os_viewed_message" count trigger that lets us prevent a message from being shown > than X times
        @"id" : [NSString stringWithFormat:@"%@_%i", OS_TEST_MESSAGE_ID, ++messageIdIncrementer],
        @"variants" : @{
                @"ios" : @{
                        @"default" : OS_TEST_MESSAGE_VARIANT_ID,
                        @"en" : OS_TEST_ENGLISH_VARIANT_ID

                },
                @"all" : @{
                        @"default" : @"should_never_be_used_by_any_test"

                }
        },
        @"triggers" : @[],
        @"redisplay" : @{
                @"limit" : @(5),
                @"delay" : @(60)

        }
    };
}

+ (NSDictionary * _Nonnull)testMessagePreviewJson {
    return @{
        @"aps" : @{
            @"alert" : @"Tap to see In-App Message preview",
            @"mutable-content" : @1,
            @"sound" : @"default"
        },
        @"custom": @{
            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
            @"a": @{
                @"os_in_app_message_preview_id" : @"c0e8dcb2-d966-4fdc-b345-36bbc00fe76a"
            }
        },
        @"triggers" : @[]
    };
}

+ (OSInAppMessage *)testMessageWithTriggersJson:(NSArray *)triggers {
    let messageJson = (NSMutableDictionary *)[self.testMessageJson mutableCopy];
    
    messageJson[@"triggers"] = triggers;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    return [OSInAppMessage instanceWithData:data];
}

+ (OSInAppMessage *)testMessageWithTriggersJson:(NSArray *)triggers redisplayLimit:(NSInteger)limit delay:(NSNumber *)delay {
    let messageJson = (NSMutableDictionary *)[self.testMessageJson mutableCopy];

    messageJson[@"has_liquid"] = @"1";
    messageJson[@"triggers"] = triggers;
    messageJson[@"redisplay"] =
        @{
            @"limit" : @(limit),
            @"delay" : delay
        };

    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];

    return [OSInAppMessage instanceWithData:data];
}

+ (OSInAppMessage *)testMessage {
    let messageJson = self.testMessageJson;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];

    return [OSInAppMessage instanceWithData:data];
}

+ (OSInAppMessage *)testMessageWithPastEndTime:(BOOL)pastEndTime {
    let messageJson = self.testMessageJson;
    
    NSMutableDictionary *messageJsonWithEndTime = [[NSMutableDictionary alloc] initWithDictionary:messageJson];
    if (pastEndTime) {
        messageJsonWithEndTime[@"end_time"] = @"1960-01-01T00:00:00.000Z";
    } else {
        messageJsonWithEndTime[@"end_time"] = @"2200-01-01T00:00:00.000Z";
    }
    let data = [NSJSONSerialization dataWithJSONObject:messageJsonWithEndTime options:0 error:nil];

    return [OSInAppMessage instanceWithData:data];
}

+ (OSInAppMessage *)testMessageWithRedisplayLimit:(NSInteger)limit delay:(NSNumber *)delay {
     let messageJson = self.testMessageJsonRedisplay;

    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];

    let message = [OSInAppMessage instanceWithData:data];

    message.displayStats.displayLimit = limit;
    message.displayStats.displayDelay = [delay doubleValue];

    return message;
}

+ (OSInAppMessage *)testMessageWithTriggers:(NSArray <NSArray<OSTrigger *> *> *)triggers {
    let messageJson = self.testMessageJson;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    let message = [OSInAppMessage instanceWithData:data];
    
    message.triggers = triggers;
    
    return message;
}

+ (OSInAppMessage *)testMessageWithTriggers:(NSArray <NSArray<OSTrigger *> *> *)triggers withRedisplayLimit:(NSInteger)limit delay:(NSNumber *)delay {
    let messageJson = self.testMessageJsonRedisplay;

    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];

    let message = [OSInAppMessage instanceWithData:data];

    message.displayStats.displayLimit = limit;
    message.displayStats.displayDelay = [delay doubleValue];
    message.triggers = triggers;

    return message;
}

+ (NSDictionary *)testRegistrationJsonWithMessages:(NSArray<NSDictionary *> *)messages {
    return @{
        @"id" : @"1234",
        @"success" : @1,
        @"in_app_messages" : messages
    };
}

+ (NSDictionary *)testMessageJsonWithTriggerPropertyName:(NSString *)property withId:(NSString *)triggerId withOperator:(OSTriggerOperatorType)type withValue:(id)value {
    let testMessage = (NSMutableDictionary *)[[self testMessageJson] mutableCopy];
    
    testMessage[@"triggers"] = @[
         @[
             @{
                 @"kind" : property,
                 @"property" : property,
                 @"operator" : OS_OPERATOR_TO_STRING(type),
                 @"value" : value,
                 @"id" : triggerId
             }
         ]
     ];
    
    return testMessage;
}

+ (NSDictionary*)testInAppMessageGetContainsWithHTML:(NSString*)html {
    return @{
      @"html": html,
      @"display_duration": @123
    };
}

@end



// This category lets us access the messaging controller's trigger controller
// which is normally private
@interface OSMessagingController (Testing)
@property (strong, nonatomic, nonnull) OSTriggerController *triggerController;
@property (strong, nonatomic, nonnull) NSArray <OSInAppMessage *> *messages;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessage *> *messageDisplayQueue;
@end

@implementation OSMessagingController (Testing)

@dynamic messages;
@dynamic messageDisplayQueue;
@dynamic triggerController;

- (void)setTriggerWithName:(NSString *)name withValue:(id)value {
    [self.triggerController addTriggers:@{name : value}];
}

@end
