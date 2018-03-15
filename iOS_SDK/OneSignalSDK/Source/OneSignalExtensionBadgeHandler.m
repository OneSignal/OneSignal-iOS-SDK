//
//  OneSignalExtensionBadgeHandler.m
//  OneSignal
//
//  Created by Brad Hesse on 3/15/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "OneSignalExtensionBadgeHandler.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalHelper.h"
#import "OneSignalTrackFirebaseAnalytics.h"
#import "OSNotificationPayload+Internal.h"

@implementation OneSignalExtensionBadgeHandler

+ (void)handleBadgeCountWithNotificationRequest:(UNNotificationRequest *)request withNotificationPayload:(OSNotificationPayload *)payload withMutableNotificationContent:(UNMutableNotificationContent *)replacementContent {
    
    if (!payload.badgeIncrement)
        return;
    
    let appGroupName = [OneSignalExtensionBadgeHandler appGroupName];
    
    let userDefaults = [[NSUserDefaults alloc] initWithSuiteName:appGroupName];
    
    var currentValue = [((NSNumber *)[userDefaults objectForKey:ONESIGNAL_BADGE_KEY] ?: @0) intValue];
    
    currentValue += (int)payload.badgeIncrement;
    
    if (currentValue < 0)
        currentValue = 0;
    
    replacementContent.badge = @(currentValue);
    
    [userDefaults setObject:@(currentValue) forKey:ONESIGNAL_BADGE_KEY];
    [userDefaults synchronize];
}

+ (NSString *)appGroupName {
    var appGroupName = (NSString *)[[NSBundle mainBundle] objectForInfoDictionaryKey:ONESIGNAL_APP_GROUP_NAME_KEY];
    
    if (!appGroupName)
        appGroupName = [NSString stringWithFormat:@"group.%@.%@", [[NSBundle mainBundle] bundleIdentifier], @"onesignal"];
    
    return [appGroupName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

@end
