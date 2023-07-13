/*
 Modified MIT License

 Copyright 2023 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "OSInAppMessages.h"
#import "OneSignalLog.h"

@implementation OSStubInAppMessages

+ (Class<OSInAppMessages>)InAppMessages {
    return self;
}

+ (void)addClickListener:(NSObject<OSInAppMessageClickListener> * _Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)addLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> * _Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)addTrigger:(NSString * _Nonnull)key withValue:(NSString * _Nonnull)value {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)addTriggers:(NSDictionary<NSString *,NSString *> * _Nonnull)triggers {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)clearTriggers {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (BOOL)paused {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
    return true;
}

+ (void)paused:(BOOL)pause {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)removeClickListener:(NSObject<OSInAppMessageClickListener> * _Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)removeLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> * _Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)removeTrigger:(NSString * _Nonnull)key {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)removeTriggers:(NSArray<NSString *> * _Nonnull)keys {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

@end
