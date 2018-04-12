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

#import "UnitTestCommonMethods.h"

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

#import "OneSignalExtensionBadgeHandler.h"

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
#import "OneSignalClientOverrider.h"

// Networking
#import "OneSignalClient.h"
#import "Requests.h"
#import "OneSignalClientOverrider.h"
#import "OneSignalCommonDefines.h"


@interface UnitTests : XCTestCase

@end

@implementation UnitTests

- (void)beforeAllTest {
    static var setupUIApplicationDelegate = false;
    if (setupUIApplicationDelegate)
        return;
    
    // Normally this just loops internally, overwrote _run to work around this.
    UIApplicationMain(0, nil, nil, NSStringFromClass([UnitTestAppDelegate class]));
    
    setupUIApplicationDelegate = true;
    
    // InstallUncaughtExceptionHandler();
    
    // Force swizzle in all methods for tests.
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [OneSignalAppDelegate swizzleSelectors];
    OneSignalHelperOverrider.mockIOSVersion = 10;
}

- (void)clearStateForAppRestart {
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

// Called before each test.
- (void)setUp {
    [super setUp];
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];

    [UnitTestCommonMethods beforeAllTest];
    
    // Uncomment to simulate slow travis-CI runs.
    /*float minRange = 0, maxRange = 15;
    float random = ((float)arc4random() / 0x100000000 * (maxRange - minRange)) + minRange;
    NSLog(@"Sleeping for debugging: %f", random);
    [NSThread sleepForTimeInterval:random];*/
}

// Called after each test.
- (void)tearDown {
    [super tearDown];
    [UnitTestCommonMethods runBackgroundThreads];
}

- (void)backgroundModesDisabledInXcode {
    NSBundleOverrider.nsbundleDictionary = @{};
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
    
    [UnitTestCommonMethods resumeApp];
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

- (void)backgroundApp {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateBackground;
    UIApplication *sharedApp = [UIApplication sharedApplication];
    [sharedApp.delegate applicationWillResignActive:sharedApp];
}
                                                                          
- (UNNotificationResponse*)createBasiciOSNotificationResponse {
  id userInfo = @{@"custom":
                      @{@"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"}
                  };
  
  return [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
}


-(void)initOneSignalAndThreadWait {
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
}

- (void)testBasicInitTest {
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    NSLog(@"iOS VERSION: %@", [[UIDevice currentDevice] systemVersion]);
    
    [UnitTestCommonMethods initOneSignal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    NSLog(@"CHECKING LAST HTTP REQUEST");
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @15);
    NSLog(@"RAN A FEW CONDITIONALS: %@", OneSignalClientOverrider.lastHTTPRequest);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"en-US");
    
    OSPermissionSubscriptionState* status = [OneSignal getPermissionSubscriptionState];
    XCTAssertTrue(status.permissionStatus.accepted);
    XCTAssertTrue(status.permissionStatus.hasPrompted);
    XCTAssertTrue(status.permissionStatus.answeredPrompt);
    
    NSLog(@"CURRENT USER ID: %@", status.subscriptionStatus);
    
    XCTAssertEqual(status.subscriptionStatus.subscribed, true);
    XCTAssertEqual(status.subscriptionStatus.userSubscriptionSetting, true);
    XCTAssertEqual(status.subscriptionStatus.userId, @"1234");
    XCTAssertEqualObjects(status.subscriptionStatus.pushToken, @"0000000000000000000000000000000000000000000000000000000000000000");
    
    //email has not been set so the email properties should be nil
    XCTAssertFalse(status.emailSubscriptionStatus.subscribed);
    XCTAssertNil(status.emailSubscriptionStatus.emailUserId);
    XCTAssertNil(status.emailSubscriptionStatus.emailAddress);
    
    // 2nd init call should not fire another on_session call.
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    
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
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    OneSignalHelperOverrider.mockIOSVersion = 7;
    
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @7);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"en-US");
    
    // 2nd init call should not fire another on_session call.
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
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
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];
    UIApplicationOverrider.didFailRegistarationErrorCode = 3010;
    
    [self initOneSignalAndThreadWait];
    
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"identifier"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @-15);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_model"], @"x86_64");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"en-US");
    
    // 2nd init call should not fire another on_session call.
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
}


