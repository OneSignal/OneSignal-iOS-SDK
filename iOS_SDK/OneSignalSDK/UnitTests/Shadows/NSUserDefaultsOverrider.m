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

#import "NSUserDefaultsOverrider.h"
#import "OneSignalSelectorHelpers.h"

static NSMutableDictionary* defaultsDictionary;

@implementation NSUserDefaultsOverrider
+ (void)load {
    defaultsDictionary = [[NSMutableDictionary alloc] init];
    
    // Sets
    injectToProperClass(@selector(overrideSetObject:forKey:), @selector(setObject:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetString:forKey:), @selector(setString:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetInteger:forKey:), @selector(setInteger:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetDouble:forKey:), @selector(setDouble:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideSetBool:forKey:), @selector(setBool:forKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    
    // Gets
    injectToProperClass(@selector(overrideObjectForKey:), @selector(objectForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideStringForKey:), @selector(stringForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideIntegerForKey:), @selector(integerForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideDoubleForKey:), @selector(doubleForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(overrideBoolForKey:), @selector(boolForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
}

+ (void)clearInternalDictionary {
    defaultsDictionary = [[NSMutableDictionary alloc] init];
}

// Sets
-(void)overrideSetObject:(id)value forKey:(NSString*)key {
    defaultsDictionary[key] = value;
}

-(void)overrideSetString:(NSString*)value forKey:(NSString*)key {
    defaultsDictionary[key] = value;
}

- (void)overrideSetDouble:(double)value forKey:(NSString*)key {
    defaultsDictionary[key] = [NSNumber numberWithDouble:value];
}

- (void)overrideSetBool:(BOOL)value forKey:(NSString*)key {
    defaultsDictionary[key] = [NSNumber numberWithBool:value];
}

- (void)overrideSetInteger:(NSInteger)value forKey:(NSString*)key {
    defaultsDictionary[key] = [NSNumber numberWithInteger:value];
}

// Gets
- (nullable id)overrideObjectForKey:(NSString*)key {
    if ([key isEqualToString:@"XCTIDEConnectionTimeout"])
        return [NSNumber numberWithInt:60];
    
    return defaultsDictionary[key];
}

- (NSString*)overrideStringForKey:(NSString*)key {
    return defaultsDictionary[key];
}

- (NSInteger)overrideIntegerForKey:(NSString*)key {
    if ([key isEqualToString:@"XCTIDEConnectionTimeout"])
        return 60.0;
    
    return [defaultsDictionary[key] integerValue];
}

- (double)overrideDoubleForKey:(NSString*)key {
    if ([key isEqualToString:@"XCTIDEConnectionTimeout"])
        return 60.0;
    
    return [defaultsDictionary[key] doubleValue];
}

- (BOOL)overrideBoolForKey:(NSString*)key {
    return [defaultsDictionary[key] boolValue];
}

@end

