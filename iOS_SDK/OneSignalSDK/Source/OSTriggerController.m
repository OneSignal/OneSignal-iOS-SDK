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

#import "OSTriggerController.h"
#import "OSInAppMessagingDefines.h"
#import "OneSignalHelper.h"

@interface OSTriggerController ()
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSString *, id> *triggers;
@property (strong, nonatomic, nonnull) NSUserDefaults *defaults;
@end

@implementation OSTriggerController

+ (OSTriggerController *)sharedInstance {
    static OSTriggerController *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [OSTriggerController new];
    });
    return sharedInstance;
}

- (instancetype _Nonnull)init {
    if (self = [super init]) {
        self.triggers = ([[self triggersFromUserDefaults] mutableCopy] ?: [NSMutableDictionary<NSString *, id> new]);
        self.defaults = [NSUserDefaults standardUserDefaults];
    }
    
    return self;
}

#pragma mark Public Methods
- (void)addTriggers:(NSDictionary<NSString *, id> *)triggers {
    @synchronized (self.triggers) {
        [self.triggers addEntriesFromDictionary:triggers];
        
        [self didUpdateTriggers];
    }
}

- (void)removeTriggersForKeys:(NSArray<NSString *> *)keys {
    @synchronized (self.triggers) {
        for (NSString *key in keys)
            [self.triggers removeObjectForKey:key];
        
        [self didUpdateTriggers];
    }
}

- (void)addTriggerWithKey:(NSString *)key withValue:(id)value {
    [self addTriggers:@{key : value}];
}

- (void)removeTriggerForKey:(NSString *)key {
    [self removeTriggersForKeys:@[key]];
}

#pragma mark Private Methods

/**
    Triggers on a message are structured as a 2D array, where the outer array represents OR conditions
    and the inner array represents AND conditions.
 
    Because of this structure, we use a nested for-loop. In the inner loop, it continues to evaluate. If
    at any point it determines a trigger condition is FALSE, it breaks and the outer loop continues.
 
    But if the inner loop never hits a condition that is FALSE, it continues looping until it hits the
    last condition. If the last condition is also true, it returns YES.
 
    Supports both String and Numeric value types & comparisons
*/
- (BOOL)messageMatchesTriggers:(OSInAppMessage *)message {
    for (NSArray <OSTrigger *> *conditions in message.triggers) {
        for (int i = 0; i < conditions.count; i++) {
            let trigger = conditions[i];
            
            if (!self.triggers[trigger.property])
                break;
            
            // the Exists operator requires no comparisons or equality check
            if (trigger.operatorType == OSTriggerOperatorTypeExists) {
                if (i == conditions.count - 1)
                    return true;
                else continue;
            }
            
            id realValue = self.triggers[trigger.property];
            
            if (trigger.operatorType == OSTriggerOperatorTypeContains) {
                if (![self array:realValue containsValue:trigger.value])
                    break;
                else if (i == conditions.count - 1)
                    return true;
                else continue;
            } else if (![trigger.value isKindOfClass:[realValue class]] ||
                ([trigger.value isKindOfClass:[NSNumber class]] && ![self trigger:trigger matchesNumericValue:realValue]) ||
                ([trigger.value isKindOfClass:[NSString class]] && ![trigger.value isEqualToString:realValue])) {
                break;
            } else if (i == conditions.count - 1) {
                return true;
            }
        }
    }
    
    return false;
}

- (BOOL)triggerValue:(id)triggerValue isEqualToValue:(id)value {
    return ([triggerValue isKindOfClass:[value class]] &&
     (([triggerValue isKindOfClass:[NSNumber class]] && [triggerValue isEqualToNumber:value]) ||
      ([triggerValue isKindOfClass:[NSString class]] && [triggerValue isEqualToString:value])));
}

- (BOOL)array:(NSArray *)array containsValue:(id)value {
    if (!array) return false;
    
    for (id element in array)
        if ([self triggerValue:value isEqualToValue:element])
            return true;
    
    return false;
}

- (BOOL)trigger:(OSTrigger *)trigger matchesNumericValue:(id)realValue {
    switch (trigger.operatorType) {
        case OSTriggerOperatorTypeGreaterThan:
            return [realValue doubleValue] > [trigger.value doubleValue];
        case OSTriggerOperatorTypeEqualTo:
            return [realValue isEqualToNumber:trigger.value];
        case OSTriggerOperatorTypeLessThan:
            return [realValue doubleValue] < [trigger.value doubleValue];
        case OSTriggerOperatorTypeLessThanOrEqualTo:
            return [realValue doubleValue] <= [trigger.value doubleValue];
        case OSTriggerOperatorTypeGreaterThanOrEqualTo:
            return [realValue doubleValue] >= [trigger.value doubleValue];
        case OSTriggerOperatorTypeExists:
            @throw [NSException exceptionWithName:@"OneSignal Extension" reason:@"Attempted to compare/check equality for a non-comparative operator (OSTriggerOperatorTypeExists)" userInfo:nil];
        case OSTriggerOperatorTypeContains:
            @throw [NSException exceptionWithName:@"OneSignal Extension" reason:@"Attempted to compare/check equality for a non-comparative operator (OSTriggerOperatorTypeContains)" userInfo:nil];
    }
}

- (NSDictionary<NSString *, id> * _Nullable)triggersFromUserDefaults {
    return [self.defaults dictionaryForKey:OS_TRIGGERS_KEY];
}

- (void)didUpdateTriggers {
    [self.defaults setObject:self.triggers forKey:OS_TRIGGERS_KEY];
    [self.defaults synchronize];
}

@end
