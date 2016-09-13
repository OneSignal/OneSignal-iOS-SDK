//
//  NotificationViewController.m
//  OSContentExension
//
//  Created by Joseph Kalash on 9/12/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

#import "NotificationViewController.h"
#import <UserNotifications/UserNotifications.h>
#import <UserNotificationsUI/UserNotificationsUI.h>

@interface NotificationViewController () <UNNotificationContentExtension>

@property IBOutlet UILabel *label;

@end

@implementation NotificationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)didReceiveNotification:(UNNotification *)notification {
    self.label.text = notification.request.content.body;
}

@end
