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

#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <UserNotifications/UserNotifications.h>


#import "UncaughtExceptionHandler.h"


#import "OneSignal.h"

#import "OneSignalHelper.h"
#import "OneSignalTracker.h"
#import "OneSignalSelectorHelpers.h"
#import "NSString+OneSignal.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalNotificationSettingsIOS10.h"
#import "OSPermission.h"
#import "OSNotificationPayload+Internal.h"

#include <pthread.h>
#include <mach/mach.h>

#include "TestHelperFunctions.h"

#import "UnitTestAppDelegate.h"

// Shadows
#import "NSObjectOverrider.h"
#import "NSUserDefaultsOverrider.h"
#import "NSDateOverrider.h"
#import "NSBundleOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "UIApplicationOverrider.h"
#import "OneSignalHelperOverrider.h"
#import "NSLocaleOverrider.h"
#import "UIAlertViewOverrider.h"
#import "OneSignalTrackFirebaseAnalyticsOverrider.h"

@interface OneSignal (UN_extra)
+ (dispatch_queue_t) getRegisterQueue;
@end

// START - Start Observers

@interface OSPermissionStateTestObserver : NSObject<OSPermissionObserver>
@end

@implementation OSPermissionStateTestObserver {
    @package OSPermissionStateChanges* last;
    @package int fireCount;
}

- (void)onOSPermissionChanged:(OSPermissionStateChanges*)stateChanges {
    NSLog(@"UnitTest:onOSPermissionChanged :\n%@", stateChanges);
    last = stateChanges;
    fireCount++;
}
@end


@interface OSSubscriptionStateTestObserver : NSObject<OSSubscriptionObserver>
@end

@implementation OSSubscriptionStateTestObserver {
    @package OSSubscriptionStateChanges* last;
    @package int fireCount;
}
- (void)onOSSubscriptionChanged:(OSSubscriptionStateChanges*)stateChanges {
    NSLog(@"UnitTest:onOSSubscriptionChanged:\n%@", stateChanges);
    last = stateChanges;
    fireCount++;
}
@end

// END - Observers


@interface UnitTests : XCTestCase
@end

@implementation UnitTests

- (void)beforeAllTest {
    static BOOL setupUIApplicationDelegate = false;
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

- (void)clearStateForAppRestart {
    NSLog(@"=======  APP RESTART ======\n\n");
    
    NSDateOverrider.timeOffset = 0;
    [OneSignalHelperOverrider reset:self];
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

// Called before each test.
- (void)setUp {
    [super setUp];
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
    [self clearStateForAppRestart];

    [self beforeAllTest];
    
    // Uncomment to simulate slow travis-CI runs.
    /*float minRange = 0, maxRange = 15;
    float random = ((float)arc4random() / 0x100000000 * (maxRange - minRange)) + minRange;
    NSLog(@"Sleeping for debugging: %f", random);
    [NSThread sleepForTimeInterval:random];*/
}

// Called after each test.
- (void)tearDown {
    [super tearDown];
    [self runBackgroundThreads];
}

- (void)backgroundModesDisabledInXcode {
    NSBundleOverrider.nsbundleDictionary = @{};
}

- (void)setCurrentNotificationPermissionAsUnanswered {
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusNotDetermined];
}

- (void)setCurrentNotificationPermission:(BOOL)accepted {
    if (accepted) {
        UNUserNotificationCenterOverrider.notifTypesOverride = 7;
        UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    }
    else {
        UNUserNotificationCenterOverrider.notifTypesOverride = 0;
        UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    }
}

- (void)registerForPushNotifications {
    [OneSignal registerForPushNotifications];
    [self backgroundApp];
}

- (void)answerNotifiationPrompt:(BOOL)accept {
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
    
    [self resumeApp];
    [self setCurrentNotificationPermission:accept];
    
    if (triggerDidRegisterForRemoteNotfications && NSBundleOverrider.nsbundleDictionary[@"UIBackgroundModes"])
        [UIApplicationOverrider helperCallDidRegisterForRemoteNotificationsWithDeviceToken];
    
    if (OneSignalHelperOverrider.mockIOSVersion > 9)
        [UNUserNotificationCenterOverrider fireLastRequestAuthorizationWithGranted:accept];
    else if (OneSignalHelperOverrider.mockIOSVersion > 7) {
        UIApplication *sharedApp = [UIApplication sharedApplication];
        [sharedApp.delegate application:sharedApp didRegisterUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UNUserNotificationCenterOverrider.notifTypesOverride categories:nil]];
    }
    else // iOS 7 - Only support accepted for now.
        [UIApplicationOverrider helperCallDidRegisterForRemoteNotificationsWithDeviceToken];
}

- (void)backgroundApp {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateBackground;
    UIApplication *sharedApp = [UIApplication sharedApplication];
    [sharedApp.delegate applicationWillResignActive:sharedApp];
}

- (void)resumeApp {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateActive;
    UIApplication *sharedApp = [UIApplication sharedApplication];
    [sharedApp.delegate applicationDidBecomeActive:sharedApp];
}

