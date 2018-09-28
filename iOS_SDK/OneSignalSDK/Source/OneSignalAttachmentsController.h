//
//  OneSignalAttachmentsController.h
//  OneSignalExtension
//
//  Created by Brad Hesse on 9/26/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "OneSignalShared.h"

NS_ASSUME_NONNULL_BEGIN

@interface OneSignalAttachmentsController : NSObject
+ (void)addAttachments:(OSNotificationPayload*)payload toNotificationContent:(UNMutableNotificationContent*)content;
+ (void)addActionButtons:(OSNotificationPayload*)payload toNotificationContent:(UNMutableNotificationContent*)content;
@end

NS_ASSUME_NONNULL_END
