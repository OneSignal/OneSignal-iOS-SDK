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

@implementation NSUserDefaultsOverrider {
   NSString *suiteName;
}

+ (void)load {
    defaultsDictionary = [NSMutableDictionary new];
    
    // Adding helpers to NSUserDefaults to be used internally
    injectToProperClass(@selector(getObjectForKey:), @selector(getObjectForKey:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    injectToProperClass(@selector(setObjectForKey:withValue:), @selector(setObjectForKey:withValue:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    
    // initWithSuiteName overrider
    injectToProperClass(@selector(overrideInitWithSuiteName:), @selector(initWithSuiteName:), @[], [NSUserDefaultsOverrider class], [NSUserDefaults class]);
    
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
    defaultsDictionary = [NSMutableDictionary new];
}

- (nullable instancetype)overrideInitWithSuiteName:(nullable NSString *)suitename {
    suiteName = suitename;
    return [self overrideInitWithSuiteName:suitename];
}

- (void)setObjectForKey:(NSString*)key withValue:(id)value {
    if (!suiteName)
        suiteName = @"default";
    
    if (!defaultsDictionary[suiteName])
        defaultsDictionary[suiteName] = [NSMutableDictionary new];
    
    defaultsDictionary[suiteName][key] = value;
}

// Sets
-(void)overrideSetObject:(id)value forKey:(NSString*)key {
    [self setObjectForKey:key withValue:value];
}

-(void)overrideSetString:(NSString*)value forKey:(NSString*)key {
   [self setObjectForKey:key withValue:value];
}

- (void)overrideSetDouble:(double)value forKey:(NSString*)key {
    [self setObjectForKey:key withValue:[NSNumber numberWithDouble:value]];
}

- (void)overrideSetBool:(BOOL)value forKey:(NSString*)key {
    [self setObjectForKey:key withValue:[NSNumber numberWithBool:value]];
}

- (void)overrideSetInteger:(NSInteger)value forKey:(NSString*)key {
    [self setObjectForKey:key withValue:[NSNumber numberWithInteger:value]];
}

- (id)getObjectForKey:(NSString*)key {
    if (!suiteName)
        suiteName = @"default";
    
    if (!defaultsDictionary[suiteName])
        defaultsDictionary[suiteName] = [NSMutableDictionary new];
    
    return defaultsDictionary[suiteName][key];
}

// Gets
- (nullable id)overrideObjectForKey:(NSString*)key {
    if ([key isEqualToString:@"XCTIDEConnectionTimeout"])
        return [NSNumber numberWithInt:60];
    
    return [self getObjectForKey:key];
}

- (NSString*)overrideStringForKey:(NSString*)key {
    return [self getObjectForKey:key];
}

- (NSInteger)overrideIntegerForKey:(NSString*)key {
    if ([key isEqualToString:@"XCTIDEConnectionTimeout"])
        return 60.0;
    
    return [[self getObjectForKey:key] integerValue];
}

- (double)overrideDoubleForKey:(NSString*)key {
    if ([key isEqualToString:@"XCTIDEConnectionTimeout"])
        return 60.0;
    
    return [[self getObjectForKey:key] doubleValue];
}

- (BOOL)overrideBoolForKey:(NSString*)key {
    return [[self getObjectForKey:key] boolValue];
}

@end