// Runs any blocks passed to dispatch_async()
- (void)runBackgroundThreads {
    NSLog(@"START runBackgroundThreads");
    
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    
    dispatch_queue_t registerUserQueue, notifSettingsQueue;
    for(int i = 0; i < 10; i++) {
        [OneSignalHelperOverrider runBackgroundThreads];
        
        notifSettingsQueue = [OneSignalNotificationSettingsIOS10 getQueue];
        if (notifSettingsQueue)
            dispatch_sync(notifSettingsQueue, ^{});
        
        registerUserQueue = [OneSignal getRegisterQueue];
        if (registerUserQueue)
            dispatch_sync(registerUserQueue, ^{});
        
        [UNUserNotificationCenterOverrider runBackgroundThreads];
        
        dispatch_barrier_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{});
        
        [UIApplicationOverrider runBackgroundThreads];
    }
    
    NSLog(@"END runBackgroundThreads");
}


- (UNNotificationResponse*)createBasiciOSNotificationResponseWithPayload:(NSDictionary*)userInfo {
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
                                                                          
- (UNNotificationResponse*)createBasiciOSNotificationResponse {
  id userInfo = @{@"custom":
                      @{@"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb"}
                  };
  
  return [self createBasiciOSNotificationResponseWithPayload:userInfo];
}

// Helper used to simpify tests below.
- (void)initOneSignal {
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    // iOS fires the resume event when app is cold started.
    [self resumeApp];
}

-(void)initOneSignalAndThreadWait {
    [self initOneSignal];
    [self runBackgroundThreads];
}

- (void)testBasicInitTest {
    NSLog(@"iOS VERSION: %@", [[UIDevice currentDevice] systemVersion]);
    
    [self initOneSignal];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @15);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"language"], @"en-US");
    
    OSPermissionSubscriptionState* status = [OneSignal getPermissionSubscriptionState];
    XCTAssertTrue(status.permissionStatus.accepted);
    XCTAssertTrue(status.permissionStatus.hasPrompted);
    XCTAssertTrue(status.permissionStatus.answeredPrompt);
    
    XCTAssertEqual(status.subscriptionStatus.subscribed, true);
    XCTAssertEqual(status.subscriptionStatus.userSubscriptionSetting, true);
    XCTAssertEqual(status.subscriptionStatus.userId, @"1234");
    XCTAssertEqualObjects(status.subscriptionStatus.pushToken, @"0000000000000000000000000000000000000000000000000000000000000000");
    
    // 2nd init call should not fire another on_session call.
    OneSignalHelperOverrider.lastHTTPRequset = nil;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
}

- (void)testVersionStringLength {
	XCTAssertEqual(ONESIGNAL_VERSION.length, 6, @"ONESIGNAL_VERSION length is not 6: length is %lu", (unsigned long)ONESIGNAL_VERSION.length);
	XCTAssertEqual([OneSignal sdk_version_raw].length, 6, @"OneSignal sdk_version_raw length is not 6: length is %lu", (unsigned long)[OneSignal sdk_version_raw].length);
}

- (void)testSymanticVersioning {
	NSDictionary *versions = @{@"011303" : @"1.13.3",
                               @"020000" : @"2.0.0",
                               @"020116" : @"2.1.16",
                               @"020400" : @"2.4.0",
                               @"000400" : @"0.4.0",
                               @"000000" : @"0.0.0"};

	[versions enumerateKeysAndObjectsUsingBlock:^(NSString* raw, NSString* semantic, BOOL* stop) {
		XCTAssertEqualObjects([raw one_getSemanticVersion], semantic, @"Strings are not equal %@ %@", semantic, [raw one_getSemanticVersion] );
	}];

	NSDictionary *versionsThatFail = @{ @"011001" : @"1.0.1",
                                        @"011086" : @"1.10.6",
                                        @"011140" : @"1.11.0",
                                        @"011106" : @"1.11.1",
                                        @"091103" : @"1.11.3"};

	[versionsThatFail enumerateKeysAndObjectsUsingBlock:^(NSString* raw, NSString* semantic, BOOL* stop) {
		XCTAssertNotEqualObjects([raw one_getSemanticVersion], semantic, @"Strings are equal %@ %@", semantic, [raw one_getSemanticVersion] );
	}];

}

- (void)testRegisterationOniOS7 {
    OneSignalHelperOverrider.mockIOSVersion = 7;
    
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @7);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"language"], @"en-US");
    
    // 2nd init call should not fire another on_session call.
    OneSignalHelperOverrider.lastHTTPRequset = nil;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    
    // Make the following methods were not called as they are not available on iOS 7
    XCTAssertFalse(UIApplicationOverrider.calledRegisterForRemoteNotifications);
    XCTAssertFalse(UIApplicationOverrider.calledCurrentUserNotificationSettings);
}

// Test exists since we've seen a few rare crash reports where
//   [NSLocale preferredLanguages] resturns an empty array
- (void)testInitWithEmptyPreferredLanguages {
    NSLocaleOverrider.preferredLanguagesArray = @[];
    [self initOneSignalAndThreadWait];
}

- (void)testInitOnSimulator {
    [self setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];
    UIApplicationOverrider.didFailRegistarationErrorCode = 3010;
    
    [self initOneSignalAndThreadWait];
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset[@"identifier"]);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @-15);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"language"], @"en-US");
    
    // 2nd init call should not fire another on_session call.
    OneSignalHelperOverrider.lastHTTPRequset = nil;
    [self initOneSignalAndThreadWait];
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
}


- (void)testFocusSettingsOnInit {
    // Test old kOSSettingsKeyInFocusDisplayOption
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyInFocusDisplayOption: @(OSNotificationDisplayTypeNone)}];
    
    XCTAssertEqual(OneSignal.inFocusDisplayType, OSNotificationDisplayTypeNone);
    
    [self clearStateForAppRestart];

    // Test old very old kOSSettingsKeyInAppAlerts
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyInAppAlerts: @(false)}];
    XCTAssertEqual(OneSignal.inFocusDisplayType, OSNotificationDisplayTypeNone);
}

