//
//  OneSignalCore.m
//  OneSignalCore
//
//  Created by Elliot Mawby on 9/20/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalCore.h"
#import "OneSignalNotificationServiceExtensionHandler.h"

@implementation OneSignalCore

// Called from the app's Notification Service Extension
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    return [OneSignalNotificationServiceExtensionHandler
            didReceiveNotificationExtensionRequest:request
            withMutableNotificationContent:replacementContent];
}

// Called from the app's Notification Service Extension. Calls contentHandler() to display the notification
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request                              withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent
                withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    return [OneSignalNotificationServiceExtensionHandler
            didReceiveNotificationExtensionRequest:request
            withMutableNotificationContent:replacementContent
            withContentHandler:contentHandler];
}


// Called from the app's Notification Service Extension
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest*)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    return [OneSignalNotificationServiceExtensionHandler
            serviceExtensionTimeWillExpireRequest:request
            withMutableNotificationContent:replacementContent];
}

//+ (void)setLogLevel:(ONE_S_LOG_LEVEL)nsLogLevel visualLevel:(ONE_S_LOG_LEVEL)visualLogLevel {
//    _nsLogLevel = nsLogLevel; _visualLogLevel = visualLogLevel;
//}
//
//+ (void) onesignal_Log:(ONE_S_LOG_LEVEL)logLevel message:(NSString*) message {
//    onesignal_Log(logLevel, message);
//}
//
//+ (void)onesignalLog:(ONE_S_LOG_LEVEL)logLevel message:(NSString* _Nonnull)message {
//    onesignal_Log(logLevel, message);
//}
//
//void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message) {
//    NSString* levelString;
//    switch (logLevel) {
//        case ONE_S_LL_FATAL:
//            levelString = @"FATAL: ";
//            break;
//        case ONE_S_LL_ERROR:
//            levelString = @"ERROR: ";
//            break;
//        case ONE_S_LL_WARN:
//            levelString = @"WARNING: ";
//            break;
//        case ONE_S_LL_INFO:
//            levelString = @"INFO: ";
//            break;
//        case ONE_S_LL_DEBUG:
//            levelString = @"DEBUG: ";
//            break;
//        case ONE_S_LL_VERBOSE:
//            levelString = @"VERBOSE: ";
//            break;
//
//        default:
//            break;
//    }
//
//    if (logLevel <= _nsLogLevel)
//        NSLog(@"%@", [levelString stringByAppendingString:message]);
//
//    if (logLevel <= _visualLogLevel) {
//        [[OneSignalDialogController sharedInstance] presentDialogWithTitle:levelString withMessage:message withActions:nil cancelTitle:NSLocalizedString(@"Close", @"Close button") withActionCompletion:nil];
//    }
//}

@end
