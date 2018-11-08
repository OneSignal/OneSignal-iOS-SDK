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

@implementation OSTrigger (Test)

+ (instancetype)triggerWithProperty:(NSString *)property withOperator:(OSTriggerOperatorType)type withValue:(id)value {
    OSTrigger *trigger = [OSTrigger new];
    trigger.property = property;
    trigger.operatorType = type;
    trigger.value = value;
    
    return trigger;
}

@end

@implementation OSInAppMessage (Test)

+ (NSDictionary *)testMessageJson {
    return @{
        @"type" : @"centered_modal",
        @"id" : @"a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba",
        @"content_id" : @"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba",
        @"triggers" : @[]
    };
}

+ (instancetype)testMessageWithTriggersJson:(NSArray *)triggers {
    let messageJson = (NSMutableDictionary *)[self.testMessageJson mutableCopy];
    
    messageJson[@"triggers"] = triggers;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    return [OSInAppMessage instanceWithData:data];
}

+ (instancetype)testMessage {
    let messageJson = self.testMessageJson;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    return [OSInAppMessage instanceWithData:data];
}

+ (instancetype)testMessageWithTriggers:(NSArray <NSArray<OSTrigger *> *> *)triggers {
    let messageJson = self.testMessageJson;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    let message = [OSInAppMessage instanceWithData:data];
    
    message.triggers = triggers;
    
    return message;
}

+ (NSDictionary *)testRegistrationJsonWithTriggerProperty:(NSString *)property withOperator:(NSString *)operator withValue:(id)value {
    let testMessage = (NSMutableDictionary *)[[self testMessageJson] mutableCopy];
    
    testMessage[@"triggers"] = @[
        @[
            @{
                @"property" : property,
                @"operator" : operator,
                @"value" : value
            }
        ]
    ];
    
    return @{
        @"id" : @"1234",
        @"success" : @1,
        @"messages" : @[testMessage]
    };
}

@end
