/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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
#import "OneSignalHelper.h"
#import "OSOutcomesUtils.h"
#import "OSLastNotification.h"
#import "OneSignalSharedUserDefaults.h"

@implementation OSOutcomesUtils

static int DEFAULT_INDIRECT_ATTRIBUTION_WINDOW = 24 * 60;
static int DEFAULT_NOTIFICATION_LIMIT = 10;

+ (void)saveLastNotificationWithBackground:(NSString * _Nullable)notificationId wasOnBackground:(BOOL)wasOnBackground {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"saveLastNotificationWithBackground notificationId: %@ wasOnBackground: %@",
                                                       notificationId, wasOnBackground ? @"YES" : @"NO"]];
        
    NSArray *notifications = [OneSignalSharedUserDefaults getSavedCodeableData:LAST_NOTIFICATIONS_RECEIVED];

    NSTimeInterval timeInSeconds = [[NSDate date] timeIntervalSince1970];
    OSLastNotification *lastNotification = [[OSLastNotification alloc] initWithParamsNotificationId:notificationId
                                                                                        arrivalTime:timeInSeconds
                                                                                    wasOnBackground:wasOnBackground];
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Notifications received %@", lastNotification]];

    NSInteger notificationLimit = [self getNotificationLimit];
    
    NSArray *finalNotifications;
    if (!notifications) {
        finalNotifications = [NSArray arrayWithObject: lastNotification];
    } else if ([notifications count] < notificationLimit) {
        NSMutableArray *notificationIdsMutable = [notifications mutableCopy];
        [notificationIdsMutable addObject:lastNotification];
        
        finalNotifications = notificationIdsMutable;
    } else {
        NSMutableArray *notificationIdsMutable = [notifications mutableCopy];
        long lengthDifference = [notificationIdsMutable count] - notificationLimit;
        
        NSMutableArray *toDelete = [NSMutableArray new];
        for (int i = 0; i < lengthDifference; i++) {
            [toDelete addObject:[notificationIdsMutable objectAtIndex:i]];
        }
        
        finalNotifications = notificationIdsMutable;
    }
    
    [OneSignalSharedUserDefaults saveCodeableData:finalNotifications withKey:LAST_NOTIFICATIONS_RECEIVED];
}

+ (NSArray *)getNotifications {
    let userDefaults = [OneSignalSharedUserDefaults getSharedUserDefault];
    NSArray *notifications = [NSKeyedUnarchiver unarchiveObjectWithData:[userDefaults objectForKey:LAST_NOTIFICATIONS_RECEIVED]];
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Last notifications received: %@", [notifications description]]];
    return notifications;
}

+ (NSInteger)getNotificationLimit {
    return [OneSignalSharedUserDefaults getSavedInteger:NOTIFICATION_LIMIT defaultValue:DEFAULT_NOTIFICATION_LIMIT];
}

+ (NSInteger)getIndirectAttributionWindow {
    return [OneSignalSharedUserDefaults getSavedInteger:NOTIFICATION_ATTRIBUTION_WINDOW defaultValue:DEFAULT_INDIRECT_ATTRIBUTION_WINDOW];
}

+ (BOOL)isDirectSessionEnabled {
    return [OneSignalSharedUserDefaults getSavedBool:DIRECT_SESSION_ENABLED defaultValue:NO];
}

+ (BOOL)isIndirectSessionEnabled {
    return [OneSignalSharedUserDefaults getSavedBool:INDIRECT_SESSION_ENABLED defaultValue:NO];
}

+ (BOOL)isUnattributedSessionEnabled {
    return [OneSignalSharedUserDefaults getSavedBool:UNATTRIBUTED_SESSION_ENABLED defaultValue:NO];
}

+ (void)saveOutcomesParams:(NSDictionary *)params {
    NSDictionary *outcomes = [params objectForKey:@"outcomes"];
    if (outcomes) {
        NSDictionary *direct = [outcomes objectForKey:@"direct"];
        [self saveEnabledParamWithKey:DIRECT_SESSION_ENABLED dictionary:direct];
        
        NSDictionary *indirect = [outcomes objectForKey:@"indirect"];
        [self saveEnabledParamWithKey:INDIRECT_SESSION_ENABLED dictionary:indirect];
        
        if (indirect) {
            NSDictionary *notificationAttribution = [indirect objectForKey:@"notification_attribution"];
            if (notificationAttribution) {
                id minutesLimit = [notificationAttribution valueForKey:@"minutes_since_displayed"];
                id notificationLimit = [notificationAttribution valueForKey:@"limit"];
                
                NSInteger minutesLimitValue = minutesLimit && minutesLimit != (id)[NSNull null] ? [minutesLimit integerValue] : DEFAULT_INDIRECT_ATTRIBUTION_WINDOW;
                NSInteger notificationLimitValue = notificationLimit && notificationLimit != (id)[NSNull null] ? [notificationLimit integerValue] : DEFAULT_NOTIFICATION_LIMIT;
                
                [OneSignalSharedUserDefaults saveInteger:minutesLimitValue withKey:NOTIFICATION_ATTRIBUTION_WINDOW];
                [OneSignalSharedUserDefaults saveInteger:notificationLimitValue withKey:NOTIFICATION_LIMIT];
            }
        }
        
        NSDictionary *unattributed = [outcomes objectForKey:@"unattributed"];
        [self saveEnabledParamWithKey:UNATTRIBUTED_SESSION_ENABLED dictionary:unattributed];
    }
}

+ (void)saveEnabledParamWithKey:(NSString *)key dictionary:(NSDictionary *)dictionary {
    if (!dictionary)
        return;
    
    id isEnabled = [dictionary valueForKey:@"enabled"];
    BOOL unattributedEnabled = isEnabled ? [isEnabled boolValue] : NO;
    
    [OneSignalSharedUserDefaults saveBool:unattributedEnabled withKey:key];
}

+ (void)saveOpenedByNotification:(NSString *)notificationId {
    [OneSignalSharedUserDefaults saveString:notificationId withKey:OPENED_BY_NOTIFICATION];
}

+ (NSString *)wasOpenedByNotification {
    return [OneSignalSharedUserDefaults getSavedString:OPENED_BY_NOTIFICATION defaultValue:nil];
}

+ (void)saveLastSession:(SessionState)session notificationIds:(NSArray *)notificationIds {
    [OneSignalSharedUserDefaults saveString:sessionStateString(session) withKey:LAST_SESSION];
    [OneSignalSharedUserDefaults saveObject:notificationIds withKey:LAST_SESSION_NOTIFICATION_IDS];
}

+ (SessionState)getLastSession:(NSArray **)notificationIds {
    NSString *sessionString = [OneSignalSharedUserDefaults getSavedString:LAST_SESSION defaultValue:sessionStateString(NONE)];
    NSArray *sessionStateStrings = @[@"DIRECT", @"INDIRECT", @"UNATTRIBUTED", @"DISABLED", @"NONE"];
    NSArray *lastNotificationIds = [OneSignalSharedUserDefaults getSavedObject:LAST_SESSION_NOTIFICATION_IDS defaultValue:nil];
 
    *notificationIds = lastNotificationIds;
    
    return (int)[sessionStateStrings indexOfObject:sessionString];
}

@end
