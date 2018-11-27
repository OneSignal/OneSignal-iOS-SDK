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

NS_ASSUME_NONNULL_BEGIN

@interface OSTrigger (Test)
+ (instancetype)triggerWithProperty:(NSString *)property withOperator:(OSTriggerOperatorType)type withValue:(id _Nullable)value;
@end

@interface OSMessagingController (Test)
- (void)reset;
- (void)setTriggerWithName:(NSString *)name withValue:(id)value;
@end

@interface OSInAppMessageTestHelper : NSObject
+ (OSInAppMessage *)testMessageWithTriggersJson:(NSArray<NSDictionary *> *)triggers;
+ (OSInAppMessage *)testMessage;
+ (OSInAppMessage *)testMessageWithTriggers:(NSArray <NSArray<OSTrigger *> *> *)triggers;
+ (NSDictionary *)testRegistrationJsonWithMessages:(NSArray<NSDictionary *> *)messages;
+ (NSDictionary *)testMessageJsonWithTriggerPropertyName:(NSString *)property withOperator:(OSTriggerOperatorType)operator withValue:(id)value;
@end

NS_ASSUME_NONNULL_END
