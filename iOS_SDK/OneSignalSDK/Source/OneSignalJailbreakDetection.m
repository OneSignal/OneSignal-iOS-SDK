//  OneSignalJailbreakDetection.m
//
//  Copyright (c) 2014 Doan Truong Thi
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

// Renamed DTTJailbreakDetection.m to OneSignalJailbreakDetection.m to avoid conflicts with other libraries.

#import <UIKit/UIKit.h>

#import "OneSignalJailbreakDetection.h"

#import "OneSignalCommonDefines.h"

@implementation OneSignalJailbreakDetection

+ (BOOL)isJailbroken {
    
#if !(TARGET_IPHONE_SIMULATOR)
    
    // checks filesystem to see if signature
    // files present in most jailbroken installations
    // are present
    
    for (NSString *path in JAILBREAK_SIGNATURE_FILES) {
        FILE *file = fopen(path.UTF8String, "r");
        if (file) {
            fclose(file);
            return YES;
        }
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *path in JAILBREAK_SIGNATURE_FILES) {
        if ([fileManager fileExistsAtPath:path]) {
            return YES;
        }
    }
    
    // Omit logic below since they show warnings in the device log on iOS 9 devices.
    if (NSFoundationVersionNumber > 1144.17) // NSFoundationVersionNumber_iOS_8_4
        return NO;
    
    // Check if the app can access outside of its sandbox
    NSError *error = nil;
    NSString *string = @".";
    [string writeToFile:@"/private/jailbreak.txt" atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!error)
        return YES;
    else
        [fileManager removeItemAtPath:@"/private/jailbreak.txt" error:nil];
    
    // Check if the app can open a Cydia's URL scheme
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://package/com.example.package"]])
        return YES;
    
#endif
    
    return NO;
}

@end
