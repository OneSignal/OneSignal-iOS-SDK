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

#import "NSTimerOverrider.h"

#import "OneSignalSelectorHelpers.h"
#import "TestHelperFunctions.h"
#import "DelayedSelectors.h"

#define NSTIMER_INTERVAL_MAX 9999999999

// Due to issues swizzling Class methods in Objective-C,
// we'll use a Category to implement this method
@implementation NSTimer (Testing)
+ (NSTimer *)overrideTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo {
    NSTimerOverrider.mostRecentTimerInterval = ti;
    
    NSTimerOverrider.hasScheduledTimer = true;
    
    if (NSTimerOverrider.shouldScheduleTimers) {
        return [NSTimer overrideTimerWithTimeInterval:ti target:aTarget selector:aSelector userInfo:userInfo repeats:yesOrNo];
    }
    return [NSTimer new];
}

+ (NSTimer *)overrideScheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo {
    NSTimerOverrider.mostRecentTimerInterval = ti;
    
    NSTimerOverrider.hasScheduledTimer = true;
    
    if (NSTimerOverrider.shouldScheduleTimers) {
        // Call original as we need to assign userInfo to the timer
        NSTimer* timer = [NSTimer overrideScheduledTimerWithTimeInterval:NSTIMER_INTERVAL_MAX target:nil selector:nil userInfo:userInfo repeats:false];
        [NSTimerOverrider.delayedSelectors addSelector:aSelector onObject:aTarget withObject:timer];
        return timer;
    }
    return [NSTimer new];
}
@end

@implementation NSTimerOverrider

static BOOL _shouldScheduleTimers;
static BOOL _hasScheduledTimer;

// The most recently scheduled delay/interval for NSTimer
static NSTimeInterval _mostRecentTimerInterval;
static NSTimeInterval _previousMostRecentTimeInterval;

static DelayedSelectors* _delayedSelectors;

+(void)load {
    swizzleClassMethodWithCategoryImplementation(NSTimer.class, @selector(timerWithTimeInterval:target:selector:userInfo:repeats:), @selector(overrideTimerWithTimeInterval:target:selector:userInfo:repeats:));
    swizzleClassMethodWithCategoryImplementation(NSTimer.class, @selector(scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:), @selector(overrideScheduledTimerWithTimeInterval:target:selector:userInfo:repeats:));
    
}

+ (void)reset {
    _shouldScheduleTimers = true;
    _hasScheduledTimer = false;
    _mostRecentTimerInterval = 0.0f;
    _previousMostRecentTimeInterval = 0.0f;
    _delayedSelectors = [DelayedSelectors new];
}

+(NSTimeInterval)mostRecentTimerInterval {
    return _mostRecentTimerInterval;
}

+(void)setMostRecentTimerInterval:(NSTimeInterval)mostRecentTimerInterval {
    _previousMostRecentTimeInterval = _mostRecentTimerInterval;
    _mostRecentTimerInterval = mostRecentTimerInterval;
}

+(BOOL)shouldScheduleTimers {
    return _shouldScheduleTimers;
}

+(void)setShouldScheduleTimers:(BOOL)shouldScheduleTimers {
    _shouldScheduleTimers = shouldScheduleTimers;
}

+(BOOL)hasScheduledTimer {
    return _hasScheduledTimer;
}

+(void)setHasScheduledTimer:(BOOL)hasScheduledTimer {
    _hasScheduledTimer = hasScheduledTimer;
}
         
+ (DelayedSelectors*)delayedSelectors {
    return _delayedSelectors;
}

+ (void)runPendingSelectors {
    [_delayedSelectors runPendingSelectors];
}

@end
