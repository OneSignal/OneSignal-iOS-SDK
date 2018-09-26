//
//  OneSignalExtension.h
//  OneSignalExtension
//
//  Created by Brad Hesse on 9/26/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

//! Project version number for OneSignalExtension.
FOUNDATION_EXPORT double OneSignalExtensionVersionNumber;

//! Project version string for OneSignalExtension.
FOUNDATION_EXPORT const unsigned char OneSignalExtensionVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <OneSignalExtension/PublicHeader.h>


@interface OneSignalExtension : NSObject
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent;
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest*)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent;
@end