- (void)testFocusSettingsOnInit {
    // Test old kOSSettingsKeyInFocusDisplayOption
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyInFocusDisplayOption: @(OSNotificationDisplayTypeNone)}];
    
    XCTAssertEqual(OneSignal.inFocusDisplayType, OSNotificationDisplayTypeNone);
    
    [UnitTestCommonMethods clearStateForAppRestart:self];

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
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key"], @"value");
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal setSubscription:true];
    [OneSignal promptLocation];
    [OneSignal promptForPushNotificationsWithUserResponse:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self initOneSignalAndThreadWait];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 1);
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
    
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.to.hasPrompted, true);
    XCTAssertEqual(observer->last.to.answeredPrompt, false);
    XCTAssertEqual(observer->fireCount, 1);
    
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
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
    [UnitTestCommonMethods runBackgroundThreads];
    
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
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [self setCurrentNotificationPermission:false];
    [self initOneSignalAndThreadWait];
    
    // Added Observer should be notified of the change right away.
    observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    [UnitTestCommonMethods runBackgroundThreads];
    
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
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    [UnitTestCommonMethods runBackgroundThreads];
    
    
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Restart App
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertNil(observer->last);
}

- (void)testPermissionChangeObserverDontLoseFromChanges {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    [UnitTestCommonMethods runBackgroundThreads];

    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
}

- (void)testSubscriptionChangeObserverWhenAlreadyAccepted {
    [self initOneSignalAndThreadWait];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [UnitTestCommonMethods runBackgroundThreads];
    
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
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [self setCurrentNotificationPermission:false];
    [self initOneSignalAndThreadWait];
    
    // Added Observer should be notified of the change right away.
    observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, true);
    XCTAssertEqual(observer->last.to.subscribed, false);
}


- (void)testPermissionChangeObserverWithNativeiOS10PromptCall {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError* error) {}];
    [self backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->fireCount, 1);
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 0, status: NotDetermined>,\nto:   <OSPermissionState: hasPrompted: 1, status: NotDetermined>\n>");
    
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Make sure it doesn't fire for answeredPrompt then again right away for accepted
    XCTAssertEqual(observer->fireCount, 2);
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: NotDetermined>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized>\n>");
}

// Yes, this starts with testTest, we are testing our Unit Test behavior!
//  Making sure our simulated methods using swizzling can reproduce an iOS 10.2.1 bug.
- (void)testTestPermissionChangeObserverWithNativeiOS10PromptCall {
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:false];
    
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
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
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->fireCount, 3);
    
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: Denied>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized>\n>");
}

- (void)testPermissionChangeObserverWithDecline {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.to.hasPrompted, true);
    XCTAssertEqual(observer->last.to.answeredPrompt, false);
    XCTAssertEqual(observer->fireCount, 1);
    
    [self answerNotifiationPrompt:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.answeredPrompt, true);
    XCTAssertEqual(observer->last.to.accepted, false);
    XCTAssertEqual(observer->fireCount, 2);
}


- (void)testPermissionAndSubscriptionChangeObserverRemove {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
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
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertNil(permissionObserver->last);
    XCTAssertNil(subscriptionObserver->last);
}

- (void)testSubscriptionChangeObserverBasic {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, false);
    XCTAssertEqual(observer->last.to.subscribed, true);
    
    [OneSignal setSubscription:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, true);
    XCTAssertEqual(observer->last.to.subscribed, false);
}

- (void)testSubscriptionChangeObserverWhenPromptNotShown {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    // Triggers the 30 fallback to register device right away.
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertNil(observer->last.from.userId);
    XCTAssertEqualObjects(observer->last.to.userId, @"1234");
    XCTAssertFalse(observer->last.to.subscribed);
    
    [OneSignal setSubscription:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue(observer->last.from.userSubscriptionSetting);
    XCTAssertFalse(observer->last.to.userSubscriptionSetting);
    // Device registered with OneSignal so now make pushToken available.
    XCTAssertEqualObjects(observer->last.to.pushToken, @"0000000000000000000000000000000000000000000000000000000000000000");
    
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertFalse(observer->last.to.subscribed);
    
    // Prompt and accept notifications
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Shouldn't be subscribed yet as we called setSubscription:false before
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertFalse(observer->last.to.subscribed);
    
    // Device should be reported a subscribed now as all condiditions are true.
    [OneSignal setSubscription:true];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertTrue(observer->last.to.subscribed);
}

- (void)testInitAcceptingNotificationsWithoutCapabilitesSet {
    [self backgroundModesDisabledInXcode];
    UIApplicationOverrider.didFailRegistarationErrorCode = 3000;
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    
    [UnitTestCommonMethods initOneSignal];
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    
    [UnitTestCommonMethods runBackgroundThreads];
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @-13);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
}


