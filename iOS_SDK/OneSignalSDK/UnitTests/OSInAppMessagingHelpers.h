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

#import <Foundation/Foundation.h>
#import "OSTrigger.h"
#import "OSInAppMessage.h"
#import "OSMessagingController.h"

#define OS_TEST_MESSAGE_ID @"a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba"
#define OS_TEST_MESSAGE_VARIANT_ID @"m8dh7234f-d8cc-11e4-bed1-df8f05be55ba"
#define OS_TEST_ENGLISH_VARIANT_ID @"11e4-bed1-df8f05be55ba-m8dh7234f-d8cc"

#define OS_DUMMY_HTML @"<html><h1>Hello World</h1></html>"

NS_ASSUME_NONNULL_BEGIN

@interface OSTrigger (Test)
+ (instancetype)triggerWithKind:(NSString *)kind withProperty:(NSString *)property withId:(NSString *)triggerId withOperator:(OSTriggerOperatorType)type withValue:(id)value;
+ (instancetype)dynamicTriggerWithKind:(NSString *)kind withId:(NSString *)triggerId withOperator:(OSTriggerOperatorType)type withValue:(id _Nullable)value;
+ (instancetype)dynamicTriggerWithKind:(NSString *)kind withOperator:(OSTriggerOperatorType)type withValue:(id _Nullable)value;
+ (instancetype)customTriggerWithProperty:(NSString *)property withId:(NSString *)triggerId withOperator:(OSTriggerOperatorType)type withValue:(id)value;
+ (instancetype)customTriggerWithProperty:(NSString *)property withOperator:(OSTriggerOperatorType)type withValue:(id _Nullable)value;
@end

@interface OSMessagingController (Test)
- (void)reset;
- (void)setTriggerWithName:(NSString *)name withValue:(id)value;
@end

@interface OSInAppMessageTestHelper : NSObject
+ (NSDictionary *)testActionJson;
+ (OSInAppMessage *)testMessageWithTriggersJson:(NSArray<NSDictionary *> *)triggers;
+ (OSInAppMessage *)testMessageWithTriggersJson:(NSArray *)triggers redisplayLimit:(NSInteger)limit delay:(NSNumber *)delay;
+ (OSInAppMessage *)testMessage;
+ (OSInAppMessage *)testMessageWithRedisplayLimit:(NSInteger)limit delay:(NSNumber *)delay;
+ (OSInAppMessage *)testMessagePreview;
+ (OSInAppMessage *)testMessageWithTriggers:(NSArray <NSArray<OSTrigger *> *> *)triggers;
+ (OSInAppMessage *)testMessageWithTriggers:(NSArray <NSArray<OSTrigger *> *> *)triggers withRedisplayLimit:(NSInteger)limit delay:(NSNumber *)delay;
+ (OSInAppMessage *)testMessageWithPastEndTime:(BOOL)pastEndTime;
+ (NSDictionary *)testRegistrationJsonWithMessages:(NSArray<NSDictionary *> *)messages;
+ (NSDictionary *)testMessageJsonWithTriggerPropertyName:(NSString *)property withId:(NSString *)triggerId withOperator:(OSTriggerOperatorType)type withValue:(id)value;
+ (NSDictionary*)testInAppMessageGetContainsWithHTML:(NSString *)html;
+ (NSDictionary *)testMessagePreviewJson;
@end

NS_ASSUME_NONNULL_END
