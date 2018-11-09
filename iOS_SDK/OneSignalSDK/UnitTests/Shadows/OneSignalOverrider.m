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

#import "OneSignalOverrider.h"
#import "OSMessagingController.h"
#import "OneSignalSelectorHelpers.h"
#import "TestHelperFunctions.h"
#import "NSTimerOverrider.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

@interface OneSignal ()
+ (NSDate *)sessionLaunchTime;
@end

@implementation OneSignal (Testing)

+ (NSDate *)overrideSessionLaunchTime {
    if (OneSignalOverrider.shouldOverrideSessionLaunchTime) {
        return [NSDate date];
    } else {
        return self.overrideSessionLaunchTime;
    }
}

@end

@implementation OneSignalOverrider

static BOOL _overrideLaunchTime = false;

+(void)load {
    swizzleClassMethodWithCategoryImplementation([OneSignal class], @selector(sessionLaunchTime), @selector(overrideSessionLaunchTime));
    _overrideLaunchTime = false;
}

+(BOOL)shouldOverrideSessionLaunchTime {
    return _overrideLaunchTime;
}

+(void)setShouldOverrideSessionLaunchTime:(BOOL)shouldOverrideSessionLaunchTime {
    _overrideLaunchTime = shouldOverrideSessionLaunchTime;
}

@end

#pragma clang diagnostic pop
