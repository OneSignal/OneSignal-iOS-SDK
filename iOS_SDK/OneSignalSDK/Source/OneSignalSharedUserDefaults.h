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

@interface OneSignalSharedUserDefaults : NSObject

+ (NSUserDefaults*)getSharedUserDefault;
+ (BOOL)keyExists:(NSString *)key;

+ (void)saveString:(NSString *)value withKey:(NSString *)key;
+ (NSString *)getSavedString:(NSString *)key defaultValue:(NSString *)value;
+ (void)saveBool:(BOOL)boolean withKey:(NSString *)key;
+ (BOOL)getSavedBool:(NSString *)key defaultValue:(BOOL)value;
+ (void)saveInteger:(NSInteger)integer withKey:(NSString *)key;
+ (NSInteger)getSavedInteger:(NSString *)key defaultValue:(NSInteger)value;
+ (void)saveCodeableData:(id)data withKey:(NSString *)key;
+ (nullable id)getSavedCodeableData:(NSString *)key;
+ (void)saveObject:(id)object withKey:(NSString *)key;
+ (nullable id)getSavedObject:(NSString *)key defaultValue:(id)value;

@end