- (void)testCallingMethodsBeforeInit {
    [self setCurrentNotificationPermission:true];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal setSubscription:true];
    [OneSignal promptLocation];
    [OneSignal promptForPushNotificationsWithUserResponse:nil];
    [self runBackgroundThreads];
    
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key"], @"value");
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    
    [self clearStateForAppRestart];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal setSubscription:true];
    [OneSignal promptLocation];
    [OneSignal promptForPushNotificationsWithUserResponse:nil];
    [self runBackgroundThreads];
    
    [self initOneSignalAndThreadWait];
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 0);
    
}

- (void)testPermissionChangeObserverIOS10 {
    OneSignalHelperOverrider.mockIOSVersion = 10;
    [self sharedTestPermissionChangeObserver];
}
- (void)testPermissionChangeObserverIOS8 {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [self sharedTestPermissionChangeObserver];
}
- (void)testPermissionChangeObserverIOS7 {
    OneSignalHelperOverrider.mockIOSVersion = 7;
    [self sharedTestPermissionChangeObserver];
}
- (void)sharedTestPermissionChangeObserver {
    
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.to.hasPrompted, true);
    XCTAssertEqual(observer->last.to.answeredPrompt, false);
    XCTAssertEqual(observer->fireCount, 1);
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.answeredPrompt, true);
    XCTAssertEqual(observer->last.to.accepted, true);
    
    // Make sure it doesn't fire for answeredPrompt then again right away for accepted
    XCTAssertEqual(observer->fireCount, 2);
    
    XCTAssertEqualObjects([observer->last description], @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: NotDetermined>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized>\n>");
}


- (void)testPermissionChangeObserverWhenAlreadyAccepted {
    [self initOneSignalAndThreadWait];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
    XCTAssertEqual(observer->fireCount, 1);
}

- (void)testPermissionChangeObserverFireAfterAppRestart {
    // Setup app as accepted.
    [self initOneSignalAndThreadWait];
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    // User kills app, turns off notifications, then opnes it agian.
    [self clearStateForAppRestart];
    [self setCurrentNotificationPermission:false];
    [self initOneSignalAndThreadWait];
    
    // Added Observer should be notified of the change right away.
    observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, true);
    XCTAssertEqual(observer->last.to.accepted, false);
}


- (void)testPermissionObserverDontFireIfNothingChangedAfterAppRestartiOS10 {
    OneSignalHelperOverrider.mockIOSVersion = 10;
    [self sharedPermissionObserverDontFireIfNothingChangedAfterAppRestart];
}
- (void)testPermissionObserverDontFireIfNothingChangedAfterAppRestartiOS8 {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [self sharedPermissionObserverDontFireIfNothingChangedAfterAppRestart];
}
- (void)testPermissionObserverDontFireIfNothingChangedAfterAppRestartiOS7 {
    OneSignalHelperOverrider.mockIOSVersion = 7;
    [self sharedPermissionObserverDontFireIfNothingChangedAfterAppRestart];
}
- (void)sharedPermissionObserverDontFireIfNothingChangedAfterAppRestart {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    [self runBackgroundThreads];
    
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    // Restart App
    [self clearStateForAppRestart];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self runBackgroundThreads];
    
    XCTAssertNil(observer->last);
}




- (void)testPermissionChangeObserverDontLoseFromChanges {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    [self runBackgroundThreads];
    
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    [self runBackgroundThreads];

    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
}

- (void)testSubscriptionChangeObserverWhenAlreadyAccepted {
    [self initOneSignalAndThreadWait];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, false);
    XCTAssertEqual(observer->last.to.subscribed, true);
    XCTAssertEqual(observer->fireCount, 1);
}

- (void)testSubscriptionChangeObserverFireAfterAppRestart {
    // Setup app as accepted.
    [self initOneSignalAndThreadWait];
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    
    // User kills app, turns off notifications, then opnes it agian.
    [self clearStateForAppRestart];
    [self setCurrentNotificationPermission:false];
    [self initOneSignalAndThreadWait];
    
    // Added Observer should be notified of the change right away.
    observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, true);
    XCTAssertEqual(observer->last.to.subscribed, false);
}


- (void)testPermissionChangeObserverWithNativeiOS10PromptCall {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError* error) {}];
    [self backgroundApp];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->fireCount, 1);
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 0, status: NotDetermined>,\nto:   <OSPermissionState: hasPrompted: 1, status: NotDetermined>\n>");
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    // Make sure it doesn't fire for answeredPrompt then again right away for accepted
    XCTAssertEqual(observer->fireCount, 2);
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: NotDetermined>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized>\n>");
}

// Yes, this starts with testTest, we are testing our Unit Test behavior!
//  Making sure our simulated methods using swizzling can reproduce an iOS 10.2.1 bug.
- (void)testTestPermissionChangeObserverWithNativeiOS10PromptCall {
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:false];
    
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError* error) {}];
    [self backgroundApp];
    // Full bug details explained in answerNotifiationPrompt
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->fireCount, 3);
    
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: Denied>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized>\n>");
}

- (void)testPermissionChangeObserverWithDecline {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.to.hasPrompted, true);
    XCTAssertEqual(observer->last.to.answeredPrompt, false);
    XCTAssertEqual(observer->fireCount, 1);
    
    [self answerNotifiationPrompt:false];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.answeredPrompt, true);
    XCTAssertEqual(observer->last.to.accepted, false);
    XCTAssertEqual(observer->fireCount, 2);
}


