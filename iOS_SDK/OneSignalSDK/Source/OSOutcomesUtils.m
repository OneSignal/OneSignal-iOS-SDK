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
#import "OneSignalHelper.h"
#import "OSOutcomesUtils.h"
#import "OSIndirectNotification.h"
#import "OneSignalCommonDefines.h"
#import "OSOutcomeEventsDefines.h"
#import "OneSignalUserDefaults.h"

@implementation OSOutcomesUtils

+ (BOOL)isAttributedSession:(Session)session {
    return session == DIRECT || session == INDIRECT;
}

// Number of notifications allowed in an INDIRECT session
+ (NSInteger)getIndirectNotificationLimit {
    return [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_NOTIFICATION_LIMIT defaultValue:DEFAULT_INDIRECT_NOTIFICATION_LIMIT];
}

// Time in minutes to keep track of notifications in an INDIRECT session
+ (NSInteger)getIndirectAttributionWindow {
    return [OneSignalUserDefaults.initShared getSavedIntegerForKey:OSUD_NOTIFICATION_ATTRIBUTION_WINDOW defaultValue:DEFAULT_INDIRECT_ATTRIBUTION_WINDOW];
}

// Flag for DIRECT session enabled
+ (BOOL)isDirectSessionEnabled {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_DIRECT_SESSION_ENABLED defaultValue:NO];
}

// Flag for INDIRECT session enabled
+ (BOOL)isIndirectSessionEnabled {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_INDIRECT_SESSION_ENABLED defaultValue:NO];
}

// Flag for UNATTRIBUTED session enabled
+ (BOOL)isUnattributedSessionEnabled {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_UNATTRIBUTED_SESSION_ENABLED defaultValue:NO];
}

/*
 ios_params has outcome params and will need to be parsed and stored locally
 These params include enabled flags for DIRECT, INDIRECT, and UNATTRIBUTED sessions,
 and the INDIRECT params for the notification limit and attribution window
 */
+ (void)saveOutcomeParamsForApp:(NSDictionary *)params {
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
        }
    }
}

/*
 Save the enabled flag param for DIRECT, INDIRECT, and UNATTRIBUTED outcomes
 */
+ (void)saveOutcomeEnabledFlag:(NSString *)key dictionary:(NSDictionary *)dictionary {
    if (!dictionary)
        return;
    
    id enabledExists = [dictionary valueForKey:ENABLED_PARAM];
    BOOL enabled = enabledExists ? [enabledExists boolValue] : NO;
    
    [OneSignalUserDefaults.initShared saveBoolForKey:key withValue:enabled];
}

+ (Session)getCachedSession {
    NSString *sessionString = [OneSignalUserDefaults.initShared getSavedStringForKey:OSUD_CACHED_SESSION defaultValue:OS_SESSION_TO_STRING(UNATTRIBUTED)];
    return OS_SESSION_FROM_STRING(sessionString);
}

+ (void)saveSession:(Session)session {
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_CACHED_SESSION withValue:OS_SESSION_TO_STRING(session)];
}

+ (NSString *)getCachedDirectNotificationId {
    return [OneSignalUserDefaults.initShared getSavedStringForKey:OSUD_CACHED_DIRECT_NOTIFICATION_ID defaultValue:nil];
}

+ (void)saveDirectNotificationId:(NSString *)notificationId {
    [OneSignalUserDefaults.initShared saveStringForKey:OSUD_CACHED_DIRECT_NOTIFICATION_ID withValue:notificationId];
}

+ (NSArray *)getCachedIndirectNotificationIds {
    NSArray *indirectNotifications = [OneSignalUserDefaults.initShared getSavedObjectForKey:OSUD_CACHED_INDIRECT_NOTIFICATION_IDS defaultValue:nil];
    return indirectNotifications;
}

+ (void)saveIndirectNotificationIds:(NSArray *)indirectNotifications {
    [OneSignalUserDefaults.initShared saveObjectForKey:OSUD_CACHED_INDIRECT_NOTIFICATION_IDS withValue:indirectNotifications];
}

+ (NSArray *)getCachedReceivedNotifications {
    NSArray *notifications = [OneSignalUserDefaults.initShared getSavedCodeableDataForKey:OSUD_CACHED_RECEIVED_NOTIFICATION_IDS defaultValue:nil];
    return notifications;
}

+ (void)saveReceivedNotifications:(NSArray *)notifications {
    [OneSignalUserDefaults.initShared saveCodeableDataForKey:OSUD_CACHED_RECEIVED_NOTIFICATION_IDS withValue:notifications];
}

/*
 Saves a received indirect notification into the NSUSerDefaults at a limit equivalent to the indirect notification limit param
 */
+ (void)saveReceivedNotificationFromBackground:(NSString * _Nonnull)notificationId {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"saveReceivedNotificationFromBackground notificationId: %@",
                                                       notificationId]];
    
    let notificationLimit = [self getIndirectNotificationLimit];
    let notifications = [self getCachedReceivedNotifications];

    let timestamp = [NSDate date].timeIntervalSince1970;
    let notification = [[OSIndirectNotification alloc] initWithParamsNotificationId:notificationId
                                                                          timestamp:timestamp];
    
    // Create finalNotifications to be saved at a limited size, removing any old notifications
    NSArray *finalNotifications;
    if (!notifications || notifications.count == 0) {
        finalNotifications = [NSArray arrayWithObject:notification];
    }
    else if (notifications.count < notificationLimit) {
        NSMutableArray *notificationIdsMutable = [notifications mutableCopy];
        [notificationIdsMutable addObject:notification];
        finalNotifications = notificationIdsMutable;
    }
    else {
        NSMutableArray *notificationIdsMutable = [notifications mutableCopy];
        [notificationIdsMutable addObject:notification];
        
        // Remove old notifications to keep finalNotifications at a limited size
        let lengthDifference = notificationIdsMutable.count - notificationLimit;
        for (int i = 0; i < lengthDifference; i++)
            [notificationIdsMutable removeObjectAtIndex:0];
        
        finalNotifications = notificationIdsMutable;
    }
    
    [self saveReceivedNotifications:finalNotifications];
}

@end
