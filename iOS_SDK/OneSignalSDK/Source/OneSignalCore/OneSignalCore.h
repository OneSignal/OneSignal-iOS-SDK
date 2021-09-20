//
//  OneSignalCore.h
//  OneSignalCore
//
//  Created by Elliot Mawby on 9/20/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <UserNotifications/UserNotifications.h>

@interface OneSignalCore : NSObject

#pragma mark NotificationService Extension
// iOS 10 only
// Process from Notification Service Extension.
// Used for iOS Media Attachemtns and Action Buttons.
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent __deprecated_msg("Please use didReceiveNotificationExtensionRequest:withMutableNotificationContent:withContentHandler: instead.");
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent withContentHandler:(void (^)(UNNotificationContent *_Nonnull))contentHandler;
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest* _Nonnull)request withMutableNotificationContent:(UNMutableNotificationContent* _Nullable)replacementContent;
//
//#pragma mark Logging
//typedef NS_ENUM(NSUInteger, ONE_S_LOG_LEVEL) {
//    ONE_S_LL_NONE,
//    ONE_S_LL_FATAL,
//    ONE_S_LL_ERROR,
//    ONE_S_LL_WARN,
//    ONE_S_LL_INFO,
//    ONE_S_LL_DEBUG,
//    ONE_S_LL_VERBOSE
//};
//
//+ (void)setLogLevel:(ONE_S_LOG_LEVEL)logLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel;
//+ (void)onesignalLog:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message;

@end
//! Project version number for OneSignalCore.
FOUNDATION_EXPORT double OneSignalCoreVersionNumber;

//! Project version string for OneSignalCore.
FOUNDATION_EXPORT const unsigned char OneSignalCoreVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <OneSignalCore/PublicHeader.h>