- (void)testPromptForPushNotificationsWithUserResponse {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    
    [UnitTestCommonMethods initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertTrue(didAccept);
}

- (void)testPromptForPushNotificationsWithUserResponseOnIOS8 {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    OneSignalHelperOverrider.mockIOSVersion = 8;
    
    [UnitTestCommonMethods initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertTrue(didAccept);
}

- (void)testPromptForPushNotificationsWithUserResponseOnIOS7 {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    OneSignalHelperOverrider.mockIOSVersion = 7;
    
    [UnitTestCommonMethods initOneSignal];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertTrue(didAccept);
}


- (void)testPromptedButNeveranswerNotificationPrompt {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignalAndThreadWait];
    
    // Don't make a network call right away.
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    
    // Triggers the 30 fallback to register device right away.
    [OneSignal performSelector:NSSelectorFromString(@"registerUser")];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @-19);
}

- (void)testNotificationTypesWhenAlreadyAcceptedWithAutoPromptOffOnFristStartPreIos10 {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [self setCurrentNotificationPermission:true];
    
    [OneSignal initWithLaunchOptions:nil
                               appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @7);
}


- (void)testNeverPromptedStatus {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    
    [OneSignal initWithLaunchOptions:nil
                               appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    [UnitTestCommonMethods runBackgroundThreads];
    // Triggers the 30 fallback to register device right away.
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @-18);
}

- (void)testNotAcceptingNotificationsWithoutBackgroundModes {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];
    
    [UnitTestCommonMethods initOneSignal];
    
    // Don't make a network call right away.
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    
    [self answerNotifiationPrompt:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"players"));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"identifier"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
}

- (void)testIdsAvailableNotAcceptingNotifications {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    __block BOOL idsAvailable1Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable1Called = true;
    }];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self registerForPushNotifications];
    
    [self answerNotifiationPrompt:false];
    
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertTrue(idsAvailable1Called);
    
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    __block BOOL idsAvailable2Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable2Called = true;
    }];
    
    [UnitTestCommonMethods runBackgroundThreads];
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
    [UnitTestCommonMethods runBackgroundThreads];
    
    id notifResponse = [self createBasiciOSNotificationResponse];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    // Make sure open tracking network call was made.
    XCTAssertEqual(openedWasFire, true);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55ba"));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"opened"], @1);
    
    // Make sure if the device recieved a duplicate we don't fire the open network call again.
    OneSignalClientOverrider.lastUrl = nil;
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(OneSignalClientOverrider.lastUrl);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
}


- (UNNotificationResponse*)createNotificationResponseForAnalyticsTests {
    id userInfo = @{@"custom":
                        @{@"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                          @"ti": @"1117f966-d8cc-11e4-bed1-df8f05be55bb",
                          @"tn": @"Template Name"
                          }
                    };
    
    return [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
}

- (void)testFirebaseAnalyticsNotificationOpen {
    OneSignalTrackFirebaseAnalyticsOverrider.hasFIRAnalytics = true;
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
                      @"notification_id": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                      @"source": @"OneSignal"}
                  };
    XCTAssertEqualObjects(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents[0], event);
}

