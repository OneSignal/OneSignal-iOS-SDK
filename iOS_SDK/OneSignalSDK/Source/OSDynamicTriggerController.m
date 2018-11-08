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

@interface OSDynamicTriggerController ()

/**
    Maps messageId's to future scheduled time-based triggers
    For example, a message might conceivably have a session_duration trigger
    and an os_time trigger both scheduled for the future
 
    This dictionary prevents the SDK from scheduling multiple duplicate timers
    for the same messageId + trigger type.
*/
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSString *, NSMutableArray <NSString *> *> *scheduledMessages;

@end

@implementation OSDynamicTriggerController

+ (OSDynamicTriggerController *)sharedInstance {
    static OSDynamicTriggerController *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [OSDynamicTriggerController new];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.scheduledMessages = [NSMutableDictionary new];
    }
    
    return self;
}

- (BOOL)triggerExpressionIsTrueForValue:(id)value withTriggerType:(NSString *)triggerType withMessageId:(NSString *)messageId {
    if (!value)
        return false;
    
    if ([triggerType isEqualToString:OS_SDK_VERSION_TRIGGER]) {
        return [value isEqualToString:OS_SDK_VERSION];
    }
    
    //currently all other supported dunamic triggers are time-based triggers
    return [self timeBasedTriggerIsTrueForValue:value withTriggerType:triggerType withMessageId:messageId];
}

- (BOOL)timeBasedTriggerIsTrueForValue:(id)value withTriggerType:(NSString *)property withMessageId:(NSString *)messageId {
    @synchronized (self.scheduledMessages) {
        if (![value isKindOfClass:[NSNumber class]])
            return false;
        
        // This would mean we've already set up a timer for this message trigger
        if (self.scheduledMessages[messageId] && [self.scheduledMessages[messageId] containsObject:property])
            return false;
        
        let requiredTimeValue = [value doubleValue];
        
        // how long to set the timer for (if needed)
        var offset = 0.0f;
        
        if ([property isEqualToString:OS_SESSION_DURATION_TRIGGER]) {
            let currentDuration = fabs([[OneSignal sessionLaunchTime] timeIntervalSinceNow]);
            
            if (currentDuration >= requiredTimeValue)
                return true;
            
            offset = currentDuration - requiredTimeValue;
        } else if ([property isEqualToString:OS_TIME_TRIGGER]) {
            let currentTimestamp = [[NSDate date] timeIntervalSince1970];
            
            if (currentTimestamp >= requiredTimeValue)
                return true;
            
            offset = requiredTimeValue - currentTimestamp;
        } else if ([property isEqualToString:OS_EXACT_TIME_TRIGGER]) {
            let currentTimestamp = [[NSDate date] timeIntervalSince1970];
            
            // if we are within 1 second of the required date, the trigger should fire
            // But since this is the Exact time trigger, if the date is already passed,
            // we should return false 
            if (fabs(requiredTimeValue - currentTimestamp) <= 1.0)
                return true;
            else if (currentTimestamp > requiredTimeValue)
                return false;
            
            offset = requiredTimeValue - currentTimestamp;
        }
        
        // if we reach this point, it means we need to return false and set up a timer for a future time
        [NSTimer scheduledTimerWithTimeInterval:offset target:self selector:@selector(timerFiredForMessage) userInfo:nil repeats:false];
        
        if (self.scheduledMessages[messageId]) {
            [self.scheduledMessages[messageId] addObject:property];
        } else {
            self.scheduledMessages[messageId] = [NSMutableArray arrayWithObject:property];
        }
    }
    
    return false;
}

- (void)timerFiredForMessage {
    [self.delegate dynamicTriggerFired];
}

@end