- (void)testPermissionAndSubscriptionChangeObserverRemove {
    [self setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* permissionObserver = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:permissionObserver];
    [OneSignal removePermissionObserver:permissionObserver];
    
    OSSubscriptionStateTestObserver* subscriptionObserver = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:subscriptionObserver];
    [OneSignal removeSubscriptionObserver:subscriptionObserver];
    
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertNil(permissionObserver->last);
    XCTAssertNil(subscriptionObserver->last);
}

- (void)testSubscriptionChangeObserverBasic {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, false);
    XCTAssertEqual(observer->last.to.subscribed, true);
    
    [OneSignal setSubscription:false];
    
    XCTAssertEqual(observer->last.from.subscribed, true);
    XCTAssertEqual(observer->last.to.subscribed, false);
    
    XCTAssertEqualObjects([observer->last description], @"<OSSubscriptionStateChanges:\nfrom: <OSSubscriptionState: userId: 1234, pushToken: 0000000000000000000000000000000000000000000000000000000000000000, userSubscriptionSetting: 1, subscribed: 1>,\nto:   <OSSubscriptionState: userId: 1234, pushToken: 0000000000000000000000000000000000000000000000000000000000000000, userSubscriptionSetting: 0, subscribed: 0>\n>");
    NSLog(@"Test description: %@", observer->last);
}

- (void)testSubscriptionChangeObserverWhenPromptNotShown {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    // Triggers the 30 fallback to register device right away.
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    
    XCTAssertNil(observer->last.from.userId);
    XCTAssertEqualObjects(observer->last.to.userId, @"1234");
    XCTAssertFalse(observer->last.to.subscribed);
    
    [OneSignal setSubscription:false];
    [self runBackgroundThreads];
    
    XCTAssertTrue(observer->last.from.userSubscriptionSetting);
    XCTAssertFalse(observer->last.to.userSubscriptionSetting);
    // Device registered with OneSignal so now make pushToken available.
    XCTAssertEqualObjects(observer->last.to.pushToken, @"0000000000000000000000000000000000000000000000000000000000000000");
    
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertFalse(observer->last.to.subscribed);
    
    // Prompt and accept notifications
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    
    // Shouldn't be subscribed yet as we called setSubscription:false before
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertFalse(observer->last.to.subscribed);
    
    // Device should be reported a subscribed now as all condiditions are true.
    [OneSignal setSubscription:true];
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertTrue(observer->last.to.subscribed);
}

- (void)testInitAcceptingNotificationsWithoutCapabilitesSet {
    [self backgroundModesDisabledInXcode];
    UIApplicationOverrider.didFailRegistarationErrorCode = 3000;
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignal];
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @-13);
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
}


- (void)testPromptForPushNotificationsWithUserResponse {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    XCTAssertTrue(didAccept);
}

- (void)testPromptForPushNotificationsWithUserResponseOnIOS8 {
    [self setCurrentNotificationPermissionAsUnanswered];
    OneSignalHelperOverrider.mockIOSVersion = 8;
    
    [self initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    XCTAssertTrue(didAccept);
}

- (void)testPromptForPushNotificationsWithUserResponseOnIOS7 {
    [self setCurrentNotificationPermissionAsUnanswered];
    OneSignalHelperOverrider.mockIOSVersion = 7;
    
    [self initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [self runBackgroundThreads];
    XCTAssertTrue(didAccept);
}


- (void)testPromptedButNeveranswerNotificationPrompt {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignalAndThreadWait];
    
    // Don't make a network call right away.
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    
    // Triggers the 30 fallback to register device right away.
    [OneSignal performSelector:NSSelectorFromString(@"registerUser")];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @-19);
}

- (void)testNotificationTypesWhenAlreadyAcceptedWithAutoPromptOffOnFristStartPreIos10 {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @7);
}


- (void)testNeverPromptedStatus {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    [self runBackgroundThreads];
    // Triggers the 30 fallback to register device right away.
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @-18);
}

- (void)testNotAcceptingNotificationsWithoutBackgroundModes {
    [self setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];
    
    [self initOneSignal];
    
    // Don't make a network call right away.
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    
    [self answerNotifiationPrompt:false];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastUrl, @"https://onesignal.com/api/v1/players");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset[@"identifier"]);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @0);
}

- (void)testIdsAvailableNotAcceptingNotifications {
    [self setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    __block BOOL idsAvailable1Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable1Called = true;
    }];
    
    [self runBackgroundThreads];
    
    [self registerForPushNotifications];
    
    [self answerNotifiationPrompt:false];
    
    [self runBackgroundThreads];
    XCTAssertTrue(idsAvailable1Called);
    
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    __block BOOL idsAvailable2Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable2Called = true;
    }];
    
    [self runBackgroundThreads];
    XCTAssertTrue(idsAvailable2Called);
}

// Tests that a normal notification opened on iOS 10 triggers the handleNotificationAction.
- (void)testNotificationOpen {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertNil(result.notification.payload.additionalData);
        XCTAssertEqual(result.action.type, OSNotificationActionTypeOpened);
        XCTAssertNil(result.action.actionID);
        openedWasFire = true;
    }];
    [self runBackgroundThreads];
    
    id notifResponse = [self createBasiciOSNotificationResponse];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    // Make sure open tracking network call was made.
    XCTAssertEqual(openedWasFire, true);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastUrl, @"https://onesignal.com/api/v1/notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55bb");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"opened"], @1);
    
    // Make sure if the device recieved a duplicate we don't fire the open network call again.
    OneSignalHelperOverrider.lastUrl = nil;
    OneSignalHelperOverrider.lastHTTPRequset = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(OneSignalHelperOverrider.lastUrl);
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 2);
}


