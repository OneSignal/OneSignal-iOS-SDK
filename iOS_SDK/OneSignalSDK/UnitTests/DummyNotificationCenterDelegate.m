//
//  DummyNotificationCenterDelegate.m
//  UnitTests
//
//  Created by Brad Hesse on 4/19/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "DummyNotificationCenterDelegate.h"

@implementation DummyNotificationCenterDelegate

-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    
}

-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    
}

@end
