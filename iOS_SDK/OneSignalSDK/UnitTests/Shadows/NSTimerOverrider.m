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

#import "NSTimerOverrider.h"

// Due to issues swizzling Class methods in Objective-C,
// we'll use a Category to implement this method
@implementation NSTimer (Testing)
+ (NSTimer *)overrideTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(nullable id)userInfo repeats:(BOOL)yesOrNo {
    NSTimerOverrider.mostRecentTimerInterval = ti;
    
    NSTimerOverrider.hasScheduledTimer = true;
    
    if (NSTimerOverrider.shouldScheduleTimers) {
        return [NSTimer overrideTimerWithTimeInterval:ti target:aTarget selector:aSelector userInfo:userInfo repeats:yesOrNo];
    } else {
        return [NSTimer new];
    }
}
@end

@implementation NSTimerOverrider

static BOOL _shouldScheduleTimers = false;
static BOOL _hasScheduledTimer = false;
static NSTimeInterval _mostRecentTimerInterval = 0.0f;

+(void)load {
    swizzleClassMethodWithCategoryImplementation([NSTimer class], @selector(timerWithTimeInterval:target:selector:userInfo:repeats:), @selector(overrideTimerWithTimeInterval:target:selector:userInfo:repeats:));
}

+ (void)reset {
    NSTimerOverrider.shouldScheduleTimers = true;
    NSTimerOverrider.hasScheduledTimer = false;
    NSTimerOverrider.mostRecentTimerInterval = 0.0f;
}

+(NSTimeInterval)mostRecentTimerInterval {
    return _mostRecentTimerInterval;
}

+(void)setMostRecentTimerInterval:(NSTimeInterval)mostRecentTimerInterval {
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

@end
