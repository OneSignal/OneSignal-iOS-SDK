//
//  OSInAppMessageMigrationController.m
//  OneSignalInAppMessages
//
//  Created by Elliot Mawby on 6/21/23.
//  Copyright © 2023 Hiptic. All rights reserved.
//

#import "OSInAppMessageMigrationController.h"
#import "OSInAppMessagingDefines.h"
#import "OSInAppMessageInternal.h"

@implementation OSInAppMessageMigrationController

+(void)migrate {
    [self migrateIAMRedisplayCache];
    [self migrateToOSInAppMessageInternal];
}

// Devices could potentially have bad data in the OS_IAM_REDISPLAY_DICTIONARY
// that was saved as a dictionary and not CodeableData. Try to detect if that is the case
// and save it is as CodeableData instead.
+ (void)migrateIAMRedisplayCache {
    let iamRedisplayCacheFixVersion = 30203;
    long sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
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
    long sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    [NSKeyedUnarchiver setClass:[OSInAppMessageInternal class] forClassName:@"OSInAppMessage"];
    if (sdkVersion < nameChangeVersion) {
        [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Migrating OSInAppMessage from version: %ld", sdkVersion]];

        [NSKeyedUnarchiver setClass:[OSInAppMessageInternal class] forClassName:@"OSInAppMessage"];
        // Messages Array
        NSArray<OSInAppMessageInternal *> *messages = [OneSignalUserDefaults.initStandard getSavedCodeableDataForKey:OS_IAM_MESSAGES_ARRAY
                                                                                          defaultValue:[NSArray<OSInAppMessageInternal *> new]];
        if (messages && messages.count) {
            [NSKeyedArchiver setClassName:@"OSInAppMessageInternal" forClass:[OSInAppMessageInternal class]];
            [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_MESSAGES_ARRAY withValue:messages];
        } else {
            [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_MESSAGES_ARRAY withValue:nil];
        }

        // Redisplay Messages Dict
        NSMutableDictionary <NSString *, OSInAppMessageInternal *> *redisplayedInAppMessages = [[NSMutableDictionary alloc] initWithDictionary:[OneSignalUserDefaults.initStandard getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:[NSMutableDictionary new]]];
        if (redisplayedInAppMessages && redisplayedInAppMessages.count) {
            [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:redisplayedInAppMessages];
        } else {
            [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:nil];
        }
    }
}


@end
