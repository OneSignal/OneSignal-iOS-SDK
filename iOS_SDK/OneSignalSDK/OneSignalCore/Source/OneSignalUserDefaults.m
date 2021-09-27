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
#import "OneSignalCommonDefines.h"

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

- (NSUserDefaults* _Nonnull)getStandardUserDefault {
    return NSUserDefaults.standardUserDefaults;
}

- (NSUserDefaults* _Nonnull)getSharedUserDefault {
    return [[NSUserDefaults alloc] initWithSuiteName:[self appGroupKey]];
}

- (NSString * _Nonnull)appGroupKey {
    return [OneSignalUserDefaults appGroupName];
}

- (BOOL)keyExists:(NSString * _Nonnull)key {
    return [self.userDefaults objectForKey:key] != nil;
}

- (void)removeValueForKey:(NSString * _Nonnull)key {
    [self.userDefaults removeObjectForKey:key];
    [self.userDefaults synchronize];
}

- (BOOL)getSavedBoolForKey:(NSString * _Nonnull)key defaultValue:(BOOL)value {
    if ([self keyExists:key])
        return (BOOL) [self.userDefaults boolForKey:key];
    
    return value;
}

- (void)saveBoolForKey:(NSString * _Nonnull)key withValue:(BOOL)value {
    [self.userDefaults setBool:value forKey:key];
    [self.userDefaults synchronize];
}

- (NSString * _Nullable)getSavedStringForKey:(NSString * _Nonnull)key defaultValue:(NSString * _Nullable)value {
    if ([self keyExists:key])
        return [self.userDefaults stringForKey:key];
    
    return value;
}

- (void)saveStringForKey:(NSString * _Nonnull)key withValue:(NSString * _Nullable)value {
    [self.userDefaults setObject:value forKey:key];
    [self.userDefaults synchronize];
}

// NOTE: NSInteger because NSUserDefaults returns NSInteger when using integerForKey method
- (NSInteger)getSavedIntegerForKey:(NSString * _Nonnull)key defaultValue:(NSInteger)value {
    if ([self keyExists:key])
        return [self.userDefaults integerForKey:key];
        
    return value;
}

- (void)saveIntegerForKey:(NSString * _Nonnull)key withValue:(NSInteger)value {
    [self.userDefaults setInteger:value forKey:key];
    [self.userDefaults synchronize];
}

- (double)getSavedDoubleForKey:(NSString * _Nonnull)key defaultValue:(double)value {
    if ([self keyExists:key])
        return [self.userDefaults doubleForKey:key];
    
    return value;
}

- (void)saveDoubleForKey:(NSString * _Nonnull)key withValue:(double)value {
    [self.userDefaults setDouble:value forKey:key];
    [self.userDefaults synchronize];
}

- (NSSet * _Nullable)getSavedSetForKey:(NSString * _Nonnull)key defaultValue:(NSSet * _Nullable)value {
    if ([self keyExists:key])
        return [NSSet setWithArray:[self.userDefaults arrayForKey:key]];
    
    return value;
}

- (void)saveSetForKey:(NSString * _Nonnull)key withValue:(NSSet * _Nullable)value {
    [self.userDefaults setObject:[value allObjects] forKey:key];
    [self.userDefaults synchronize];
}

- (NSDictionary * _Nullable)getSavedDictionaryForKey:(NSString * _Nonnull)key defaultValue:(NSDictionary * _Nullable)value {
    if ([self keyExists:key])
        return [self.userDefaults dictionaryForKey:key];

    return value;
}

- (void)saveDictionaryForKey:(NSString * _Nonnull)key withValue:(NSSet * _Nullable)value {
    [self.userDefaults setObject:value forKey:key];
    [self.userDefaults synchronize];
}

- (id _Nullable)getSavedObjectForKey:(NSString *)key defaultValue:(id _Nullable)value {
    if ([self keyExists:key])
        return [self.userDefaults objectForKey:key];
    
    return value;
}

- (void)saveObjectForKey:(NSString * _Nonnull)key withValue:(id _Nullable)object {
    [self.userDefaults setObject:object forKey:key];
    [self.userDefaults synchronize];
}

- (id _Nullable)getSavedCodeableDataForKey:(NSString * _Nonnull)key defaultValue:(id _Nullable)value {
    if ([self keyExists:key])
        return [NSKeyedUnarchiver unarchiveObjectWithData:[self.userDefaults objectForKey:key]];
    
    return value;
}

- (void)saveCodeableDataForKey:(NSString * _Nonnull)key withValue:(id _Nullable)value {
    [self.userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:value] forKey:key];
    [self.userDefaults synchronize];
}

//gets the NSBundle of the primary application - NOT the app extension
//this way we can determine the bundle ID for the host (primary) application.
+ (NSString *)primaryBundleIdentifier {
    NSBundle *bundle = [NSBundle mainBundle];
    if ([[bundle.bundleURL pathExtension] isEqualToString:@"appex"])
        bundle = [NSBundle bundleWithURL:[[bundle.bundleURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent]];
    
    return [bundle bundleIdentifier];
    
}

+ (NSString *)appGroupName {
    NSString *appGroupName = (NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:ONESIGNAL_APP_GROUP_NAME_KEY];
    
    if (!appGroupName)
        appGroupName = [NSString stringWithFormat:@"group.%@.%@", OneSignalUserDefaults.primaryBundleIdentifier, @"onesignal"];
    
    return [appGroupName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}


@end
