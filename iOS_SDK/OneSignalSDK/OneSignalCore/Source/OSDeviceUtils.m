/*
 Modified MIT License

 Copyright 2022 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <sys/utsname.h>
#import <UIKit/UIKit.h>
#import "OSMacros.h"
#import "OSDeviceUtils.h"

@implementation OSDeviceUtils

+ (NSString *)getCurrentDeviceVersion {
    return [[UIDevice currentDevice] systemVersion];
}
 
+ (BOOL)isIOSVersionGreaterThanOrEqual:(NSString *)version {
    return [[self getCurrentDeviceVersion] compare:version options:NSNumericSearch] != NSOrderedAscending;
}

+ (BOOL)isIOSVersionLessThan:(NSString *)version {
    return [[self getCurrentDeviceVersion] compare:version options:NSNumericSearch] == NSOrderedAscending;
}

+ (NSString*)getSystemInfoMachine {
    // e.g. @"x86_64" or @"iPhone9,3"
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine
                                         encoding:NSUTF8StringEncoding];
}

// This will get real device model if it is a real iOS device (Example iPhone8,2)
// If an iOS Simulator it will return "Simulator iPhone" or "Simulator iPad"
// If a macOS Catalyst app, return "Mac"
+ (NSString*)getDeviceVariant {
    let systemInfoMachine = [self getSystemInfoMachine];

    // x86_64 could mean an iOS Simulator or Catalyst app on macOS
    #if TARGET_OS_MACCATALYST
        return @"Mac";
    #elif TARGET_OS_SIMULATOR
        let model = UIDevice.currentDevice.model;
        if (model) {
            return [@"Simulator " stringByAppendingString:model];
        } else {
            return @"Simulator";
        }
    #endif
    return systemInfoMachine;
}

@end
