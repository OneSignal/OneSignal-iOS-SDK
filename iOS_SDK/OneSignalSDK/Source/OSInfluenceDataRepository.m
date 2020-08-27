/**
Modified MIT License

Copyright 2019 OneSignal

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
#import "OSInfluenceDataRepository.h"
#import "OSInfluenceDataDefines.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"

@implementation OSInfluenceDataRepository

- (void)cacheNotificationInfluenceType:(Session) influenceType {
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_CACHED_NOTIFICATION_INFLUENCE withValue:OS_INFLUENCE_TYPE_TO_STRING(influenceType)];
}

- (Session)notificationCachedInfluenceType {
    NSString *sessionString = [OneSignalUserDefaults.initShared getSavedStringForKey:OSUD_CACHED_NOTIFICATION_INFLUENCE defaultValue:OS_INFLUENCE_TYPE_TO_STRING(UNATTRIBUTED)];
    return OS_INFLUENCE_TYPE_FROM_STRING(sessionString);
}

- (void)cacheIAMInfluenceType:(Session) influenceType {
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_CACHED_IAM_INFLUENCE withValue:OS_INFLUENCE_TYPE_TO_STRING(influenceType)];
}

- (Session)iamCachedInfluenceType {
    NSString *sessionString = [OneSignalUserDefaults.initShared getSavedStringForKey:OSUD_CACHED_IAM_INFLUENCE defaultValue:OS_INFLUENCE_TYPE_TO_STRING(UNATTRIBUTED)];
    return OS_INFLUENCE_TYPE_FROM_STRING(sessionString);
}

- (void)cacheNotificationOpenId:(NSString *)notificationId {
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_CACHED_DIRECT_NOTIFICATION_ID withValue:notificationId];
}

- (NSString *)cachedNotificationOpenId {
    return [OneSignalUserDefaults.initShared getSavedStringForKey:OSUD_CACHED_DIRECT_NOTIFICATION_ID defaultValue:nil];
}

- (void)cacheIndirectNotifications:(NSArray *)notifications {
    [OneSignalUserDefaults.initShared saveObjectForKey:OSUD_CACHED_INDIRECT_NOTIFICATION_IDS withValue:notifications];
}

- (NSArray * _Nullable)cachedIndirectNotifications {
    return [OneSignalUserDefaults.initShared getSavedObjectForKey:OSUD_CACHED_INDIRECT_NOTIFICATION_IDS defaultValue:nil];
}

- (void)saveNotifications:(NSArray *)notifications {
    [OneSignalUserDefaults.initShared saveCodeableDataForKey:OSUD_CACHED_RECEIVED_NOTIFICATION_IDS withValue:notifications];
}

- (NSArray * _Nullable)lastNotificationsReceivedData {
    return [OneSignalUserDefaults.initShared getSavedCodeableDataForKey:OSUD_CACHED_RECEIVED_NOTIFICATION_IDS defaultValue:nil];
}

- (void)saveIAMs:(NSArray *)iams {
    [OneSignalUserDefaults.initShared saveCodeableDataForKey:OSUD_CACHED_RECEIVED_IAM_IDS withValue:iams];
}

- (NSArray *)lastIAMsReceivedData {
    return [OneSignalUserDefaults.initShared getSavedCodeableDataForKey:OSUD_CACHED_RECEIVED_IAM_IDS defaultValue:nil];
}

- (NSInteger)notificationLimit {
    return [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_NOTIFICATION_LIMIT defaultValue:DEFAULT_INDIRECT_NOTIFICATION_LIMIT];
}

- (NSInteger)iamLimit {
    return [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_IAM_LIMIT defaultValue:DEFAULT_INDIRECT_NOTIFICATION_LIMIT];
}

- (NSInteger)notificationIndirectAttributionWindow {
    return [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_NOTIFICATION_ATTRIBUTION_WINDOW defaultValue:DEFAULT_INDIRECT_ATTRIBUTION_WINDOW];
}

- (NSInteger)iamIndirectAttributionWindow {
    return [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_IAM_ATTRIBUTION_WINDOW defaultValue:DEFAULT_INDIRECT_ATTRIBUTION_WINDOW];
}

- (BOOL)isDirectInfluenceEnabled {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_DIRECT_SESSION_ENABLED defaultValue:NO];
}

- (BOOL)isIndirectInfluenceEnabled {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_INDIRECT_SESSION_ENABLED defaultValue:NO];
}

- (BOOL)isUnattributedInfluenceEnabled {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_UNATTRIBUTED_SESSION_ENABLED defaultValue:NO];
}

/*
 ios_params has outcome params and will need to be parsed and stored locally
 These params include enabled flags for DIRECT, INDIRECT, and UNATTRIBUTED sessions,
 and the INDIRECT params for the notification limit and attribution window
 */
