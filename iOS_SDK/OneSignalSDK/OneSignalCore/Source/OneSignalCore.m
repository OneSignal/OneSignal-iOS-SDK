/**
 * Modified MIT License
 *
 * Copyright 2024 OneSignal
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

#import <Foundation/Foundation.h>
#import "OneSignalCore.h"

@implementation OneSignalCoreImpl

+ (void)migrate {
    [self migrateCachedSdkVersion];
    [self saveCurrentSDKVersion];
}

/// Every module should be responsible for its own migration, as it is possible for one module
/// to finish migrating without another undergoing migration yet.
/// See https://github.com/OneSignal/OneSignal-iOS-SDK/pull/1541
+ (void)migrateCachedSdkVersion {
    if (![OneSignalUserDefaults.initShared keyExists:OSUD_LEGACY_CACHED_SDK_VERSION_FOR_MIGRATION]) {
        return;
    }
    
    // The default value should never be used, however the getSavedIntegerForKey method requires it
    long sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_LEGACY_CACHED_SDK_VERSION_FOR_MIGRATION defaultValue:0];
    [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"OneSignalCoreImpl migrating cached SDK versions from version: %ld", sdkVersion]];

    [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_CACHED_SDK_VERSION_FOR_CORE withValue:sdkVersion];
    [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_CACHED_SDK_VERSION_FOR_OUTCOMES withValue:sdkVersion];
    [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_CACHED_SDK_VERSION_FOR_IAM withValue:sdkVersion];
    [OneSignalUserDefaults.initShared removeValueForKey:OSUD_LEGACY_CACHED_SDK_VERSION_FOR_MIGRATION];
}

+ (void)saveCurrentSDKVersion {
    int currentVersion = [ONESIGNAL_VERSION intValue];
    [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_CACHED_SDK_VERSION_FOR_CORE withValue:currentVersion];
}

static id<IOneSignalClient> _sharedClient;
+ (id<IOneSignalClient>)sharedClient {
    if (!_sharedClient) {
        // If tests didn't set their own client, we will default to this
        return OneSignalClient.sharedClient;
    }
    return _sharedClient;
}

+ (void)setSharedClient:(id<IOneSignalClient>)client {
    _sharedClient = client;
}

@end
