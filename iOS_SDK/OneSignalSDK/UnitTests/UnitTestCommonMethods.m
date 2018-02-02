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
#import "UnitTestAppDelegate.h"
#import "OneSignalHelper.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "NSLocaleOverrider.h"
#import "NSDateOverrider.h"
#import "OneSignalTracker.h"
#import "OneSignalTrackFirebaseAnalyticsOverrider.h"
#import "UIAlertViewOverrider.h"
#import "NSObjectOverrider.h"

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

+ (void)clearStateForAppRestart {
    NSLog(@"=======  APP RESTART ======\n\n");
    
    NSDateOverrider.timeOffset = 0;
    [OneSignalClientOverrider reset:self];
    [UNUserNotificationCenterOverrider reset:self];
    [UIApplicationOverrider reset];
    [OneSignalTrackFirebaseAnalyticsOverrider reset];
    
    NSLocaleOverrider.preferredLanguagesArray = @[@"en-US"];
    
    [OneSignalHelper performSelector:NSSelectorFromString(@"resetLocals")];
    
    [OneSignal setValue:nil forKeyPath:@"lastAppActiveMessageId"];
    [OneSignal setValue:nil forKeyPath:@"lastnonActiveMessageId"];
    [OneSignal setValue:@0 forKeyPath:@"mSubscriptionStatus"];
    
    [OneSignalTracker performSelector:NSSelectorFromString(@"resetLocals")];
    
    [NSObjectOverrider reset];
    
    [OneSignal performSelector:NSSelectorFromString(@"clearStatics")];
    
    [UIAlertViewOverrider reset];
    
    [OneSignal setLogLevel:ONE_S_LL_VERBOSE visualLevel:ONE_S_LL_NONE];
}

+ (void)beforeAllTest {
    static var setupUIApplicationDelegate = false;
    if (setupUIApplicationDelegate)
        return;
    
    // Normally this just loops internally, overwrote _run to work around this.
    UIApplicationMain(0, nil, nil, NSStringFromClass([UnitTestAppDelegate class]));
    
    setupUIApplicationDelegate = true;
    
    // InstallUncaughtExceptionHandler();
    
    // Force swizzle in all methods for tests.
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [OneSignalAppDelegate sizzlePreiOS10MethodsPhase1];
    [OneSignalAppDelegate sizzlePreiOS10MethodsPhase2];
    OneSignalHelperOverrider.mockIOSVersion = 10;
}

+ (void)setCurrentNotificationPermissionAsUnanswered {
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined];
}


// Helper used to simpify tests below.
+ (void)initOneSignal {
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    // iOS fires the resume event when app is cold started.
    [UnitTestCommonMethods resumeApp];
}

+ (void)resumeApp {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateActive;
    UIApplication *sharedApp = [UIApplication sharedApplication];
    [sharedApp.delegate applicationDidBecomeActive:sharedApp];
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
