//
//  NotificationService.m
//  NotificationServiceExtension
//
//  Created by Kasten on 3/7/17.
//  Copyright © 2017 OneSignal. All rights reserved.
//

#import <OneSignal/OneSignal.h>

#import "NotificationService.h"

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    [OneSignal didReceiveNotificatioExtensionnRequest:request withMutableNotificationContent:self.bestAttemptContent];
    
    // Modify the notification content here...
    self.bestAttemptContent.title = [NSString stringWithFormat:@"%@ [modified]", self.bestAttemptContent.title];
    
    
    //self.bestAttemptContent.categoryIdentifier = @"myNotificationCategory";
    
    self.contentHandler(self.bestAttemptContent);
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    
    // TODO: Add OneSignal call here with the same name.
    //         It should add action buttons if they are set and skip the attachments if it can't finish in time.
    self.contentHandler(self.bestAttemptContent);
}

@end
