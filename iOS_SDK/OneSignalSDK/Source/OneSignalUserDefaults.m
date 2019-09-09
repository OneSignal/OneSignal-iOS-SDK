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

#import <Foundation/Foundation.h>
#import "OneSignalUserDefaults.h"
#import "OneSignalExtensionBadgeHandler.h"

@implementation OneSignalUserDefaults : NSObject

+ (OneSignalUserDefaults * _Nonnull)initStandard {
    OneSignalUserDefaults *instance = [OneSignalUserDefaults new];
    instance.userDefaults = [instance getStandardUserDefault];
    return instance;
}

+ (OneSignalUserDefaults * _Nonnull)initShared {
    OneSignalUserDefaults *instance = [OneSignalUserDefaults new];
    instance.userDefaults = [instance getSharedUserDefault];
    return instance;
}

- (NSString * _Nonnull)appGroupKey {
    return [OneSignalExtensionBadgeHandler appGroupName];
}

- (NSUserDefaults* _Nonnull)getStandardUserDefault {
    return NSUserDefaults.standardUserDefaults;
}

- (NSUserDefaults* _Nonnull)getSharedUserDefault {
    return [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
}

- (BOOL)keyExists:(NSString * _Nonnull)key withUserDefaults:(NSUserDefaults * _Nonnull)userDefaults {
    return [userDefaults objectForKey:key] != nil;
}

- (BOOL)getSavedBool:(NSString * _Nonnull)key defaultValue:(BOOL)value {
    if ([self keyExists:key withUserDefaults:self.userDefaults])
        return (BOOL) [self.userDefaults boolForKey:key];
    
    return value;
}

- (void)saveBoolForKey:(NSString * _Nonnull)key withValue:(BOOL)value {
    [self.userDefaults setBool:value forKey:key];
    [self.userDefaults synchronize];
}

- (NSString * _Nullable)getSavedString:(NSString * _Nonnull)key defaultValue:(NSString * _Nullable)value {
    if ([self keyExists:key withUserDefaults:self.userDefaults])
        return [self.userDefaults stringForKey:key];
    
    return value;
}

- (void)saveStringForKey:(NSString * _Nonnull)key withValue:(NSString * _Nullable)value {
    [self.userDefaults setObject:value forKey:key];
    [self.userDefaults synchronize];
}

- (NSInteger)getSavedInteger:(NSString * _Nonnull)key defaultValue:(NSInteger)value {
    if ([self keyExists:key withUserDefaults:self.userDefaults])
        return [self.userDefaults integerForKey:key];
        
    return value;
}

- (void)saveIntegerForKey:(NSString * _Nonnull)key withValue:(NSInteger)value {
    [self.userDefaults setInteger:value forKey:key];
    [self.userDefaults synchronize];
}

- (double)getSavedDouble:(NSString * _Nonnull)key defaultValue:(double)value {
    if ([self keyExists:key withUserDefaults:self.userDefaults])
        return [self.userDefaults doubleForKey:key];
    
    return value;
}

- (void)saveDoubleForKey:(NSString * _Nonnull)key withValue:(double)value {
    [self.userDefaults setDouble:value forKey:key];
    [self.userDefaults synchronize];
}

- (NSSet * _Nullable)getSavedSet:(NSString * _Nonnull)key defaultValue:(NSSet * _Nullable)value {
    if ([self keyExists:key withUserDefaults:self.userDefaults])
        return [NSSet setWithArray:[self.userDefaults arrayForKey:key]];
    
    return value;
}

- (void)saveSetForKey:(NSString * _Nonnull)key withValue:(NSSet * _Nullable)value {
    [self.userDefaults setObject:[value allObjects] forKey:key];
    [self.userDefaults synchronize];
}

- (id _Nullable)getSavedObject:(NSString *)key defaultValue:(id _Nullable)value {
    if ([self keyExists:key withUserDefaults:self.userDefaults])
        return [self.userDefaults objectForKey:key];
    
    return value;
}

- (void)saveObjectForKey:(NSString * _Nonnull)key withValue:(id _Nullable)object {
    [self.userDefaults setObject:object forKey:key];
    [self.userDefaults synchronize];
}

- (id _Nullable)getSavedCodeableData:(NSString * _Nonnull)key defaultValue:(id _Nullable)value {
    if ([self keyExists:key withUserDefaults:self.userDefaults])
        return [NSKeyedUnarchiver unarchiveObjectWithData:[self.userDefaults objectForKey:key]];
    
    return value;
}

- (void)saveCodeableDataForKey:(NSString * _Nonnull)key withValue:(id _Nullable)value {
    [self.userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:value] forKey:key];
    [self.userDefaults synchronize];
}

@end

@implementation OneSignalSharedUserDefaults : NSObject

+ (NSUserDefaults*)getSharedUserDefault {
    return [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
}

+ (BOOL)keyExists:(NSString *)key {
    return [[OneSignalSharedUserDefaults getSharedUserDefault] objectForKey:key] != nil;
}

+ (void)saveString:(NSString *)value withKey:(NSString *)key {
    NSUserDefaults *userDefaultsShared = [OneSignalSharedUserDefaults getSharedUserDefault];
    [userDefaultsShared setObject:value forKey:key];
    [userDefaultsShared synchronize];
}

+ (NSString *)getSavedString:(NSString *)key defaultValue:(NSString *)value {
    // If the key exists in NSUserDefaults return the set
    if ([OneSignalSharedUserDefaults keyExists:key])
        return [[OneSignalSharedUserDefaults getSharedUserDefault] objectForKey:key];
    
    // Return default boolean passed in if no boolean for key exists
    return value;
}

+ (void)saveBool:(BOOL)boolean withKey:(NSString *)key {
    NSUserDefaults *userDefaultsShared = [OneSignalSharedUserDefaults getSharedUserDefault];
    [userDefaultsShared setBool:boolean forKey:key];
    [userDefaultsShared synchronize];
}

+ (BOOL)getSavedBool:(NSString *)key defaultValue:(BOOL)boolean {
    // If the key exists in NSUserDefaults return the set
    if ([OneSignalSharedUserDefaults keyExists:key])
        return (BOOL) [[OneSignalSharedUserDefaults getSharedUserDefault] boolForKey:key];
    
    // Return default boolean passed in if no boolean for key exists
    return boolean;
}

+ (NSString *)appGroupKey {
    return [OneSignalExtensionBadgeHandler appGroupName];
}

@end
