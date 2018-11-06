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

#import "OSMessagingTriggerController.h"
#import "OSInAppMessagingDefines.h"
#import "OneSignalHelper.h"

@interface OSMessagingTriggerController ()
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSString *, id> *triggers;
@property (strong, nonatomic, nonnull) NSUserDefaults *defaults;
@end

@implementation OSMessagingTriggerController

+ (OSMessagingTriggerController *)sharedInstance {
    static OSMessagingTriggerController *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [OSMessagingTriggerController new];
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
            
            if (![trigger.value isKindOfClass:[realValue class]]) {
                break;
            } else if ([trigger.value isKindOfClass:[NSNumber class]] && ![self trigger:trigger matchesValue:realValue]) {
                break;
            } else if ([trigger.value isKindOfClass:[NSString class]] && ![trigger.value isEqualToString:realValue]) {
                break;
            } else if (i == conditions.count - 1) {
                return true;
            }
        }
    }
    
    return false;
}

- (BOOL)trigger:(OSTrigger *)trigger matchesValue:(id)realValue {
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
    }
}

#pragma mark Private Methods
- (NSDictionary<NSString *, id> * _Nullable)triggersFromUserDefaults {
    return [self.defaults dictionaryForKey:OS_TRIGGERS_KEY];
}

- (void)didUpdateTriggers {
    [self.defaults setObject:self.triggers forKey:OS_TRIGGERS_KEY];
    [self.defaults synchronize];
}

@end
