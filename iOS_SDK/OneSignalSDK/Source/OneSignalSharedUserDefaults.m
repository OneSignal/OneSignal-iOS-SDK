/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
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
#import "OneSignalSharedUserDefaults.h"
#import "OneSignalExtensionBadgeHandler.h"

@implementation OneSignalSharedUserDefaults : NSObject

+ (NSString * _Nonnull)appGroupKey {
    return [OneSignalExtensionBadgeHandler appGroupName];
}

+ (NSUserDefaults* _Nonnull)getSharedUserDefault {
    return [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
}

+ (BOOL)keyExists:(NSUserDefaults * _Nonnull)userDefaults withKey:(NSString * _Nonnull)key {
    return [userDefaults objectForKey:key] != nil;
}

+ (BOOL)getSavedBool:(NSString * _Nonnull)key defaultValue:(BOOL)value {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    if ([self keyExists:userDefaults withKey:key])
        return (BOOL) [userDefaults boolForKey:key];
    
    return value;
}

+ (void)saveBool:(BOOL)value withKey:(NSString * _Nonnull)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setBool:value forKey:key];
    [userDefaults synchronize];
}

+ (NSString * _Nullable)getSavedString:(NSString * _Nonnull)key defaultValue:(NSString * _Nullable)value {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    if ([self keyExists:userDefaults withKey:key])
        return [userDefaults objectForKey:key];
    
    return value;
}

+ (void)saveString:(NSString * _Nullable)value withKey:(NSString * _Nonnull)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setObject:value forKey:key];
    [userDefaults synchronize];
}

+ (NSInteger)getSavedInteger:(NSString * _Nonnull)key defaultValue:(NSInteger)value {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    if ([self keyExists:userDefaults withKey:key])
        return [userDefaults integerForKey:key];
        
    return value;
}

+ (void)saveInteger:(NSInteger)value withKey:(NSString * _Nonnull)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setInteger:value forKey:key];
    [userDefaults synchronize];
}

+ (double)getSavedDouble:(NSString * _Nonnull)key defaultValue:(double)value {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    if ([self keyExists:userDefaults withKey:key])
        return [userDefaults doubleForKey:key];
    
    return value;
}

+ (void)saveDouble:(double)value withKey:(NSString * _Nonnull)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setDouble:value forKey:key];
    [userDefaults synchronize];
}

+ (NSSet * _Nullable)getSavedSet:(NSString * _Nonnull)key defaultValue:(NSSet * _Nullable)value {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    if ([self keyExists:userDefaults withKey:key])
        return [NSSet setWithArray:[userDefaults arrayForKey:key]];
    
    return value;
}

+ (void)saveSet:(NSSet * _Nullable)value withKey:(NSString * _Nonnull)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setObject:[value allObjects] forKey:key];
    [userDefaults synchronize];
}

+ (id _Nullable)getSavedObject:(NSString *)key defaultValue:(id _Nullable)value {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    if ([self keyExists:userDefaults withKey:key])
        return [userDefaults objectForKey:key];
    
    return value;
}

+ (void)saveObject:(id _Nullable)object withKey:(NSString * _Nonnull)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setObject:object forKey:key];
    [userDefaults synchronize];
}

+ (id _Nullable)getSavedCodeableData:(NSString * _Nonnull)key defaultValue:(id _Nullable)value {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    if ([self keyExists:userDefaults withKey:key])
        return [NSKeyedUnarchiver unarchiveObjectWithData:[userDefaults objectForKey:key]];
    
    return value;
}

+ (void)saveCodeableData:(id _Nullable)value withKey:(NSString * _Nonnull)key {
    NSUserDefaults *userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    
    [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:value] forKey:key];
    [userDefaults synchronize];
}

@end
