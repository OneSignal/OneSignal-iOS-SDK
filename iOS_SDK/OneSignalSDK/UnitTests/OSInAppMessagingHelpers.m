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

+ (instancetype)triggerWithProperty:(NSString *)property withOperator:(OSTriggerOperatorType)type withValue:(id)value {
    OSTrigger *trigger = [OSTrigger new];
    trigger.property = property;
    trigger.operatorType = type;
    trigger.value = value;
    
    return trigger;
}

@end

@implementation OSInAppMessageTestHelper

+ (NSDictionary *)testMessageJson {
    return @{
        @"type" : @"centered_modal",
        @"id" : @"a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba",
        @"content_id" : @"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba",
        @"triggers" : @[]
    };
}

+ (OSInAppMessage *)testMessageWithTriggersJson:(NSArray *)triggers {
    let messageJson = (NSMutableDictionary *)[self.testMessageJson mutableCopy];
    
    messageJson[@"triggers"] = triggers;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    return [OSInAppMessage instanceWithData:data];
}

+ (OSInAppMessage *)testMessage {
    let messageJson = self.testMessageJson;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    return [OSInAppMessage instanceWithData:data];
}

+ (OSInAppMessage *)testMessageWithTriggers:(NSArray <NSArray<OSTrigger *> *> *)triggers {
    let messageJson = self.testMessageJson;
    
    let data = [NSJSONSerialization dataWithJSONObject:messageJson options:0 error:nil];
    
    let message = [OSInAppMessage instanceWithData:data];
    
    message.triggers = triggers;
    
    return message;
}

+ (NSDictionary *)testRegistrationJsonWithMessages:(NSArray<NSDictionary *> *)messages {
    return @{
        @"id" : @"1234",
        @"success" : @1,
        @"messages" : messages
    };
}

+ (NSDictionary *)testMessageJsonWithTriggerPropertyName:(NSString *)property withOperator:(NSString *)operator withValue:(id)value {
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
    
    return testMessage;
}

@end



// This category lets us access the messaging controller's trigger controller
// which is normally private
@interface OSMessagingController (Test)
@property (strong, nonatomic, nonnull) OSTriggerController *triggerController;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessage *> *messageDisplayQueue;
@end

@implementation OSMessagingController (Test)

@dynamic messageDisplayQueue;
@dynamic triggerController;

- (void)reset {
    [self.messageDisplayQueue removeAllObjects];
}

- (void)setTriggerWithName:(NSString *)name withValue:(id)value {
    [self.triggerController addTriggers:@{name : value}];
}

@end
