/**
 * Modified MIT License
 *
 * Copyright 2021 OneSignal
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

typedef NS_ENUM(NSUInteger, ONE_S_LOG_LEVEL) {
    ONE_S_LL_NONE,
    ONE_S_LL_FATAL,
    ONE_S_LL_ERROR,
    ONE_S_LL_WARN,
    ONE_S_LL_INFO,
    ONE_S_LL_DEBUG,
    ONE_S_LL_VERBOSE
};

@interface OneSignalLogEvent : NSObject
@property(readonly)ONE_S_LOG_LEVEL level;
@property(readonly, nonnull)NSString *entry;
@end

@protocol OSLogListener <NSObject>
- (void)onLogEvent:(OneSignalLogEvent *_Nonnull)event;
@end

@protocol OSDebug <NSObject>
/**
 The log level the OneSignal SDK should be writing to the Xcode log. Defaults to [LogLevel.WARN].
 
 WARNING: This should not be set higher than LogLevel.WARN in a production setting.
 */
+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel;
/**
 The log level the OneSignal SDK should be showing as a modal. Defaults to [LogLevel.NONE].
 
 WARNING: This should not be used in a production setting.
 */
+ (void)setAlertLevel:(ONE_S_LOG_LEVEL)logLevel NS_REFINED_FOR_SWIFT;
/**
 Add a listener to receive all logging messages the SDK produces.
 Useful to capture and send logs to your server.
 
 NOTE: All log messages are always passed, LogLevel has no effect on this.
 */
+ (void)addLogListener:(NSObject<OSLogListener>*_Nonnull)listener NS_REFINED_FOR_SWIFT;
/**
 Removes a listener added by addLogListener
 */
+ (void)removeLogListener:(NSObject<OSLogListener>*_Nonnull)listener NS_REFINED_FOR_SWIFT;

@end

@interface OneSignalLog : NSObject<OSDebug>
+ (Class<OSDebug>)Debug;
+ (void)onesignalLog:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message;
+ (ONE_S_LOG_LEVEL)getLogLevel;
@end