- (UNNotificationResponse*)createNotificationResponseForAnalyticsTests {
    id userInfo = @{@"custom":
                        @{@"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                          @"ti": @"1117f966-d8cc-11e4-bed1-df8f05be55bb",
                          @"tn": @"Template Name"
                          }
                    };
    
    return [self createBasiciOSNotificationResponseWithPayload:userInfo];
}

- (void)testFirebaseAnalyticsNotificationOpen {
    [self initOneSignalAndThreadWait];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    [notifCenter.delegate userNotificationCenter:notifCenter
                 didReceiveNotificationResponse:[self createNotificationResponseForAnalyticsTests]
                          withCompletionHandler:^() {}];
    
    // Make sure we track the notification open event
    XCTAssertEqual(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents.count, 1);
    id event =  @{
                  @"os_notification_opened": @{
                      @"campaign": @"Template Name - 1117f966-d8cc-11e4-bed1-df8f05be55bb",
                      @"medium": @"notification",
                      @"notification_id": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                      @"source": @"OneSignal"}
                  };
    XCTAssertEqualObjects(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents[0], event);
}

- (void)testFirebaseAnalyticsInfluenceNotificationOpen {
    // The Notification Service Extension runs where the notification received id tracked.
    //   Note: This is normally a separate process but can't emulate that here.
    UNNotificationResponse *response = [self createNotificationResponseForAnalyticsTests];
    [OneSignal didReceiveNotificationExtensionRequest:response.notification.request
                       withMutableNotificationContent:nil];
    
    // Make sure we are tracking the notification received event to firebase.
    XCTAssertEqual(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents.count, 1);
    id received_event = @{
         @"os_notification_received": @{
              @"campaign": @"Template Name - 1117f966-d8cc-11e4-bed1-df8f05be55bb",
              @"medium": @"notification",
              @"notification_id": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
              @"source": @"OneSignal"}
         };
    XCTAssertEqualObjects(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents[0], received_event);
    
    // App is now starting
    [self initOneSignalAndThreadWait];
    
    // Since we opened the app right after receiving a notification
    //   an influence_open should be sent to firebase.
    XCTAssertEqual(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents.count, 2);
    id influence_open_event = @{
       @"os_notification_influence_open": @{
          @"campaign": @"Template Name - 1117f966-d8cc-11e4-bed1-df8f05be55bb",
          @"medium": @"notification",
          @"notification_id": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
          @"source": @"OneSignal"}
       };
    XCTAssertEqualObjects(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents[1], influence_open_event);
}

- (void)testOSNotificationPayloadParsesTemplateFields {
    NSDictionary *aps = @{@"custom": @{@"ti": @"templateId", @"tn": @"Template name"}};
    OSNotificationPayload *paylaod = [[OSNotificationPayload alloc] initWithRawMessage:aps];
    XCTAssertEqual(paylaod.templateID, @"templateId");
    XCTAssertEqual(paylaod.templateName, @"Template name");
    
    // Test os_data format
    aps = @{@"os_data": @{@"ti": @"templateId", @"tn": @"Template name"}};
    paylaod = [[OSNotificationPayload alloc] initWithRawMessage:aps];
    XCTAssertEqual(paylaod.templateID, @"templateId");
    XCTAssertEqual(paylaod.templateName, @"Template name");
}


// Wrapper SDKs may not have the app_id available on cold starts.
// Open event should still fire however so the event is not missed.
- (void)testNotificationOpenOn2ndColdStartWithoutAppId {
    [self initOneSignalAndThreadWait];
    
    [self clearStateForAppRestart];
    
    __block BOOL openedWasFire = false;
    [OneSignal initWithLaunchOptions:nil appId:nil handleNotificationAction:^(OSNotificationOpenedResult *result) {
        openedWasFire = true;
    }];
    [self runBackgroundThreads];
    
    id notifResponse = [self createBasiciOSNotificationResponse];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertTrue(openedWasFire);
}

// Testing iOS 10 - old pre-2.4.0 button fromat - with original aps payload format
- (void)testNotificationOpenFromButtonPress {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"actionSelected"], @"id1");
        XCTAssertEqual(result.action.type, OSNotificationActionTypeActionTaken);
        XCTAssertEqualObjects(result.action.actionID, @"id1");
        openedWasFire = true;
    }];
    [self runBackgroundThreads];
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateInactive;
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"m": @"alert body only",
                    @"o": @[@{@"i": @"id1", @"n": @"text1"}],
                    @"custom": @{
                                @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb"
                            }
                    };
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    // Make sure open tracking network call was made.
    XCTAssertEqual(openedWasFire, true);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastUrl, @"https://onesignal.com/api/v1/notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55bb");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"opened"], @1);
    
    // Make sure if the device recieved a duplicate we don't fire the open network call again.
    OneSignalHelperOverrider.lastUrl = nil;
    OneSignalHelperOverrider.lastHTTPRequset = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(OneSignalHelperOverrider.lastUrl);
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 2);
}


