//
//  UnitTestCommonMethods.m
//  UnitTests
//
//  Created by Brad Hesse on 1/30/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "UnitTestCommonMethods.h"
#import "OneSignalClientOverrider.h"
#import "UIApplicationOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "OneSignalHelperOverrider.h"
#import "OneSignal.h"
#import "OneSignalNotificationSettingsIOS10.h"


@interface OneSignal (UN_extra)
+ (dispatch_queue_t) getRegisterQueue;
@end

@implementation UnitTestCommonMethods

// Runs any blocks passed to dispatch_async()
+ (void)runBackgroundThreads {
    NSLog(@"START runBackgroundThreads");
    
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    // the httpQueue makes sure all HTTP request mocks are sync'ed
    
    dispatch_queue_t registerUserQueue, notifSettingsQueue;
    for(int i = 0; i < 10; i++) {
        [OneSignalHelperOverrider runBackgroundThreads];
        
        notifSettingsQueue = [OneSignalNotificationSettingsIOS10 getQueue];
        if (notifSettingsQueue)
            dispatch_sync(notifSettingsQueue, ^{});
        
        registerUserQueue = [OneSignal getRegisterQueue];
        if (registerUserQueue)
            dispatch_sync(registerUserQueue, ^{});
        
        [OneSignalClientOverrider runBackgroundThreads];
        
        [UNUserNotificationCenterOverrider runBackgroundThreads];
        
        dispatch_barrier_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{});
        
        [UIApplicationOverrider runBackgroundThreads];
    }
    
    NSLog(@"END runBackgroundThreads");
}

@end


@implementation OSPermissionStateTestObserver

- (void)onOSPermissionChanged:(OSPermissionStateChanges*)stateChanges {
    NSLog(@"UnitTest:onOSPermissionChanged :\n%@", stateChanges);
    last = stateChanges;
    fireCount++;
}
@end



@implementation OSSubscriptionStateTestObserver 
- (void)onOSSubscriptionChanged:(OSSubscriptionStateChanges*)stateChanges {
    NSLog(@"UnitTest:onOSSubscriptionChanged:\n%@", stateChanges);
    last = stateChanges;
    fireCount++;
}
@end
