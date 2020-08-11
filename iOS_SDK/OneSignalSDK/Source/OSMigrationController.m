/**
Modified MIT License

Copyright 2020 OneSignal

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
#import "OSMigrationController.h"
#import "OSInfluenceDataRepository.h"
#import "OSOutcomeEventsCache.h"
#import "OSIndirectInfluence.h"
#import "OSCachedUniqueOutcome.h"
#import "OneSignal.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalHelper.h"

@interface OneSignal ()
+ (OSInfluenceDataRepository *)influenceDataRepository;
+ (OSOutcomeEventsCache *)outcomeEventsCache;
@end

@implementation OSMigrationController

- (void)migrate {
    [self migrateToVersion_02_14_00_AndGreater];
    [self saveCurrentSDKVersion];
}

/**
 * Support renaming of decodable classes for cached data
 */
- (void)migrateToVersion_02_14_00_AndGreater {
    let influenceVersion = 21400;
    let uniqueCacheOutcomeVersion = 21403;
    long sdkVersion = [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_CACHED_SDK_VERSION defaultValue:0];
    if (sdkVersion < influenceVersion) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Migrating OSIndirectNotification from version: %ld", sdkVersion]];

        [NSKeyedUnarchiver setClass:[OSIndirectInfluence class] forClassName:@"OSIndirectNotification"];
        NSArray<OSIndirectInfluence *> * indirectInfluenceData = [[OneSignal influenceDataRepository] lastNotificationsReceivedData];
        if (indirectInfluenceData) {
            [NSKeyedArchiver setClassName:@"OSIndirectInfluence" forClass:[OSIndirectInfluence class]];
            [[OneSignal influenceDataRepository] saveNotifications:indirectInfluenceData];
        }
    }
    
    if (sdkVersion < uniqueCacheOutcomeVersion) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"Migrating OSUniqueOutcomeNotification from version: %ld", sdkVersion]];
        
        [NSKeyedUnarchiver setClass:[OSCachedUniqueOutcome class] forClassName:@"OSUniqueOutcomeNotification"];
        NSArray<OSCachedUniqueOutcome *> * attributedCacheUniqueOutcomeEvents = [[OneSignal outcomeEventsCache] getAttributedUniqueOutcomeEventSent];
        if (attributedCacheUniqueOutcomeEvents) {
            [NSKeyedArchiver setClassName:@"OSCachedUniqueOutcome" forClass:[OSCachedUniqueOutcome class]];
            [[OneSignal outcomeEventsCache] saveAttributedUniqueOutcomeEventNotificationIds:attributedCacheUniqueOutcomeEvents];
        }
    }
}

- (void)saveCurrentSDKVersion {
    let currentVersion = [[OneSignal sdk_version_raw] intValue];
    [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_CACHED_SDK_VERSION withValue:currentVersion];
}

@end
