//
//  OneSignalExtension.m
//  OneSignalExtension
//
//  Created by Brad Hesse on 9/26/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "OneSignalExtension.h"
#import "OneSignalNotificationServiceExtensionHandler.h"
#import "NSDictionary+OneSignal.h"

@implementation OneSignalExtension

// Called from the app's Notification Service Extension
+ (UNMutableNotificationContent*)didReceiveNotificationExtensionRequest:(UNNotificationRequest*)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    
    if (!request.content.userInfo.isOneSignalPayload)
        return replacementContent;
    
    return [OneSignalNotificationServiceExtensionHandler
            didReceiveNotificationExtensionRequest:request
            withMutableNotificationContent:replacementContent];
}


// Called from the app's Notification Service Extension
+ (UNMutableNotificationContent*)serviceExtensionTimeWillExpireRequest:(UNNotificationRequest*)request withMutableNotificationContent:(UNMutableNotificationContent*)replacementContent {
    
    if (!request.content.userInfo.isOneSignalPayload)
        return replacementContent;
    
    return [OneSignalNotificationServiceExtensionHandler
            serviceExtensionTimeWillExpireRequest:request
            withMutableNotificationContent:replacementContent];
}

@end
