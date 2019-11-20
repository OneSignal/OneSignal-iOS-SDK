/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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

#import "NSDateOverrider.h"

#import "OneSignalSelectorHelpers.h"
#import "TestHelperFunctions.h"

/*
 NSDate category + swizzling allows freezing of time for all tests.
 This is done by intercepting any creations of NSData and setting it to globalTimeOffset.
 TODO: Does NOT support all ways of newing up a NSDate.
          - Add them as needed.
*/

@implementation NSDate (Testing)

+ (NSDate*) overrideDate {
    return [NSDate overrideDateWithTimeIntervalSince1970:NSDateOverrider.globalTimeOffset];
}

+ (NSDate*) overrideDateWithTimeIntervalSince1970:(NSTimeInterval)secs {
    return [NSDate overrideDateWithTimeIntervalSince1970:NSDateOverrider.globalTimeOffset + secs];
}
@end


@implementation NSDateOverrider

static NSTimeInterval _globalTimeOffset;
+ (NSTimeInterval)globalTimeOffset {
    return _globalTimeOffset;
}

+ (void)load {
    swizzleClassMethodWithCategoryImplementation([NSDate class], @selector(date), @selector(overrideDate));
    swizzleClassMethodWithCategoryImplementation([NSDate class], @selector(dateWithTimeIntervalSince1970:), @selector(overrideDateWithTimeIntervalSince1970:));

    injectToProperClass(@selector(overrideTimeIntervalSinceNow), @selector(timeIntervalSinceNow), @[], [NSDateOverrider class], [NSDate class]);
}

+(void) reset {
    _globalTimeOffset = 1;
}

+(void) setTimeOffset:(NSTimeInterval)offset {
    _globalTimeOffset = offset;
}

+(void) advanceSystemTimeBy:(NSTimeInterval)sec {
    _globalTimeOffset += sec;
}

- (NSTimeInterval) overrideTimeIntervalSinceNow {
    // Ensure "now" is mocked by creating a new NSDate
    return [(NSDate*)self timeIntervalSinceDate:[NSDate date]];
}

@end