// Testing iOS 10 - 2.4.0+ button fromat - with os_data aps payload format
- (void)testNotificationOpenFromButtonPressWithNewformat {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"actionSelected"], @"id1");
        XCTAssertEqual(result.action.type, OSNotificationActionTypeActionTaken);
        XCTAssertEqualObjects(result.action.actionID, @"id1");
        openedWasFire = true;
    }];
    [self runBackgroundThreads];
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateInactive;
    
    id userInfo = @{@"aps": @{
                        @"mutable-content": @1,
                        @"alert": @"Message Body"
                    },
                    @"os_data": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                        @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                    }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    // Make sure open tracking network call was made.
    XCTAssertEqual(openedWasFire, true);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastUrl, @"https://onesignal.com/api/v1/notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55bb");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"opened"], @1);
    
    // Make sure if the device recieved a duplicate we don't fire the open network call again.
    OneSignalHelperOverrider.lastUrl = nil;
    OneSignalHelperOverrider.lastHTTPRequset = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(OneSignalHelperOverrider.lastUrl);
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset);
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 2);
}

// Testing iOS 10 - 2.4.0+ button fromat - with os_data aps payload format
- (void)testNotificationAlertButtonsDisplayWithNewformat {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertEqual(result.action.type, OSNotificationActionTypeActionTaken);
        XCTAssertEqualObjects(result.action.actionID, @"id1");
        id actionButons = @[@{@"id": @"id1", @"text": @"text1"}];
        XCTAssertEqualObjects(result.notification.payload.actionButtons, actionButons);
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"actionSelected"], @"id1");
        
        openedWasFire = true;
    }];
    [self resumeApp];
    [self runBackgroundThreads];
    
    id userInfo = @{@"aps": @{
                            @"mutable-content": @1,
                            @"alert": @{@"body": @"Message Body", @"title": @"title"}
                            },
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bf",
                            @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                            }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    [notifCenterDelegate userNotificationCenter:notifCenter willPresentNotification:[notifResponse notification] withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
    
    XCTAssertEqual(UIAlertViewOverrider.uiAlertButtonArrayCount, 1);
    [UIAlertViewOverrider.lastUIAlertViewDelegate alertView:nil clickedButtonAtIndex:1];
    XCTAssertEqual(openedWasFire, true);
}


// Testing iOS 10 - with original aps payload format
- (void)testOpeningWithAdditionalData {
    __block BOOL openedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:^(OSNotificationOpenedResult *result) {
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"foo"], @"bar");
        XCTAssertEqual(result.action.type, OSNotificationActionTypeOpened);
        XCTAssertNil(result.action.actionID);
        openedWasFire = true;
    }];
    
    [self runBackgroundThreads];
    
    id userInfo = @{@"custom": @{
                      @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                      @"a": @{ @"foo": @"bar" }
                  }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opend.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    XCTAssertEqual(openedWasFire, true);
    
    // Part 2 - New paylaod test
    // Current mocking isn't able to setup this test correctly.
    // In an app AppDelete selectors fire instead of UNUserNotificationCenter
    // SDK could also used some refactoring as this should't have an effect.
    /*
    openedWasFire = false;
    userInfo = @{@"alert": @"body",
                 @"os_data": @{
                         @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bc"
                         },
                 @"foo": @"bar"};
    notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    XCTAssertEqual(openedWasFire, true);
    */
}

// Testing iOS 10 - pre-2.4.0 button fromat - with os_data aps payload format
- (void)testRecievedCallbackWithButtons {
    __block BOOL recievedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationReceived:^(OSNotification *notification) {
        recievedWasFire = true;
        id actionButons = @[ @{@"id": @"id1", @"text": @"text1"} ];
        // TODO: Fix code so it don't use the shortened format.
        // XCTAssertEqualObjects(notification.payload.actionButtons, actionButons);
    } handleNotificationAction:nil settings:nil];
    [self runBackgroundThreads];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"os_data": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                        @"buttons": @{
                            @"m": @"alert body only",
                            @"o": @[@{@"i": @"id1", @"n": @"text1"}]
                        }
                    }
                };
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    //iOS 10 calls  UNUserNotificationCenterDelegate method directly when a notification is received while the app is in focus.
    [notifCenterDelegate userNotificationCenter:notifCenter willPresentNotification:[notifResponse notification] withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
    
    XCTAssertEqual(recievedWasFire, true);
}


// Testing iOS 8 - with os_data aps payload format
- (void)testGeneratingLocalNotificationWithButtonsiOS8OS_data {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [self initOneSignalAndThreadWait];
    [self backgroundApp];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                            @"buttons": @{
                                    @"m": @"alert body only",
                                    @"o": @[@{@"i": @"id1", @"n": @"text1"}]
                                    }
                            }
                    };
    
    
    id appDelegate = [UIApplication sharedApplication].delegate;
                      
    [appDelegate application:[UIApplication sharedApplication]
didReceiveRemoteNotification:userInfo
      fetchCompletionHandler:^(UIBackgroundFetchResult result) { }];
    
    XCTAssertEqualObjects(UIApplicationOverrider.lastUILocalNotification.alertBody, @"alert body only");
}


- (void)testGeneratingLocalNotificationWithButtonsiOS8 {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [self initOneSignalAndThreadWait];
    [self backgroundApp];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"m": @"alert body only",
                    @"o": @[@{@"i": @"id1", @"n": @"text1"}],
                    @"custom": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb"
                            }
                    };
    
    
    id appDelegate = [UIApplication sharedApplication].delegate;
    
    [appDelegate application:[UIApplication sharedApplication]
didReceiveRemoteNotification:userInfo
      fetchCompletionHandler:^(UIBackgroundFetchResult result) { }];
    
    XCTAssertEqualObjects(UIApplicationOverrider.lastUILocalNotification.alertBody, @"alert body only");
}