- (void)testFirebaseAnalyticsInfluenceNotificationOpen {
    // Start App once to download params
    OneSignalTrackFirebaseAnalyticsOverrider.hasFIRAnalytics = true;
    [self initOneSignalAndThreadWait];
    
    // Notification is recieved.
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
              @"notification_id": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
              @"source": @"OneSignal"}
         };
    XCTAssertEqualObjects(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents[0], received_event);
    
    // Trigger a new app session
    [self backgroundApp];
    NSDateOverrider.timeOffset = 41;
    [UnitTestCommonMethods resumeApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Since we opened the app under 2 mintues after receiving a notification
    //   an influence_open should be sent to firebase.
    XCTAssertEqual(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents.count, 2);
    id influence_open_event = @{
       @"os_notification_influence_open": @{
          @"campaign": @"Template Name - 1117f966-d8cc-11e4-bed1-df8f05be55bb",
          @"medium": @"notification",
          @"notification_id": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
          @"source": @"OneSignal"}
       };
    XCTAssertEqualObjects(OneSignalTrackFirebaseAnalyticsOverrider.loggedEvents[1], influence_open_event);
}

- (void)testOSNotificationPayloadParsesTemplateFields {
    NSDictionary *aps = @{@"custom": @{@"ti": @"templateId", @"tn": @"Template name"}};
    OSNotificationPayload *paylaod = [OSNotificationPayload parseWithApns:aps];
    XCTAssertEqual(paylaod.templateID, @"templateId");
    XCTAssertEqual(paylaod.templateName, @"Template name");
    
    // Test os_data format
    aps = @{@"os_data": @{@"ti": @"templateId", @"tn": @"Template name"}};
    paylaod = [OSNotificationPayload parseWithApns:aps];
    XCTAssertEqual(paylaod.templateID, @"templateId");
    XCTAssertEqual(paylaod.templateName, @"Template name");
}


// Wrapper SDKs may not have the app_id available on cold starts.
// Open event should still fire however so the event is not missed.
- (void)testNotificationOpenOn2ndColdStartWithoutAppId {
    [self initOneSignalAndThreadWait];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    __block BOOL openedWasFire = false;
    [OneSignal initWithLaunchOptions:nil appId:nil handleNotificationAction:^(OSNotificationOpenedResult *result) {
        openedWasFire = true;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
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
    [UnitTestCommonMethods runBackgroundThreads];
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateInactive;
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"m": @"alert body only",
                    @"o": @[@{@"i": @"id1", @"n": @"text1"}],
                    @"custom": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
                            }
                    };
    
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    // Make sure open tracking network call was made.
    XCTAssertEqual(openedWasFire, true);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55ba"));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"opened"], @1);
    
    // Make sure if the device recieved a duplicate we don't fire the open network call again.
    OneSignalClientOverrider.lastUrl = nil;
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(OneSignalClientOverrider.lastUrl);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
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
    [UnitTestCommonMethods runBackgroundThreads];
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateInactive;
    
    id userInfo = @{@"aps": @{
                            @"mutable-content": @1,
                            @"alert": @"Message Body"
                            },
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                            @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                            }};
    
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    // Make sure open tracking network call was made.
    XCTAssertEqual(openedWasFire, true);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55ba"));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"opened"], @1);
    
    // Make sure if the device recieved a duplicate we don't fire the open network call again.
    OneSignalClientOverrider.lastUrl = nil;
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(OneSignalClientOverrider.lastUrl);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
}

// Testing iOS 10 - 2.4.0+ button fromat - with os_data aps payload format
- (void)notificationAlertButtonsDisplayWithFormat:(NSDictionary *)userInfo {
    __block BOOL openedWasFire = false;
    id receiveBlock = ^(OSNotificationOpenedResult *result) {
        XCTAssertEqual(result.action.type, OSNotificationActionTypeActionTaken);
        XCTAssertEqualObjects(result.action.actionID, @"id1");
        id actionButons = @[@{@"id": @"id1", @"text": @"text1"}];
        XCTAssertEqualObjects(result.notification.payload.actionButtons, actionButons);
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"actionSelected"], @"id1");
        
        openedWasFire = true;
    };
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" handleNotificationAction:receiveBlock];
    
    [UnitTestCommonMethods resumeApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifResponse setValue:@"id1" forKeyPath:@"actionIdentifier"];
    
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    id notifCenterDelegate = notifCenter.delegate;
    [notifCenterDelegate userNotificationCenter:notifCenter
                        willPresentNotification:[notifResponse notification]
                          withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
    
    XCTAssertEqual(UIAlertViewOverrider.uiAlertButtonArrayCount, 1);
    [UIAlertViewOverrider.lastUIAlertViewDelegate alertView:nil clickedButtonAtIndex:1];
    XCTAssertEqual(openedWasFire, true);
}

