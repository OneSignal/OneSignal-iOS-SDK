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

#import "NSBundleOverrider.h"

#import "OneSignalSelectorHelpers.h"

@implementation NSBundleOverrider

static NSDictionary* nsbundleDictionary;

+ (void)load {
    injectToProperClass(@selector(overrideBundleIdentifier), @selector(bundleIdentifier), @[], [NSBundleOverrider class], [NSBundle class]);
    
    injectToProperClass(@selector(overrideObjectForInfoDictionaryKey:), @selector(objectForInfoDictionaryKey:), @[], [NSBundleOverrider class], [NSBundle class]);
    injectToProperClass(@selector(overrideURLForResource:withExtension:), @selector(URLForResource:withExtension:), @[], [NSBundleOverrider class], [NSBundle class]);
    
    // Doesn't work to swizzle for mocking. Both an NSDictionary and NSMutableDictionarys both throw odd selecotor not found errors.
    // injectToProperClass(@selector(overrideInfoDictionary), @selector(infoDictionary), @[], [NSBundleOverrider class], [NSBundle class]);
}

+(void) setNsbundleDictionary:(NSDictionary*)value {
    nsbundleDictionary = value;
}

+(NSDictionary*) nsbundleDictionary {
    return nsbundleDictionary;
}

- (NSString*)overrideBundleIdentifier {
    return @"com.onesignal.unittest";
}

- (nullable id)overrideObjectForInfoDictionaryKey:(NSString*)key {
    return nsbundleDictionary[key];
}

- (NSURL*)overrideURLForResource:(NSString*)name withExtension:(NSString*)ext {
    NSString *content = @"File Contents";
    NSData *fileContents = [content dataUsingEncoding:NSUTF8StringEncoding];
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* nameWithExt = [name stringByAppendingString:[@"." stringByAppendingString:ext]];
    NSString* fullpath = [paths[0] stringByAppendingPathComponent:nameWithExt];
    
    [[NSFileManager defaultManager] createFileAtPath:fullpath
                                            contents:fileContents
                                          attributes:nil];
    
    NSLog(@"fullpath: %@", fullpath);
    return [NSURL URLWithString:[@"file://" stringByAppendingString:fullpath]];
}

@end
