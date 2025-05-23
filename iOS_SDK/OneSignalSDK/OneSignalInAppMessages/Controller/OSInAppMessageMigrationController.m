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

#import "OSInAppMessageMigrationController.h"
#import "OSInAppMessagingDefines.h"
#import "OSInAppMessageInternal.h"

@implementation OSInAppMessageMigrationController

+(void)migrate {
    [self migrateIAMRedisplayCache];
    [self migrateToOSInAppMessageInternal];
    [self saveCurrentSDKVersion];
}

// Devices could potentially have bad data in the OS_IAM_REDISPLAY_DICTIONARY
// that was saved as a dictionary and not CodeableData. Try to detect if that is the case
// and save it is as CodeableData instead.
+ (void)migrateIAMRedisplayCache {
    let iamRedisplayCacheFixVersion = 30203;
    long sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION_FOR_IAM defaultValue:0];
    if (sdkVersion >= iamRedisplayCacheFixVersion)
        return;

    @try {
        __unused NSMutableDictionary *redisplayDict =[[NSMutableDictionary alloc] initWithDictionary:[OneSignalUserDefaults.initStandard
                                                        getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY
                                                        defaultValue:[NSMutableDictionary new]]];
    } @catch (NSException *exception) {
        @try {
            // The redisplay IAMs might have been saved as a dictionary.
            // Try to read them as a dictionary and then save them as a codeable.
            NSMutableDictionary *redisplayDict = [[NSMutableDictionary alloc] initWithDictionary:[OneSignalUserDefaults.initStandard
                                                                    getSavedDictionaryForKey:OS_IAM_REDISPLAY_DICTIONARY
                                                                    defaultValue:[NSMutableDictionary new]]];
            [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY
                                                                    withValue:redisplayDict];
        } @catch (NSException *exception) {
            //Clear the cached redisplay dictionary of bad data
            [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY
                                                                    withValue:nil];
        }
    }
}

// OSInAppMessage has been made public
// The old class has been renamed to OSInAppMessageInternal
// We must set the new class name to the unarchiver to avoid crashing
+ (void)migrateToOSInAppMessageInternal {
    let nameChangeVersion = 30700;
    long sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION_FOR_IAM defaultValue:0];
    [NSKeyedUnarchiver setClass:[OSInAppMessageInternal class] forClassName:@"OSInAppMessage"];
    if (sdkVersion < nameChangeVersion) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Migrating OSInAppMessage from version: %ld", sdkVersion]];

        [NSKeyedUnarchiver setClass:[OSInAppMessageInternal class] forClassName:@"OSInAppMessage"];

        // Redisplay Messages Dict
        NSMutableDictionary <NSString *, OSInAppMessageInternal *> *redisplayedInAppMessages = [[NSMutableDictionary alloc] initWithDictionary:[OneSignalUserDefaults.initStandard getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:[NSMutableDictionary new]]];
        if (redisplayedInAppMessages && redisplayedInAppMessages.count) {
            [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:redisplayedInAppMessages];
        } else {
            [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:nil];
        }
    }
}

+ (void)saveCurrentSDKVersion {
    int currentVersion = [ONESIGNAL_VERSION intValue];
    [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_CACHED_SDK_VERSION_FOR_IAM withValue:currentVersion];
}

@end