- (void)testOldFormatNotificationAlertButtonsDisplay {
    id oldFormat = @{@"aps" : @{
                             @"mutable-content" : @1,
                             @"alert" : @{
                                     @"title" : @"Test Title"
                                     }
                             },
                     @"buttons" : @[@{@"i": @"id1", @"n": @"text1"}],
                     @"custom" : @{
                             @"i" : @"b2f7f966-d8cc-11e4-bed1-df8f05be55bf"
                             }
                     };
    
    [self notificationAlertButtonsDisplayWithFormat:oldFormat];
}

- (void)testNewFormatNotificationAlertButtonsDisplay {
    id newFormat = @{@"aps": @{
                             @"mutable-content": @1,
                             @"alert": @{@"body": @"Message Body", @"title": @"title"}
                             },
                     @"os_data": @{
                             @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55bf",
                             @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                             }};
    
    [self notificationAlertButtonsDisplayWithFormat:newFormat];
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
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    id userInfo = @{@"custom": @{
                      @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                      @"a": @{ @"foo": @"bar" }
                  }};
    
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
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
    notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    XCTAssertEqual(openedWasFire, true);
    */
}

// Testing iOS 10 - pre-2.4.0 button fromat - with os_data aps payload format
- (void)receivedCallbackWithButtonsWithUserInfo:(NSDictionary *)userInfo {
    __block BOOL recievedWasFire = false;
    
    [OneSignal initWithLaunchOptions:nil
                               appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
          handleNotificationReceived:^(OSNotification *notification) {
              recievedWasFire = true;
              let actionButons = @[ @{@"id": @"id1", @"text": @"text1"} ];
              XCTAssertEqualObjects(notification.payload.actionButtons, actionButons);
          }
            handleNotificationAction:nil
                            settings:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    let notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    UNUserNotificationCenter *notifCenter = [UNUserNotificationCenter currentNotificationCenter];
    let notifCenterDelegate = notifCenter.delegate;
    
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateInactive;
    
    //iOS 10 calls UNUserNotificationCenterDelegate method directly when a notification is received while the app is in focus.
    [notifCenterDelegate userNotificationCenter:notifCenter
                        willPresentNotification:[notifResponse notification]
                          withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(recievedWasFire, true);
}

/*
    There was a bug where receiving notifications would cause OSRequestSubmitNotificationOpened
    to fire, even though the notification had not been opened
*/
- (void)testReceiveNotificationDoesNotSubmitOpenedRequest {
    [OneSignalClientOverrider reset:self];
    
    let newFormat = @{@"aps": @{@"content_available": @1},
                      @"os_data": @{
                              @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                              @"buttons": @{
                                      @"m": @"alert body only",
                                      @"o": @[@{@"i": @"id1", @"n": @"text1"}]
                                      }
                              }
                      };
    
    [self receivedCallbackWithButtonsWithUserInfo:newFormat];
    
    XCTAssertFalse([OneSignalClientOverrider hasExecutedRequestOfType:[OSRequestSubmitNotificationOpened class]]);
}

- (void)testReceivedCallbackWithButtonsWithNewFormat {
    let newFormat = @{@"aps": @{@"content_available": @1},
                      @"os_data": @{
                              @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                              @"buttons": @{
                                      @"m": @"alert body only",
                                      @"o": @[@{@"i": @"id1", @"n": @"text1"}]
                                      }
                              }
                      };
    
    id oldFormat = @{@"aps" : @{
                             @"mutable-content" : @1,
                             @"alert" : @{
                                     @"title" : @"Test Title"
                                     }
                             },
                     @"buttons" : @[@{@"i": @"id1", @"n": @"text1"}],
                     @"custom" : @{
                             @"i" : @"b2f7f966-d8cc-11e4-bed1-df8f05be55bf"
                             }
                     };
    
    [self receivedCallbackWithButtonsWithUserInfo:newFormat];
    [self receivedCallbackWithButtonsWithUserInfo:oldFormat];
}

-(void)fireDidReceiveRemoteNotification:(NSDictionary*)userInfo {
    let appDelegate = [UIApplication sharedApplication].delegate;
    [appDelegate application:[UIApplication sharedApplication]
didReceiveRemoteNotification:userInfo
      fetchCompletionHandler:^(UIBackgroundFetchResult result) { }];
}

-(void)assertLocalNotification:(NSDictionary*)userInfo {
    let localNotif = UIApplicationOverrider.lastUILocalNotification;
    XCTAssertEqualObjects(localNotif.alertBody, @"alert body only");
    XCTAssertEqualObjects(localNotif.category, @"__dynamic__");
    XCTAssertEqualObjects(localNotif.userInfo, userInfo);
    
    let categories = [UIApplication sharedApplication].currentUserNotificationSettings.categories;
    
    XCTAssertEqual(categories.count, 1);
    
    let category = categories.allObjects[0];
    XCTAssertEqualObjects(category.identifier, @"__dynamic__");
    
    let actions = [category actionsForContext:UIUserNotificationActionContextDefault];
    XCTAssertEqualObjects(actions[0].identifier, @"id1");
    XCTAssertEqualObjects(actions[0].title, @"text1");
}

// Testing iOS 8 - with os_data aps payload format
- (void)testGeneratingLocalNotificationWithButtonsiOS8_osdata_format {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [self initOneSignalAndThreadWait];
    [self backgroundApp];
    
    let userInfo = @{@"aps": @{@"content_available": @1},
                    @"os_data": @{
                            @"buttons": @{
                                    @"m": @"alert body only",
                                    @"o": @[@{@"i": @"id1", @"n": @"text1"}]
                                    }
                            },
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
                    };
    
    [self fireDidReceiveRemoteNotification:userInfo];
    [self assertLocalNotification:userInfo];
}

- (void)testGeneratingLocalNotificationWithButtonsiOS8 {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [self initOneSignalAndThreadWait];
    [self backgroundApp];
    
    let userInfo = @{@"aps": @{@"content_available": @1},
                    @"m": @"alert body only",
                    @"o": @[@{@"i": @"id1", @"n": @"text1"}],
                    @"custom": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
                            }
                    };
    
    [self fireDidReceiveRemoteNotification:userInfo];
    [self assertLocalNotification:userInfo];
}

- (void)testSendTags {
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    // Simple test with a sendTag and sendTags call.
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal sendTags:@{@"key1": @"value1", @"key2": @"value2"}];
    
    // Make sure all 3 sets of tags where send in 1 network call.
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key"], @"value");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key1"], @"value1");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key2"], @"value2");
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
    
    let expectation = [self expectationWithDescription:@"wait_tags"];
    expectation.expectedFulfillmentCount = 3;
    
    [OneSignal sendTag:@"key10" value:@"value10" onSuccess:^(NSDictionary *result) {
        [expectation fulfill];
    } onFailure:^(NSError *error) {}];
    [OneSignal sendTags:@{@"key11": @"value11", @"key12": @"value12"} onSuccess:^(NSDictionary *result) {
        [expectation fulfill];
    } onFailure:^(NSError *error) {}];
    
    [OneSignal sendTag:@"key13" value:@"value13" onSuccess:^(NSDictionary *result) {
        [expectation fulfill];
    } onFailure:^(NSError *error) {}];
    
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key10"], @"value10");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key11"], @"value11");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key12"], @"value12");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key13"], @"value13");
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    
}