- (void)testSendTags {
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    
    // Simple test with a sendTag and sendTags call.
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal sendTags:@{@"key1": @"value1", @"key2": @"value2"}];
    
    // Make sure all 3 sets of tags where send in 1 network call.
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key"], @"value");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key1"], @"value1");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key2"], @"value2");
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 2);
    
    // More advanced test with callbacks.
    __block BOOL didRunSuccess1, didRunSuccess2, didRunSuccess3;
    [OneSignal sendTag:@"key10" value:@"value10" onSuccess:^(NSDictionary *result) {
        didRunSuccess1 = true;
    } onFailure:^(NSError *error) {}];
    [OneSignal sendTags:@{@"key11": @"value11", @"key12": @"value12"} onSuccess:^(NSDictionary *result) {
        didRunSuccess2 = true;
    } onFailure:^(NSError *error) {}];
    
    NSObjectOverrider.instantRunPerformSelectorAfterDelay = true;
    [OneSignal sendTag:@"key13" value:@"value13" onSuccess:^(NSDictionary *result) {
        didRunSuccess3 = true;
    } onFailure:^(NSError *error) {}];
    
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key10"], @"value10");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key11"], @"value11");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key12"], @"value12");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key13"], @"value13");
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 3);
    
    XCTAssertEqual(didRunSuccess1, true);
    XCTAssertEqual(didRunSuccess2, true);
    XCTAssertEqual(didRunSuccess3, true);
}

- (void)testDeleteTags {
    [self initOneSignalAndThreadWait];
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    
    NSLog(@"Calling sendTag and deleteTag");
    // send 2 tags and delete 1 before they get sent off.
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal sendTag:@"key2" value:@"value2"];
    [OneSignal deleteTag:@"key"];
    NSLog(@"Finished calling sendTag and deleteTag");
    
    // Make sure only 1 network call is made and only key2 gets sent.
    [NSObjectOverrider runPendingSelectors];
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key"]);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key2"], @"value2");
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 2);
    
    [OneSignal sendTags:@{@"someKey": @NO}];
    [OneSignal deleteTag:@"someKey"];
}

- (void)testGetTags {
    [self initOneSignalAndThreadWait];
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    
    __block BOOL fireGetTags = false;
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"getTags success HERE");
        fireGetTags = true;
    } onFailure:^(NSError *error) {
        NSLog(@"getTags onFailure HERE");
    }];
    
    [self runBackgroundThreads];
    
    XCTAssertTrue(fireGetTags);
}

- (void)testGetTagsBeforePlayerId {
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    
    __block BOOL fireGetTags = false;
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"getTags success HERE");
        fireGetTags = true;
    } onFailure:^(NSError *error) {
        NSLog(@"getTags onFailure HERE");
    }];
    
    [self runBackgroundThreads];
    
    XCTAssertTrue(fireGetTags);

}

- (void)testGetTagsWithNestedDelete {
    [self initOneSignal];
    
    __block BOOL fireDeleteTags = false;
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"getTags success HERE");
        [OneSignal deleteTag:@"tag" onSuccess:^(NSDictionary *result) {
            fireDeleteTags = true;
            NSLog(@"deleteTag onSuccess HERE");
        } onFailure:^(NSError *error) {
            NSLog(@"deleteTag onFailure HERE");
        }];
    } onFailure:^(NSError *error) {
        NSLog(@"getTags onFailure HERE");
    }];
    
    
    [self runBackgroundThreads];
    
    [self runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    // create, ge tags, then sendTags call.
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 3);
    XCTAssertTrue(fireDeleteTags);
}

- (void)testSendTagsBeforeRegisterComplete {
    [self setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignalAndThreadWait];
    
    NSObjectOverrider.selectorNamesForInstantOnlyForFirstRun = [@[@"sendTagsToServer"] mutableCopy];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [self runBackgroundThreads];
    
    // Do not try to send tag update yet as there isn't a player_id yet.
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 0);
    
    [self answerNotifiationPrompt:false];
    [self runBackgroundThreads];
    
    // A single POST player create call should be made with tags included.
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"tags"][@"key"], @"value");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @0);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
}

- (void)testPostNotification {
    [self initOneSignalAndThreadWait];
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    
    
    // Normal post should auto add add_id.
    [OneSignal postNotification:@{@"contents": @{@"en": @"message body"}}];
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 2);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"contents"][@"en"], @"message body");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    
    // Should allow overriding the app_id
    [OneSignal postNotification:@{@"contents": @{@"en": @"message body"}, @"app_id": @"override_app_UUID"}];
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 3);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"contents"][@"en"], @"message body");
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"app_id"], @"override_app_UUID");
}


- (void)testFirstInitWithNotificationsAlreadyDeclined {
    [self backgroundModesDisabledInXcode];
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @0);
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
}

- (void)testPermissionChangedInSettingsOutsideOfApp {
    [self backgroundModesDisabledInXcode];
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    
    [self initOneSignalAndThreadWait];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    
    [OneSignal addPermissionObserver:observer];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @0);
    XCTAssertNil(OneSignalHelperOverrider.lastHTTPRequset[@"identifier"]);
    
    [self backgroundApp];
    [self setCurrentNotificationPermission:true];
    [self resumeApp];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"notification_types"], @15);
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastHTTPRequset[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 2);
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
}

