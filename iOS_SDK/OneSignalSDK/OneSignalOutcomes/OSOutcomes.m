/*
 Modified MIT License

 Copyright 2021 OneSignal

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
#import "OneSignalOutcomes.h"
#import <OneSignalCore/OneSignalCore.h>

@implementation OSOutcomes

+ (Class<OSSession>)Session {
    return self;
}

static OneSignalOutcomeEventsController *_sharedController;
+ (OneSignalOutcomeEventsController *)sharedController {
    return _sharedController;
}

+ (void)start {
    _sharedController = [[OneSignalOutcomeEventsController alloc]
                         initWithSessionManager:[OSSessionManager sharedSessionManager]
                         outcomeEventsFactory:[[OSOutcomeEventsFactory alloc]
                                               initWithCache:[OSOutcomeEventsCache sharedOutcomeEventsCache]]];
}

+ (void)clearStatics {
    _sharedController = nil;
}

+ (void)migrate {
    [self migrateToVersion_02_14_00_AndGreater];
    [self saveCurrentSDKVersion];
}

/**
 * Support renaming of decodable classes for cached data
 */
+ (void)migrateToVersion_02_14_00_AndGreater {
    let influenceVersion = 21400;
    let uniqueCacheOutcomeVersion = 21403;
    long sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    if (sdkVersion < influenceVersion) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Migrating OSIndirectNotification from version: %ld", sdkVersion]];

        [NSKeyedUnarchiver setClass:[OSIndirectInfluence class] forClassName:@"OSIndirectNotification"];
        NSArray<OSIndirectInfluence *> * indirectInfluenceData = [[OSInfluenceDataRepository sharedInfluenceDataRepository] lastNotificationsReceivedData];
        if (indirectInfluenceData) {
            [NSKeyedArchiver setClassName:@"OSIndirectInfluence" forClass:[OSIndirectInfluence class]];
            [[OSInfluenceDataRepository sharedInfluenceDataRepository] saveNotifications:indirectInfluenceData];
        }
    }
    
    if (sdkVersion < uniqueCacheOutcomeVersion) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Migrating OSUniqueOutcomeNotification from version: %ld", sdkVersion]];
        
        [NSKeyedUnarchiver setClass:[OSCachedUniqueOutcome class] forClassName:@"OSUniqueOutcomeNotification"];
        NSArray<OSCachedUniqueOutcome *> * attributedCacheUniqueOutcomeEvents = [[OSOutcomeEventsCache sharedOutcomeEventsCache] getAttributedUniqueOutcomeEventSent];
        if (attributedCacheUniqueOutcomeEvents) {
            [NSKeyedArchiver setClassName:@"OSCachedUniqueOutcome" forClass:[OSCachedUniqueOutcome class]];
            [[OSOutcomeEventsCache sharedOutcomeEventsCache] saveAttributedUniqueOutcomeEventNotificationIds:attributedCacheUniqueOutcomeEvents];
        }
    }
}
+ (void)saveCurrentSDKVersion {
    let currentVersion = [ONESIGNAL_VERSION intValue];
    [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_CACHED_SDK_VERSION withValue:currentVersion];
}

#pragma mark Session namespace

+ (void)addOutcome:(NSString * _Nonnull)name {
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"addOutcome"]) {
        return;
    }
    if (!_sharedController) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Attempted to call OneSignal.Session before init. Make sure OneSignal init is called first."];
        return;
    }
    
    [_sharedController addOutcome:name];
}

+ (void)addOutcomeWithValue:(NSString * _Nonnull)name value:(NSNumber * _Nonnull)value {
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"addOutcomeWithValue"]) {
        return;
    }
    if (!_sharedController) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Attempted to call OneSignal.Session before init. Make sure OneSignal init is called first."];
        return;
    }
    
    [_sharedController addOutcomeWithValue:name value:value];
}

+ (void)addUniqueOutcome:(NSString * _Nonnull)name {
    if ([OSPrivacyConsentController shouldLogMissingPrivacyConsentErrorWithMethodName:@"addUniqueOutcome"]) {
        return;
    }
    if (!_sharedController) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Attempted to call OneSignal.Session before init. Make sure OneSignal init is called first."];
        return;
    }
    
    [_sharedController addUniqueOutcome:name];
}

@end