- (void)testDeleteTags {
    [self initOneSignalAndThreadWait];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    NSLog(@"Calling sendTag and deleteTag");
    // send 2 tags and delete 1 before they get sent off.
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal sendTag:@"key2" value:@"value2"];
    [OneSignal deleteTag:@"key"];
    NSLog(@"Finished calling sendTag and deleteTag");
    
    // Make sure only 1 network call is made and only key2 gets sent.
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key2"], @"value2");
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
    
    [OneSignal sendTags:@{@"someKey": @NO}];
    [OneSignal deleteTag:@"someKey"];
}

- (void)testGetTags {
    [self initOneSignalAndThreadWait];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    __block BOOL fireGetTags = false;
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"getTags success HERE");
        fireGetTags = true;
    } onFailure:^(NSError *error) {
        NSLog(@"getTags onFailure HERE");
    }];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue(fireGetTags);
}

- (void)testGetTagsBeforePlayerId {
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    __block BOOL fireGetTags = false;
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"getTags success HERE");
        fireGetTags = true;
    } onFailure:^(NSError *error) {
        NSLog(@"getTags onFailure HERE");
    }];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue(fireGetTags);

}

- (void)testGetTagsWithNestedDelete {
    [UnitTestCommonMethods initOneSignal];
    
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
    
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    // create, ge tags, then sendTags call.
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    XCTAssertTrue(fireDeleteTags);
}

