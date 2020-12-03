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
#import "NSBundleOverrider.h"
#import "NSTimerOverrider.h"
#import "OSMessagingControllerOverrider.h"
#import "OSInAppMessagingHelpers.h"
#import "OSOutcomeEventsCache.h"
#import "OSInfluenceDataRepository.h"
#import "OneSignalLocation.h"
#import "NSUserDefaultsOverrider.h"
#import "OneSignalNotificationServiceExtensionHandler.h"
#import "OneSignalTrackFirebaseAnalytics.h"
#import "OSMessagingControllerOverrider.h"
#import "OneSignalLifecycleObserver.h"

NSString * serverUrlWithPath(NSString *path) {
    return [OS_API_SERVER_URL stringByAppendingString:path];
}

@interface OneSignal ()

+ (void)notificationReceived:(NSDictionary*)messageDict foreground:(BOOL)foreground isActive:(BOOL)isActive wasOpened:(BOOL)opened;

@end

@implementation UnitTestCommonMethods

static XCTestCase* _currentXCTestCase;
+ (XCTestCase*)currentXCTestCase {
    return _currentXCTestCase;
}

// Runs any blocks passed to dispatch_async()
+ (void)runBackgroundThreads {
    NSLog(@"START runBackgroundThreads");
    
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    
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
    
    [notifResponse setValue:[self createBasiciOSNotificationWithPayload:userInfo] forKeyPath:@"notification"];
    
    return notifResponse;
}

+ (UNNotification *)createBasiciOSNotificationWithPayload:(NSDictionary *)userInfo {
    UNNotificationContent *unNotifContent = [UNNotificationContent alloc];
    UNNotification *unNotif = [UNNotification alloc];
    UNNotificationRequest *unNotifRequqest = [UNNotificationRequest alloc];
    // Set as remote push type
    [unNotifRequqest setValue:[UNPushNotificationTrigger alloc] forKey:@"trigger"];
    [unNotifContent setValue:userInfo forKey:@"userInfo"];
    [unNotifRequqest setValue:unNotifContent forKeyPath:@"content"];
    [unNotif setValue:unNotifRequqest forKeyPath:@"request"];
    return unNotif;
}

+ (void)clearStateForAppRestart:(XCTestCase *)testCase {
    NSLog(@"=======  APP RESTART ======\n\n");
    
    [UNUserNotificationCenterOverrider reset:testCase];
    [UIApplicationOverrider reset];
    [OneSignalTrackFirebaseAnalyticsOverrider reset];
    
    NSLocaleOverrider.preferredLanguagesArray = @[@"en-US"];
    
    [OneSignalHelper performSelector:NSSelectorFromString(@"resetLocals")];
    
    [OneSignal setValue:nil forKeyPath:@"lastAppActiveMessageId"];
    [OneSignal setValue:nil forKeyPath:@"lastnonActiveMessageId"];
    [OneSignal setValue:@0 forKeyPath:@"mSubscriptionStatus"];
    
    [OneSignalTracker performSelector:NSSelectorFromString(@"resetLocals")];
    
    [OneSignalTrackFirebaseAnalytics performSelector:NSSelectorFromString(@"resetLocals")];
    
    [NSObjectOverrider reset];
        
    [OneSignal performSelector:NSSelectorFromString(@"clearStatics")];
    
    [UIAlertViewOverrider reset];
    
    [OneSignal setLogLevel:ONE_S_LL_INFO visualLevel:ONE_S_LL_NONE];
    
    [NSTimerOverrider reset];
    
    [OSMessagingController.sharedInstance resetState];
    
    [OneSignalLifecycleObserver removeObserver];
}

+ (void)beforeAllTest:(XCTestCase *)testCase {
    _currentXCTestCase = testCase;
    [self beforeAllTest];
}

+ (void)beforeAllTest {
    // Esure we only run this once
    static var setupUIApplicationDelegate = false;
    if (setupUIApplicationDelegate)
        return;
    
    // Force swizzle in all methods for tests.
    OneSignalHelperOverrider.mockIOSVersion = 8;
    
    // Normally this just loops internally, overwrote _run to work around this.
    UIApplicationMain(0, nil, nil, NSStringFromClass([UnitTestAppDelegate class]));
    
    setupUIApplicationDelegate = true;
    
    // InstallUncaughtExceptionHandler();
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignal pauseInAppMessages:true];
}

+ (void) beforeEachTest:(XCTestCase *)testCase {
    [self beforeAllTest];
    [self clearStateForAppRestart:testCase];
    
    [NSDateOverrider reset];
    [OneSignalClientOverrider reset:testCase];
    [NSUserDefaultsOverrider clearInternalDictionary];
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
}

+ (void)setCurrentNotificationPermissionAsUnanswered {
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined];
}


// Helper used to simpify tests below.
+ (void)initOneSignal {
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    // iOS fires the resume event when app is cold started.
    [UnitTestCommonMethods foregroundApp];
}

+ (void)initOneSignalAndThreadWait {
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
}

