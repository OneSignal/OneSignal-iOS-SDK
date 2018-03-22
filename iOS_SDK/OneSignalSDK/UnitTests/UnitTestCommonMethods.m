/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

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
#import "OneSignalCommonDefines.h"


NSString * serverUrlWithPath(NSString *path) {
    return [NSString stringWithFormat:@"%@%@%@", SERVER_URL, API_VERSION, path];
}

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

+ (UNNotificationResponse*)createBasiciOSNotificationResponseWithPayload:(NSDictionary*)userInfo {
    // Mocking an iOS 10 notification
    // Setting response.notification.request.content.userInfo
    UNNotificationResponse *notifResponse = [UNNotificationResponse alloc];
    
    // Normal tap on notification
    [notifResponse setValue:@"com.apple.UNNotificationDefaultActionIdentifier" forKeyPath:@"actionIdentifier"];
    
    UNNotificationContent *unNotifContent = [UNNotificationContent alloc];
    UNNotification *unNotif = [UNNotification alloc];
    UNNotificationRequest *unNotifRequqest = [UNNotificationRequest alloc];
    // Set as remote push type
    [unNotifRequqest setValue:[UNPushNotificationTrigger alloc] forKey:@"trigger"];
    
    [unNotif setValue:unNotifRequqest forKeyPath:@"request"];
    [notifResponse setValue:unNotif forKeyPath:@"notification"];
    [unNotifRequqest setValue:unNotifContent forKeyPath:@"content"];
    [unNotifContent setValue:userInfo forKey:@"userInfo"];
    
    return notifResponse;
}

+ (void)clearStateForAppRestart:(XCTestCase *)testCase {
    NSLog(@"=======  APP RESTART ======\n\n");
    
    NSDateOverrider.timeOffset = 0;
    
    [OneSignalClientOverrider reset:testCase];
    [UNUserNotificationCenterOverrider reset:testCase];
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

@implementation OSEmailSubscriptionStateTestObserver
- (void)onOSEmailSubscriptionChanged:(OSEmailSubscriptionStateChanges *)stateChanges {
    NSLog(@"UnitTest:onOSEmailSubscriptionChanged: \n%@", stateChanges);
    last = stateChanges;
    fireCount++;
}
@end