- (void)testSendTagsBeforeRegisterComplete {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    
    [self initOneSignalAndThreadWait];
    
    NSObjectOverrider.selectorNamesForInstantOnlyForFirstRun = [@[@"sendTagsToServer"] mutableCopy];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Do not try to send tag update yet as there isn't a player_id yet.
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 1);
    
    [self answerNotifiationPrompt:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // A single POST player create call should be made with tags included.
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key"], @"value");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
}

- (void)testPostNotification {
    [self initOneSignalAndThreadWait];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    
    // Normal post should auto add add_id.
    [OneSignal postNotification:@{@"contents": @{@"en": @"message body"}}];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"contents"][@"en"], @"message body");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    
    // Should allow overriding the app_id
    [OneSignal postNotification:@{@"contents": @{@"en": @"message body"}, @"app_id": @"override_app_UUID"}];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"contents"][@"en"], @"message body");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"override_app_UUID");
}


- (void)testFirstInitWithNotificationsAlreadyDeclined {
    [self backgroundModesDisabledInXcode];
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    
    [self initOneSignalAndThreadWait];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
}

- (void)testPermissionChangedInSettingsOutsideOfApp {
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [self backgroundModesDisabledInXcode];
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    
    [self initOneSignalAndThreadWait];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    
    [OneSignal addPermissionObserver:observer];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"identifier"]);
    
    [self backgroundApp];
    [self setCurrentNotificationPermission:true];
    [UnitTestCommonMethods resumeApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @15);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
}

- (void) testOnSessionWhenResuming {
    [self initOneSignalAndThreadWait];
    
    // Don't make an on_session call if only out of the app for 20 secounds
    [self backgroundApp];
    NSDateOverrider.timeOffset = 10;
    [UnitTestCommonMethods resumeApp];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    // Anything over 30 secounds should count as a session.
    [self backgroundApp];
    NSDateOverrider.timeOffset = 41;
    [UnitTestCommonMethods resumeApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"players/1234/on_session"));
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
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
    [UnitTestCommonMethods runBackgroundThreads];
    
    id userInfo = @{@"aps": @{@"content_available": @1},
                    @"custom": @{
                            @"i": @"b2f7f966-d8cc-11e4-1111-df8f05be55bb"
                            }
                    };
    
    [self fireDidReceiveRemoteNotification:userInfo];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(receivedWasFire, true);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 1);
}

-(UNNotificationCategory*)unNotificagionCategoryWithId:(NSString*)identifier {
    return [UNNotificationCategory
            categoryWithIdentifier:identifier
            actions:@[]
            intentIdentifiers:@[]
            options:UNNotificationCategoryOptionCustomDismissAction];
}

// iOS 10 - Notification Service Extension test
- (void) didReceiveNotificationExtensionRequestDontOverrideCateogoryWithUserInfo:(NSDictionary *)userInfo {
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
    [[notifResponse notification].request.content setValue:@"some_category" forKey:@"categoryIdentifier"];
    
    UNMutableNotificationContent* content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    // Make sure we didn't override an existing category
    XCTAssertEqualObjects(content.categoryIdentifier, @"some_category");
    // Make sure attachments were added.
    XCTAssertEqualObjects(content.attachments[0].identifier, @"id");
    XCTAssertEqualObjects(content.attachments[0].URL.scheme, @"file");
}

