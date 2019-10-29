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
#import "OneSignalUserDefaults.h"

@implementation OneSignalUserDefaults : NSObject

/*
 Method for checking if a key exists in NSUserDefaults
 */
+ (BOOL)keyExists:(NSString *)key {
    // Check if the object for a key is nil or not
    return [NSUserDefaults.standardUserDefaults objectForKey:key] != nil;
}

/*
 Save a set in NSUserDefaults with a key
*/
+ (void)saveObject:(id)object withKey:(NSString *)key {
    [NSUserDefaults.standardUserDefaults setObject:object forKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

/*
 Get an object from NSUserDefaults with a key
*/
+ (id)getSavedObject:(NSString *)key defaultValue:(id)object {
    // If the key exists in NSUserDefaults return the object
    if ([OneSignalUserDefaults keyExists:key])
        return [NSUserDefaults.standardUserDefaults objectForKey:key];
    
    // Return default boolean passed in if no boolean for key exists
    return object;
}

/*
 Save a set in NSUserDefaults with a key
 */
+ (void)saveBool:(BOOL)boolean withKey:(NSString *)key {
    [NSUserDefaults.standardUserDefaults setBool:boolean forKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

/*
 Get a set from NSUserDefaults with a key
 */
+ (BOOL)getSavedBool:(NSString *)key default:(BOOL)boolean {
    // If the key exists in NSUserDefaults return the set
    if ([OneSignalUserDefaults keyExists:key])
        return (BOOL) [NSUserDefaults.standardUserDefaults boolForKey:key];
    
    // Return default boolean passed in if no boolean for key exists
    return boolean;
}

+ (void)saveDouble:(double)value withKey:(NSString *)key {
    [NSUserDefaults.standardUserDefaults setDouble:value forKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

+ (double)getSavedDouble:(NSString *)key default:(double)value {
    if ([OneSignalUserDefaults keyExists:key])
        return (BOOL) [NSUserDefaults.standardUserDefaults doubleForKey:key];
    
    // Return default boolean passed in if no boolean for key exists
    return value;
}

/*
 Save a set in NSUserDefaults with a key
 */
+ (void)saveSet:(NSSet *)set withKey:(NSString *)key {
    [NSUserDefaults.standardUserDefaults setObject:[set allObjects] forKey:key];
    [NSUserDefaults.standardUserDefaults synchronize];
}

/*
 Get a set from NSUserDefaults with a key
 */
+ (NSSet *)getSavedSet:(NSString *)key {
    // If the key exists in NSUserDefaults return the set
    if ([OneSignalUserDefaults keyExists:key])
        return [NSSet setWithArray:[NSUserDefaults.standardUserDefaults arrayForKey:key]];
    
    // Return new empty set if no set for key exists
    return [NSSet new];
}

@end