- (void) testOnSessionWhenResuming {
    [self initOneSignalAndThreadWait];
    
    // Don't make an on_session call if only out of the app for 20 secounds
    [self backgroundApp];
    NSDateOverrider.timeOffset = 10;
    [self resumeApp];
    [self runBackgroundThreads];
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 1);
    
    // Anything over 30 secounds should count as a session.
    [self backgroundApp];
    NSDateOverrider.timeOffset = 41;
    [self resumeApp];
    [self runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalHelperOverrider.lastUrl, @"https://onesignal.com/api/v1/players/1234/on_session");
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 2);
}

// Tests that a slient content-available 1 notification doesn't trigger an on_session or count it has opened.
- (void)testContentAvailableDoesNotTriggerOpen  {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateBackground;
    __block BOOL receivedWasFire = false;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
          handleNotificationReceived:^(OSNotification *result) {
            receivedWasFire = true;
          }
                 handleNotificationAction:nil
                            settings:nil];
    [self runBackgroundThreads];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"custom": @{
                            @"i": @"b2f7f966-d8cc-11e4-1111-df8f05be55bb"
                            }
                    };
    
    
    id appDelegate = [UIApplication sharedApplication].delegate;
    [appDelegate application:[UIApplication sharedApplication]
didReceiveRemoteNotification:userInfo
      fetchCompletionHandler:^(UIBackgroundFetchResult result) { }];
    
    [self runBackgroundThreads];
    
    XCTAssertEqual(receivedWasFire, true);
    XCTAssertEqual(OneSignalHelperOverrider.networkRequestCount, 0);
}



// iOS 10 - Notification Service Extension test
- (void) testDidReceiveNotificatioExtensionRequest {
    // Example of a pre-existing category a developer setup. + possibly an existing "__dynamic__" category of ours.
    id category = [UNNotificationCategory categoryWithIdentifier:@"some_category" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
    id category2 = [UNNotificationCategory categoryWithIdentifier:@"__dynamic__" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
    id category3 = [UNNotificationCategory categoryWithIdentifier:@"some_category2" actions:@[] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
    
    id currentNC = [UNUserNotificationCenter currentNotificationCenter];
    id categorySet = [[NSMutableSet alloc] initWithArray:@[category, category2, category3]];
    [currentNC setNotificationCategories:categorySet];
    
    id userInfo = @{@"aps": @{
                        @"mutable-content": @1,
                        @"alert": @"Message Body"
                    },
                    @"os_data": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                        @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                        @"att": @{ @"id": @"http://domain.com/file.jpg" }
                    }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent* content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    // Make sure butons were added.
    XCTAssertEqualObjects(content.categoryIdentifier, @"__dynamic__");
    // Make sure attachments were added.
    XCTAssertEqualObjects(content.attachments[0].identifier, @"id");
    XCTAssertEqualObjects(content.attachments[0].URL.scheme, @"file");
    
    
    // Run again with different buttons.
    userInfo = @{@"aps": @{
                         @"mutable-content": @1,
                         @"alert": @"Message Body"
                         },
                 @"os_data": @{
                         @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                         @"buttons": @[@{@"i": @"id2", @"n": @"text2"}],
                         @"att": @{ @"id": @"http://domain.com/file.jpg" }
                         }};
    
    notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    XCTAssertEqual(UNUserNotificationCenterOverrider.lastSetCategoriesCount, 3);
}

// iOS 10 - Notification Service Extension test
- (void) testDidReceiveNotificationExtensionRequestDontOverrideCateogory {    
    id userInfo = @{@"aps": @{
                            @"mutable-content": @1,
                            @"alert": @"Message Body"
                            },
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                            @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                            @"att": @{ @"id": @"http://domain.com/file.jpg" }
                            }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    
    [[notifResponse notification].request.content setValue:@"some_category" forKey:@"categoryIdentifier"];
    
    UNMutableNotificationContent* content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    // Make sure we didn't override an existing category
    XCTAssertEqualObjects(content.categoryIdentifier, @"some_category");
    // Make sure attachments were added.
    XCTAssertEqualObjects(content.attachments[0].identifier, @"id");
    XCTAssertEqualObjects(content.attachments[0].URL.scheme, @"file");
}

// iOS 10 - Notification Service Extension test - local file
- (void) testDidReceiveNotificationExtensionRequestLocalFile {
    id userInfo = @{@"aps": @{
                            @"mutable-content": @1,
                            @"alert": @"Message Body"
                            },
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                            @"att": @{ @"id": @"file.jpg" }
                            }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent* content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];

    // Make sure attachments were added.
    XCTAssertEqualObjects(content.attachments[0].identifier, @"id");
    XCTAssertEqualObjects(content.attachments[0].URL.scheme, @"file");
}

// iOS 10 - Notification Service Extension test
- (void) testServiceExtensionTimeWillExpireRequest {
    id userInfo = @{@"aps": @{
                        @"mutable-content": @1,
                        @"alert": @"Message Body"
                        },
                    @"os_data": @{
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bb",
                        @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                        @"att": @{ @"id": @"http://domain.com/file.jpg" }
                    }};
    
    id notifResponse = [self createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent* content = [OneSignal serviceExtensionTimeWillExpireRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    // Make sure butons were added.
    XCTAssertEqualObjects(content.categoryIdentifier, @"__dynamic__");
    // Make sure attachments were NOT added.
    //   We should not try to download attachemts as iOS is about to kill the extension and this will take to much time.
    XCTAssertNil(content.attachments);
}
@end
