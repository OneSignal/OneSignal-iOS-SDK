//
//  OneSignalExtensionBadgeHandler.h
//  OneSignal
//
//  Created by Brad Hesse on 3/15/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "OneSignal.h"

@interface OneSignalExtensionBadgeHandler : NSObject
+ (void)handleBadgeCountWithNotificationRequest:(UNNotificationRequest *)request withNotificationPayload:(OSNotificationPayload *)payload withMutableNotificationContent:(UNMutableNotificationContent *)replacementContent;
+ (NSString *)appGroupName;
@end
