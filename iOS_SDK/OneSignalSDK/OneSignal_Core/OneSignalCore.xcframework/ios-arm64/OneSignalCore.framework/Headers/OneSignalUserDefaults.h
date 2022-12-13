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

@interface OneSignalUserDefaults : NSObject

@property (strong, nonatomic, nullable) NSUserDefaults *userDefaults;

+ (OneSignalUserDefaults * _Nonnull)initStandard;
+ (OneSignalUserDefaults * _Nonnull)initShared;

+ (NSString * _Nonnull)appGroupName;

- (BOOL)keyExists:(NSString * _Nonnull)key;

- (void)removeValueForKey:(NSString * _Nonnull)key;

// NSUserDefaults for storing and getting booleans
- (BOOL)getSavedBoolForKey:(NSString * _Nonnull)key defaultValue:(BOOL)value;
- (void)saveBoolForKey:(NSString * _Nonnull)key withValue:(BOOL)value;

// NSUserDefaults for storing and getting strings
- (NSString * _Nullable)getSavedStringForKey:(NSString * _Nonnull)key defaultValue:(NSString * _Nullable)value;
- (void)saveStringForKey:(NSString * _Nonnull)key withValue:(NSString * _Nullable)value;

// NSUserDefaults for storing and getting integers
- (NSInteger)getSavedIntegerForKey:(NSString * _Nonnull)key defaultValue:(NSInteger)value;
- (void)saveIntegerForKey:(NSString * _Nonnull)key withValue:(NSInteger)value;

// NSUserDefaults for storing and getting doubles
- (double)getSavedDoubleForKey:(NSString * _Nonnull)key defaultValue:(double)value;
- (void)saveDoubleForKey:(NSString * _Nonnull)key withValue:(double)value;

// NSUserDefaults for storing and getting sets
- (NSSet * _Nullable)getSavedSetForKey:(NSString * _Nonnull)key defaultValue:(NSSet * _Nullable)value;
- (void)saveSetForKey:(NSString * _Nonnull)key withValue:(NSSet * _Nullable)value;

// NSUserDefaults for storing and getting dictionaries
- (NSDictionary * _Nullable)getSavedDictionaryForKey:(NSString * _Nonnull)key defaultValue:(NSDictionary * _Nullable)value;
- (void)saveDictionaryForKey:(NSString * _Nonnull)key withValue:(NSDictionary * _Nullable)value;

// NSUserDefaults for storing and getting objects
- (id _Nullable)getSavedObjectForKey:(NSString * _Nonnull)key defaultValue:(id _Nullable)value;
- (void)saveObjectForKey:(NSString * _Nonnull)key withValue:(id _Nullable)value;

// NSUserDefaults for storing and getting saved codeable data (custom objects)
- (id _Nullable)getSavedCodeableDataForKey:(NSString * _Nonnull)key defaultValue:(id _Nullable)value;
- (void)saveCodeableDataForKey:(NSString * _Nonnull)key withValue:(id _Nullable)value;

@end
