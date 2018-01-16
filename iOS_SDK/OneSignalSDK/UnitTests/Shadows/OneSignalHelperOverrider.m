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

#import "OneSignalHelperOverrider.h"

#import "TestHelperFunctions.h"

#import "OneSignal.h"
#import "OneSignalHelper.h"

@implementation OneSignalHelperOverrider

static dispatch_queue_t serialMockMainLooper;

static XCTestCase* currentTestInstance;

static float mockIOSVersion;

+ (void)load {
    serialMockMainLooper = dispatch_queue_create("com.onesignal.unittest", DISPATCH_QUEUE_SERIAL);
    
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideGetAppName), [OneSignalHelper class], @selector(getAppName));
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideIsIOSVersionGreaterOrEqual:), [OneSignalHelper class], @selector(isIOSVersionGreaterOrEqual:));
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideDispatch_async_on_main_queue:), [OneSignalHelper class], @selector(dispatch_async_on_main_queue:));
}

+(void)setMockIOSVersion:(float)value {
    mockIOSVersion = value;
}
+(float)mockIOSVersion {
    return mockIOSVersion;
}

+ (NSString*) overrideGetAppName {
    return @"App Name";
}

+ (BOOL)overrideIsIOSVersionGreaterOrEqual:(float)version {
    return mockIOSVersion >= version;
}

+ (void) overrideDispatch_async_on_main_queue:(void(^)())block {
    dispatch_async(serialMockMainLooper, block);
}

+ (void)runBackgroundThreads {
    dispatch_sync(serialMockMainLooper, ^{});
}

@end
