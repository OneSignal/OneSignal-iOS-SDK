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

#import "OSDynamicTriggerController.h"
#import "OSInAppMessagingDefines.h"
#import "OneSignalHelper.h"
#import "OneSignalInternal.h"
#import "OneSignalCommonDefines.h"

@interface OSDynamicTriggerController ()

/**
    Maps messageId's to future scheduled time-based triggers
    For example, a message might conceivably have a session_duration trigger
    and an os_time trigger both scheduled for the future
 
    This dictionary prevents the SDK from scheduling multiple duplicate timers
    for the same messageId + trigger type.
*/
@property (strong, nonatomic, nonnull) NSMutableArray<NSString *> *scheduledMessages;

@end

@implementation OSDynamicTriggerController

- (instancetype)init {
    if (self = [super init]) {
        self.scheduledMessages = [NSMutableArray new];
    }
    
    return self;
}

- (BOOL)dynamicTriggerShouldFire:(OSTrigger *)trigger withMessageId:(NSString *)messageId {
    if (!trigger.value)
        return false;
    
    if ([trigger.property isEqualToString:OS_SDK_VERSION_TRIGGER]) {
        return [trigger.value isEqualToString:OS_SDK_VERSION];
    } else if ([trigger.property isEqualToString:OS_DEVICE_TYPE_TRIGGER]) {
        
        
        let isTablet = OneSignalHelper.isTablet;
        
        let matches = [trigger.value isEqualToString:(isTablet ? OS_DEVICE_TYPE_TABLET : OS_DEVICE_TYPE_PHONE)];
        
        return trigger.operatorType == OSTriggerOperatorTypeEqualTo ? matches : !matches;
    }
    
    //currently all other supported dunamic triggers are time-based triggers
    return [self timeBasedDynamicTriggerIsTrue:trigger withMessageId:messageId];
}

- (BOOL)timeBasedDynamicTriggerIsTrue:(OSTrigger *)trigger withMessageId:(NSString *)messageId {
    @synchronized (self.scheduledMessages) {
        
        // All time-based trigger values should be numbers (either timestamps or offsets)
        if (![trigger.value isKindOfClass:[NSNumber class]])
            return false;
        
        let triggerId = [trigger uniqueIdentifierForTriggerFromMessageWithMessageId:messageId];
        
        // This would mean we've already set up a timer for this message trigger
        if ([self.scheduledMessages containsObject:triggerId])
            return false;
        
        let requiredTimeValue = [trigger.value doubleValue];
        
        // how long to set the timer for (if needed)
        var offset = 0.0f;
        
        // check what type of trigger it is
        if ([trigger.property isEqualToString:OS_SESSION_DURATION_TRIGGER]) {
            let currentDuration = fabs([[OneSignal sessionLaunchTime] timeIntervalSinceNow]);
            
            if ([self evaluateTimeInterval:requiredTimeValue withCurrentValue:currentDuration forOperator:trigger.operatorType])
                return true;
            
            offset = requiredTimeValue - currentDuration;
        } else if ([trigger.property isEqualToString:OS_TIME_TRIGGER]) {
            let currentTimestamp = [[NSDate date] timeIntervalSince1970];
            
            if ([self evaluateTimeInterval:requiredTimeValue withCurrentValue:currentTimestamp forOperator:trigger.operatorType])
                return true;
            
            offset = requiredTimeValue - currentTimestamp;
        }
        
        // don't schedule timers for the past
        if (offset <= 0.0f)
            return false;
        
        // if we reach this point, it means we need to return false and set up a timer for a future time
        let timer = [NSTimer timerWithTimeInterval:offset target:self selector:@selector(timerFiredForMessage:) userInfo:@{@"messageId" : messageId, @"trigger" : trigger} repeats:false];
        
        if (timer)
            [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        
        [self.scheduledMessages addObject:triggerId];
    }
    
    return false;
}

/**
    Time-based triggers can use operators like < to trigger at specific times.
    For example, the "session duration" trigger can be triggered 
*/
- (BOOL)evaluateTimeInterval:(NSTimeInterval)timeInterval withCurrentValue:(NSTimeInterval)currentTimeInterval forOperator:(OSTriggerOperatorType)operator {
    switch (operator) {
        case OSTriggerOperatorTypeLessThan:
            return currentTimeInterval < timeInterval;
        case OSTriggerOperatorTypeLessThanOrEqualTo: //due to potential floating point error, consider very small differences to be equal
            return currentTimeInterval <= timeInterval || OS_ROUGHLY_EQUAL(timeInterval, currentTimeInterval);
        case OSTriggerOperatorTypeGreaterThan:
            return currentTimeInterval > timeInterval;
        case OSTriggerOperatorTypeGreaterThanOrEqualTo: //due to potential floating point error, consider very small differences to be equal
            return currentTimeInterval >= timeInterval || OS_ROUGHLY_EQUAL(timeInterval, currentTimeInterval);
        case OSTriggerOperatorTypeEqualTo:
            return OS_ROUGHLY_EQUAL(timeInterval, currentTimeInterval);
        case OSTriggerOperatorTypeNotEqualTo:
            return !OS_ROUGHLY_EQUAL(timeInterval, currentTimeInterval);
        case OSTriggerOperatorTypeExists:
        case OSTriggerOperatorTypeNotExists:
        case OSTriggerOperatorTypeContains:
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Attempted to apply an invalid operator on a time-based in-app-message trigger: %@", OS_OPERATOR_TO_STRING(operator)]];
            return false;
    }
    
    
    return false;
}

- (void)timerFiredForMessage:(NSTimer *)timer {
    @synchronized (self.scheduledMessages) {
        let messageId = (NSString *)timer.userInfo[@"messageId"];
        let trigger = (OSTrigger *)timer.userInfo[@"trigger"];
        
        [self.scheduledMessages removeObject:[trigger uniqueIdentifierForTriggerFromMessageWithMessageId:messageId]];
        
        [self.delegate dynamicTriggerFired];
    }
}

@end