- (void)saveInfluenceParams:(NSDictionary *)params {
    NSDictionary *outcomes = [params objectForKey:OUTCOMES_PARAM];
    if (outcomes) {
        NSDictionary *direct = [outcomes objectForKey:DIRECT_PARAM];
        NSDictionary *indirect = [outcomes objectForKey:INDIRECT_PARAM];
        NSDictionary *unattributed = [outcomes objectForKey:UNATTRIBUTED_PARAM];
        
        // Save all of the outcome enabled flags
        [self saveOutcomeEnabledFlag:OSUD_DIRECT_SESSION_ENABLED dictionary:direct];
        [self saveOutcomeEnabledFlag:OSUD_INDIRECT_SESSION_ENABLED dictionary:indirect];
        [self saveOutcomeEnabledFlag:OSUD_UNATTRIBUTED_SESSION_ENABLED dictionary:unattributed];
        
        // Validate and save the INDIRECT notification limit and attribution window
        if (indirect) {
            NSDictionary *notificationAttribution = [indirect objectForKey:NOTIFICATION_ATTRIBUTION_PARAM];
            if (notificationAttribution) {
                id minutesLimit = [notificationAttribution valueForKey:MINUTES_SINCE_DISPLAYED_PARAM];
                id notificationLimit = [notificationAttribution valueForKey:LIMIT_PARAM];

                int minutesLimitValue = minutesLimit ? [minutesLimit intValue] : DEFAULT_INDIRECT_ATTRIBUTION_WINDOW;
                int notificationLimitValue = notificationLimit ? [notificationLimit intValue] : DEFAULT_INDIRECT_NOTIFICATION_LIMIT;
                
                [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_NOTIFICATION_LIMIT withValue:notificationLimitValue];
                [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_NOTIFICATION_ATTRIBUTION_WINDOW withValue:minutesLimitValue];
            }
            
            NSDictionary *iamAttribution = [indirect objectForKey:IAM_ATTRIBUTION_PARAM];
            if (iamAttribution) {
                id minutesLimit = [iamAttribution valueForKey:MINUTES_SINCE_DISPLAYED_PARAM];
                id iamLimit = [iamAttribution valueForKey:LIMIT_PARAM];

                int minutesLimitValue = minutesLimit ? [minutesLimit intValue] : DEFAULT_INDIRECT_ATTRIBUTION_WINDOW;
                int iamLimitValue = iamLimit ? [iamLimit intValue] : DEFAULT_INDIRECT_NOTIFICATION_LIMIT;
                
                [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_IAM_LIMIT withValue:iamLimitValue];
                [OneSignalUserDefaults.initShared saveIntegerForKey:OSUD_IAM_ATTRIBUTION_WINDOW withValue:minutesLimitValue];
            }
        }
    }
}

/*
 Save the enabled flag param for DIRECT, INDIRECT, and UNATTRIBUTED outcomes
 */
- (void)saveOutcomeEnabledFlag:(NSString *)key dictionary:(NSDictionary *)dictionary {
    if (!dictionary)
        return;
    
    id enabledExists = [dictionary valueForKey:ENABLED_PARAM];
    BOOL enabled = enabledExists ? [enabledExists boolValue] : NO;
    
    [OneSignalUserDefaults.initShared saveBoolForKey:key withValue:enabled];
}

@end
