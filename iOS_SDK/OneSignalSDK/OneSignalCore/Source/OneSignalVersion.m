/**
 * Modified MIT License
 *
 * Copyright 2025 OneSignal
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

#import "OneSignalVersion.h"

/**
 * The SDK version - these values are updated by the automation when releasing
 * SEMANTIC: "5.2.15" or "5.2.3-beta-01"
 * NUMERIC: "050215" or "050203-beta-01" (zero-padded with optional suffix)
 */
static NSString * const ONESIGNAL_VERSION_SEMANTIC = @"1.1.1-alpha-01";
static NSString * const ONESIGNAL_VERSION_NUMERIC = @"010101-alpha-01";

@implementation OneSignalVersion

+ (NSString *)semantic {
    return ONESIGNAL_VERSION_SEMANTIC;
}

+ (NSString *)numeric {
    return ONESIGNAL_VERSION_NUMERIC;
}

@end
