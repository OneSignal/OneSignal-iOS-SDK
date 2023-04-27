/*
 Modified MIT License

 Copyright 2022 OneSignal

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

#import "OneSignalInAppMessaging.h"
#import "OSMessagingController.h"

@implementation OneSignalInAppMessaging

+ (Class<OSInAppMessages>)InAppMessages {
    return self;
}

+ (void)start {
    // Initialize the shared instance and start observing the push subscription
    [OSMessagingController start];
}

+ (void)setClickHandler:(OSInAppMessageClickBlock)block {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"In app message click handler set successfully"];
    [OSMessagingController.sharedInstance setInAppMessageClickHandler:block];
}

+ (void)addLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> *_Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"In app message lifecycle listener added successfully"];
    [OSMessagingController.sharedInstance setInAppMessageDelegate:listener];
}

+ (void)removeLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> *_Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"In app message lifecycle listener removed successfully"];
    [OSMessagingController.sharedInstance removeInAppMessageDelegate:listener];
}

+ (void)addTrigger:(NSString * _Nonnull)key withValue:(NSString * _Nonnull)value {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"addTrigger:withValue:"])
        return;

    if (!key) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Attempted to set a trigger with a nil key."];
        return;
    }

    [OSMessagingController.sharedInstance addTriggers:@{key : value}];
}

+ (void)addTriggers:(NSDictionary<NSString *, NSString *> * _Nonnull)triggers {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"addTriggers:"])
        return;

    [OSMessagingController.sharedInstance addTriggers:triggers];
}

+ (void)removeTrigger:(NSString * _Nonnull)key {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"removeTriggerForKey:"])
        return;

    if (!key) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Attempted to remove a trigger with a nil key."];
        return;
    }

    [OSMessagingController.sharedInstance removeTriggersForKeys:@[key]];
}

+ (void)removeTriggers:(NSArray<NSString *> * _Nonnull)keys {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"removeTriggerForKey:"])
        return;

    [OSMessagingController.sharedInstance removeTriggersForKeys:keys];
}

+ (void)clearTriggers {
    // return if the user has not granted privacy permissions
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"clearTriggers:"])
        return;
    
    [OSMessagingController.sharedInstance clearTriggers];
}

+ (void)paused:(BOOL)pause {
    [OSMessagingController.sharedInstance setInAppMessagingPaused:pause];
}

+ (BOOL)paused {
    return [OSMessagingController.sharedInstance isInAppMessagingPaused];
}

@end
