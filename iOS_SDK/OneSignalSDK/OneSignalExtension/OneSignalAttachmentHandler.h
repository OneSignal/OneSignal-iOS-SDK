//
//  OneSignalAttachmentHandler.h
//  OneSignalExtension
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <OneSignalCore/OneSignalCore.h>
#import <UserNotifications/UserNotifications.h>

@interface OneSignalAttachmentHandler : NSObject
+ (void)addAttachments:(OSNotification*)notification toNotificationContent:(UNMutableNotificationContent*)content;
+ (void)addActionButtons:(OSNotification*)notification toNotificationContent:(UNMutableNotificationContent*)content;
+ (UNNotificationAction *)createActionForButton:(NSDictionary *)button;
@end