+ (void)foregroundApp {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateActive;
    
    if ([UIApplication isAppUsingUIScene]) {
        if (@available(iOS 13.0, *)) {
            [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidActivateNotification object:nil];
        }
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    }
}

+ (void)backgroundApp {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateBackground;
    if ([UIApplication isAppUsingUIScene]) {
        if (@available(iOS 13.0, *)) {
            [[NSNotificationCenter defaultCenter] postNotificationName:UISceneWillDeactivateNotification object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:nil];
        }
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];
    }
}

+ (void)setAppInactive {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateInactive;
}

+ (void)pullDownNotificationCenter {
    [self backgroundApp];
    [self foregroundApp];
    [self backgroundApp];
    [self setAppInactive];
}

//Call this method before init OneSignal. Make sure not to overwrite the NSBundleDictionary in later calls.
+ (void)useSceneLifecycle:(BOOL)useSceneLifecycle {
    NSMutableDictionary *currentBundleDictionary = [[NSMutableDictionary alloc] initWithDictionary:NSBundleOverrider.nsbundleDictionary];
    if (useSceneLifecycle)
        [currentBundleDictionary setObject:@[@"SceneDelegate"] forKey:@"UIApplicationSceneManifest"];
    NSBundleOverrider.nsbundleDictionary = currentBundleDictionary;
}

+ (void)setCurrentNotificationPermission:(BOOL)accepted {
    if (accepted) {
        UNUserNotificationCenterOverrider.notifTypesOverride = 7;
        UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    }
    else {
        UNUserNotificationCenterOverrider.notifTypesOverride = 0;
        UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    }
}

+ (void)answerNotificationPrompt:(BOOL)accept {
    // iOS 10.2.1 Real device obserserved sequence of events:
    //   1. Call requestAuthorizationWithOptions to prompt for notifications.
    ///  2. App goes out of focus when the prompt is shown.
    //   3. User press ACCPET! and focus event fires.
    //   4. *(iOS bug?)* We check permission with currentNotificationCenter.getNotificationSettingsWithCompletionHandler and it show up as UNAuthorizationStatusDenied!?!?!
    //   5. Callback passed to getNotificationSettingsWithCompletionHandler then fires with Accpeted as TRUE.
    //   6. Check getNotificationSettingsWithCompletionHandler and it is then correctly reporting UNAuthorizationStatusAuthorized
    //   7. Note: If remote notification background modes are on then application:didRegisterForRemoteNotificationsWithDeviceToken: will fire after #5 on it's own.
    BOOL triggerDidRegisterForRemoteNotfications = (UNUserNotificationCenterOverrider.authorizationStatus == [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined] && accept);
    if (triggerDidRegisterForRemoteNotfications)
        [self setCurrentNotificationPermission:false];
    
    [UnitTestCommonMethods foregroundApp];
    [self setCurrentNotificationPermission:accept];
    
    if (triggerDidRegisterForRemoteNotfications && NSBundleOverrider.nsbundleDictionary[@"UIBackgroundModes"])
        [UIApplicationOverrider helperCallDidRegisterForRemoteNotificationsWithDeviceToken];
    
    if (OneSignalHelperOverrider.mockIOSVersion > 9) {
        [UNUserNotificationCenterOverrider fireLastRequestAuthorizationWithGranted:accept];
    } else if (OneSignalHelperOverrider.mockIOSVersion > 7) {
        UIApplication *sharedApp = [UIApplication sharedApplication];
        [sharedApp.delegate application:sharedApp didRegisterUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UNUserNotificationCenterOverrider.notifTypesOverride categories:nil]];
    }
    else  { // iOS 7 - Only support accepted for now.
        [UIApplicationOverrider helperCallDidRegisterForRemoteNotificationsWithDeviceToken];
    }
}

+ (void)receiveNotification:(NSString *)notificationId wasOpened:(BOOL)opened {
    // Create notification content
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    
    if (!notificationId)
        notificationId = @"";
    
    content.userInfo = [self createNotificationUserInfo:notificationId];
    
    // Create notification request
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:notificationId content:content trigger:nil];
    
    // Entry point for the NSE
    [OneSignalNotificationServiceExtensionHandler didReceiveNotificationExtensionRequest:request withMutableNotificationContent:content];
    
    [self handleNotificationReceived:content.userInfo wasOpened:opened];
}

+ (void)handleNotificationReceived:(NSDictionary*)messageDict wasOpened:(BOOL)opened {
    BOOL foreground = UIApplication.sharedApplication.applicationState != UIApplicationStateBackground;
    BOOL isActive = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
    
    [OneSignal notificationReceived:messageDict foreground:foreground isActive:isActive wasOpened:opened];
}

+ (NSDictionary*)createNotificationUserInfo:(NSString *)notificationId {
    return @{
        @"aps": @{
                @"content_available": @1,
                @"mutable-content": @1,
                @"alert": @"Message Body",
        },
        @"os_data": @{
                @"i": notificationId,
        }
    };
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