- (void)testDidReceiveNotificationExtensionRequestDontOverrideCategory
{
    id newFormat = @{@"aps": @{
                             @"mutable-content": @1,
                             @"alert": @"Message Body"
                             },
                     @"os_data": @{
                             @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                             @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                             @"att": @{ @"id": @"http://domain.com/file.jpg" }
                             }};
    
    id oldFormat = @{@"aps" : @{
                             @"mutable-content" : @1,
                             @"alert" : @{
                                     @"title" : @"Test Title"
                                     }
                             },
                     
                     @"att": @{ @"id": @"http://domain.com/file.jpg" },
                     @"buttons" : @[@{@"i": @"id1", @"n": @"text1"}],
                     @"custom" : @{
                             @"i" : @"b2f7f966-d8cc-11e4-bed1-df8f05be55bf"
                             }
                     };
    
    
    [self didReceiveNotificationExtensionRequestDontOverrideCateogoryWithUserInfo:oldFormat];
    [self didReceiveNotificationExtensionRequestDontOverrideCateogoryWithUserInfo:newFormat];
}

// iOS 10 - Notification Service Extension test
- (void) testDidReceiveNotificationExtensionRequestDontOverrideCateogory {    
    id userInfo = @{@"aps": @{
                            @"mutable-content": @1,
                            @"alert": @"Message Body"
                            },
                    @"os_data": @{
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                            @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                            @"att": @{ @"id": @"http://domain.com/file.jpg" }
                            }};
    
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
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
                            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                            @"att": @{ @"id": @"file.jpg" }
                            }};
    
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
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
                        @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                        @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                        @"att": @{ @"id": @"http://domain.com/file.jpg" }
                    }};
    
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent* content = [OneSignal serviceExtensionTimeWillExpireRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    // Make sure butons were added.
    XCTAssertEqualObjects(content.categoryIdentifier, @"__dynamic__");
    // Make sure attachments were NOT added.
    //   We should not try to download attachemts as iOS is about to kill the extension and this will take to much time.
    XCTAssertNil(content.attachments);
}

-(void)testBuildOSRequest {
    let request = [OSRequestSendTagsToServer withUserId:@"12345" appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" tags:@{@"tag1" : @"test1", @"tag2" : @"test2"} networkType:[OneSignalHelper getNetType] withEmailAuthHashToken:nil];
    
    XCTAssert([request.parameters[@"app_id"] isEqualToString:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"]);
    XCTAssert([request.parameters[@"tags"][@"tag1"] isEqualToString:@"test1"]);
    XCTAssert([request.path isEqualToString:@"players/12345"]);
    
    let urlRequest = request.request;
    
    XCTAssert([urlRequest.URL.absoluteString isEqualToString:serverUrlWithPath(@"players/12345")]);
    XCTAssert([urlRequest.HTTPMethod isEqualToString:@"PUT"]);
    XCTAssert([urlRequest.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);
}

-(void)testInvalidJSONTags {
    [self initOneSignalAndThreadWait];
    
    //this test will also print invalid JSON warnings to console
    
    let invalidJson = @{@{@"invalid1" : @"invalid2"} : @"test"}; //Keys are required to be strings, this would crash the app if not handled appropriately
    
    let request = [OSRequestSendTagsToServer withUserId:@"12345" appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" tags:invalidJson networkType:[OneSignalHelper getNetType] withEmailAuthHashToken:nil];
    
    let urlRequest = request.request;
    
    XCTAssertNil(urlRequest.HTTPBody);
    
    //test OneSignal sendTags method
    [OneSignal sendTags:invalidJson];
    
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    //the request should fail and the HTTP request should not contain the invalid tags
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"tags"]);
}

/*
     When subscription state changes, the OSSubscriptionStateObserver will delay the update
     until the HTTP request to update the backend is finished. This prevents rare race
     conditions where an app instantly posts a new notification in response to a
     subscription change. This test checks to make sure it is delayed as it should be
 */

-(void)testDelayedSubscriptionUpdate {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Triggers the 30 fallback to register device right away.
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignal setSubscription:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Prompt and accept notifications
    [self registerForPushNotifications];
    [self answerNotifiationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Shouldn't be subscribed yet as we called setSubscription:false before
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertFalse(observer->last.to.subscribed);
    
    // Device should be reported a subscribed now as all condiditions are true.
    [OneSignalClientOverrider setShouldExecuteInstantaneously:false];
    [OneSignal setSubscription:true];
    
    [OneSignalClientOverrider setShouldExecuteInstantaneously:true];
    XCTAssertFalse(observer->last.to.subscribed);
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue(observer->last.to.subscribed);
}

@end
