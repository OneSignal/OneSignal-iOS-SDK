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

#import <pthread.h>
#import <mach/mach.h>
#import <objc/runtime.h>
#import <XCTest/XCTest.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <UserNotifications/UserNotifications.h>
#import "UncaughtExceptionHandler.h"
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OneSignalTracker.h"
#import "OneSignalInternal.h"
#import "NSString+OneSignal.h"
#import "UnitTestCommonMethods.h"
#import "OneSignalSelectorHelpers.h"
#import "UIApplicationDelegate+OneSignal.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalNotificationSettingsIOS10.h"
#import "OSPermission.h"
#import "OSNotificationPayload+Internal.h"
#import "OneSignalUserDefaults.h"

#import "TestHelperFunctions.h"
#import "UnitTestAppDelegate.h"
#import "OneSignalExtensionBadgeHandler.h"
#import "OneSignalDialogControllerOverrider.h"
#import "OneSignalNotificationCategoryController.h"

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
#import "OneSignalLocation.h"
#import "OneSignalLocationOverrider.h"
#import "UIDeviceOverrider.h"

// Dummies
#import "DummyNotificationCenterDelegate.h"

// Networking
#import "OneSignalClient.h"
#import "Requests.h"
#import "OneSignalClientOverrider.h"
#import "OneSignalCommonDefines.h"



@interface OneSignalHelper (TestHelper)
+ (NSString*)downloadMediaAndSaveInBundle:(NSString*)urlString;
@end


@interface UnitTests : XCTestCase

@property NSString* CALLBACK_EXTERNAL_USER_ID;
@property NSString* CALLBACK_EMAIL_EXTERNAL_USER_ID;

@end

@implementation UnitTests

// Called before each test.
- (void)setUp {
    [super setUp];
    
    // Only enable remote-notifications in UIBackgroundModes
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    // Clear last location stored
    [OneSignalLocation clearLastLocation];
    
    // Clear callback external ids for push and email before each test
    self.CALLBACK_EXTERNAL_USER_ID = nil;
    self.CALLBACK_EMAIL_EXTERNAL_USER_ID = nil;

    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    [UnitTestCommonMethods beforeEachTest:self];
    
    [OneSignalHelperOverrider reset];
    
    [UIDeviceOverrider reset];
    
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

- (void)registerForPushNotifications {
    [OneSignal registerForPushNotifications];
    [self backgroundApp];
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

- (void)testBasicInitTest {
    // Simulator iPhone
    [UIDeviceOverrider reset];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    NSLog(@"iOS VERSION: %@", [[UIDevice currentDevice] systemVersion]);
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    NSLog(@"CHECKING LAST HTTP REQUEST");
    
    // final value should be "Simulator iPhone" or "Simulator iPad"
    let deviceModel = [OneSignalHelper getDeviceVariant];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], UIApplicationOverrider.mockAPNSToken);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @15);
    NSLog(@"RAN A FEW CONDITIONALS: %@", OneSignalClientOverrider.lastHTTPRequest);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_model"], deviceModel);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"en-US");
    
    OSPermissionSubscriptionState* status = [OneSignal getPermissionSubscriptionState];
    XCTAssertTrue(status.permissionStatus.accepted);
    XCTAssertTrue(status.permissionStatus.hasPrompted);
    XCTAssertTrue(status.permissionStatus.answeredPrompt);
    XCTAssertFalse(status.permissionStatus.provisional);
    
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
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
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

- (void)testLocationPromptAcceptedWithSetLocationShared_iOS8_AlwaysUsage {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification", @"location"],
                                             @"NSLocationAlwaysUsageDescription" : @YES
                                             };
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    [self assertLocationShared_withGrantLocationServices];
}

- (void)testLocationPromptAcceptedWithSetLocationShared_iOS8_AlwaysAndWhenInUseUsage {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification", @"location"],
                                             @"NSLocationAlwaysAndWhenInUseUsageDescription" : @YES
                                             };
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    [self assertLocationShared_withGrantLocationServices];
}

- (void)testLocationPromptAcceptedWithSetLocationShared_iOS8_WhenInUseUsage {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"],
                                             @"NSLocationWhenInUseUsageDescription" : @YES
                                             };
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    [self assertLocationShared_withGrantLocationServices];
}

- (void)testLocationPromptAcceptedWithSetLocationShared_iOS7AndUnder {
    OneSignalHelperOverrider.mockIOSVersion = 7;
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    [self assertLocationShared_withGrantLocationServices];
}

- (void)assertLocationShared_withGrantLocationServices {
    // Set location shared false
    [OneSignal setLocationShared:false];
    // Simulate user granting location services
    [OneSignalLocationOverrider grantLocationServices];
    // Last location should not exist since we are not sharing location
    XCTAssertFalse([OneSignalLocation lastLocation]);
    
    // Set location shared true
    [OneSignal setLocationShared:true];
    // Simulate user granting location services
    [OneSignalLocationOverrider grantLocationServices];
    // Last location should not exist since we are not sharing location
    XCTAssertTrue([OneSignalLocation lastLocation]);
}

- (void)testRegisterationOniOS7 {
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    OneSignalHelperOverrider.mockIOSVersion = 7;
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
        
    // final value should be "Simulator iPhone" or "Simulator iPad"
    let deviceModel = [OneSignalHelper getDeviceVariant];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @7);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_model"], deviceModel);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"en-US");
    
    // 2nd init call should not fire another on_session call.
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    // Make the following methods were not called as they are not available on iOS 7
    XCTAssertFalse(UIApplicationOverrider.calledRegisterForRemoteNotifications);
    XCTAssertFalse(UIApplicationOverrider.calledCurrentUserNotificationSettings);
}

// Test exists since we've seen a few rare crash reports where
//   [NSLocale preferredLanguages] resturns an empty array
- (void)testInitWithEmptyPreferredLanguages {
    NSLocaleOverrider.preferredLanguagesArray = @[];
    [UnitTestCommonMethods initOneSignalAndThreadWait];
}

- (void)testInitOnSimulator {
    [self backgroundModesDisabledInXcode];
    // Mock error code the simulator returns
    UIApplicationOverrider.didFailRegistarationErrorCode = 3010;
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
        
    // final value should be "Simulator iPhone" or "Simulator iPad"
    let deviceModel = [OneSignalHelper getDeviceVariant];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"identifier"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @-15);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_model"], deviceModel);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"device_type"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"language"], @"en-US");
    
    // 2nd init call should not fire another on_session call.
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
}


- (void)testFocusSettingsOnInit {
    // Test old kOSSettingsKeyInFocusDisplayOption
    [OneSignal setAppSettings:@{kOSSettingsKeyInFocusDisplayOption: @(OSNotificationDisplayTypeNone)}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    XCTAssertEqual(OneSignal.inFocusDisplayType, OSNotificationDisplayTypeNone);
    
    [UnitTestCommonMethods clearStateForAppRestart:self];

    // Test old very old kOSSettingsKeyInAppAlerts
    [OneSignal setAppSettings:@{kOSSettingsKeyInAppAlerts: @(false)}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];

    XCTAssertEqual(OneSignal.inFocusDisplayType, OSNotificationDisplayTypeNone);
}

- (void)testCallingMethodsWorks_beforeInit {
    [UnitTestCommonMethods setCurrentNotificationPermission:true];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal setSubscription:true];
    [OneSignal promptLocation];
    [OneSignal promptForPushNotificationsWithUserResponse:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key"], @"value");
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    [self backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [OneSignal setSubscription:true];
    [OneSignal promptLocation];
    [OneSignal promptForPushNotificationsWithUserResponse:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
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
    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.to.hasPrompted, true);
    XCTAssertEqual(observer->last.to.answeredPrompt, false);
    XCTAssertEqual(observer->fireCount, 1);
    XCTAssertEqual(observer->last.from.provisional, false);
    XCTAssertEqual(observer->last.to.provisional, false);
    
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.answeredPrompt, true);
    XCTAssertEqual(observer->last.to.accepted, true);
    
    // Make sure it doesn't fire for answeredPrompt then again right away for accepted
    XCTAssertEqual(observer->fireCount, 2);
    XCTAssertEqualObjects([observer->last description], @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: NotDetermined, provisional: 0>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized, provisional: 0>\n>");
}

- (void)testPermissionChangeObserverWhenAlreadyAccepted {
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    // User kills app, turns off notifications, then opnes it agian.
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [UnitTestCommonMethods setCurrentNotificationPermission:false];
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
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

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Restart App
    [UnitTestCommonMethods clearStateForAppRestart:self];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertNil(observer->last);
}

- (void)testPermissionChangeObserverDontLoseFromChanges {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self registerForPushNotifications];
    [UnitTestCommonMethods answerNotificationPrompt:true];
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, false);
    XCTAssertEqual(observer->last.to.subscribed, true);
    XCTAssertEqual(observer->fireCount, 1);
}

- (void)testSubscriptionChangeObserverFireAfterAppRestart {
    // Setup app as accepted.
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    
    // User kills app, turns off notifications, then opnes it agian.
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [UnitTestCommonMethods setCurrentNotificationPermission:false];
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // Added Observer should be notified of the change right away.
    observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.subscribed, true);
    XCTAssertEqual(observer->last.to.subscribed, false);
}


- (void)testPermissionChangeObserverWithNativeiOS10PromptCall {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError* error) {}];
    [self backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->fireCount, 1);
    NSLog(@"Sub desc: %@", [observer->last description]);
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 0, status: NotDetermined, provisional: 0>,\nto:   <OSPermissionState: hasPrompted: 1, status: NotDetermined, provisional: 0>\n>");
    
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Make sure it doesn't fire for answeredPrompt then again right away for accepted
    XCTAssertEqual(observer->fireCount, 2);
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: NotDetermined, provisional: 0>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized, provisional: 0>\n>");
}

// Yes, this starts with testTest, we are testing our Unit Test behavior!
//  Making sure our simulated methods using swizzling can reproduce an iOS 10.2.1 bug.
- (void)testTestPermissionChangeObserverWithNativeiOS10PromptCall {
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:false];
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError* error) {}];
    [self backgroundApp];
    // Full bug details explained in answerNotifiationPrompt
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->fireCount, 3);
    
    XCTAssertEqualObjects([observer->last description],
                          @"<OSSubscriptionStateChanges:\nfrom: <OSPermissionState: hasPrompted: 1, status: Denied, provisional: 0>,\nto:   <OSPermissionState: hasPrompted: 1, status: Authorized, provisional: 0>\n>");
}

- (void)testDeliverQuietly {
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:false];
    
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self backgroundApp];
    
    //answer the prompt to allow notification
    [UnitTestCommonMethods answerNotificationPrompt:true];
    
    // user notification center will return only `notificationCenterSetting` enabled
    // this mimics enabling 'Deliver Quietly'
    [UNUserNotificationCenterOverrider setNotifTypesOverride:(1 << 4)];
    [UnitTestCommonMethods runBackgroundThreads];
    
    let permissionState = OneSignal.getPermissionSubscriptionState.permissionStatus;
    
    // OneSignal should detect that deliver quietly is enabled and set the 5th bit to true
    XCTAssertTrue((permissionState.notificationTypes >> 4) & 1);
}

- (void)testPermissionChangeObserverWithDecline {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.hasPrompted, false);
    XCTAssertEqual(observer->last.from.answeredPrompt, false);
    XCTAssertEqual(observer->last.to.hasPrompted, true);
    XCTAssertEqual(observer->last.to.answeredPrompt, false);
    XCTAssertEqual(observer->fireCount, 1);
    
    [UnitTestCommonMethods answerNotificationPrompt:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.answeredPrompt, true);
    XCTAssertEqual(observer->last.to.accepted, false);
    XCTAssertEqual(observer->fireCount, 2);
}


- (void)testPermissionAndSubscriptionChangeObserverRemove {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    [self backgroundModesDisabledInXcode];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSPermissionStateTestObserver* permissionObserver = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:permissionObserver];
    [OneSignal removePermissionObserver:permissionObserver];
    
    OSSubscriptionStateTestObserver* subscriptionObserver = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:subscriptionObserver];
    [OneSignal removeSubscriptionObserver:subscriptionObserver];
    
    [self registerForPushNotifications];
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertNil(permissionObserver->last);
    XCTAssertNil(subscriptionObserver->last);
}

- (void)testSubscriptionChangeObserverBasic {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    [self registerForPushNotifications];
    [UnitTestCommonMethods answerNotificationPrompt:true];
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

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
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
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Shouldn't be subscribed yet as we called setSubscription:false before
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertFalse(observer->last.to.subscribed);
    
    // Device should be reported a subscribed now as all conditions are true.
    [OneSignal setSubscription:true];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertFalse(observer->last.from.subscribed);
    XCTAssertTrue(observer->last.to.subscribed);
}

- (void)testInitAcceptingNotificationsWithoutCapabilitesSet {
    [self backgroundModesDisabledInXcode];
    // Mock error code return when Push Notification Capabilites are missing
    UIApplicationOverrider.didFailRegistarationErrorCode = 3000;
    
    [UnitTestCommonMethods initOneSignal];
    // Don't make a network call right away
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @-13);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
}


- (void)testPromptForPushNotificationsWithUserResponse {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertTrue(didAccept);
}

- (void)testPromptForPushNotificationsWithUserResponseOnIOS8 {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    OneSignalHelperOverrider.mockIOSVersion = 8;
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertTrue(didAccept);
}

- (void)testPromptForPushNotificationsWithUserResponseOnIOS7 {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    OneSignalHelperOverrider.mockIOSVersion = 7;
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    __block BOOL didAccept;
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        didAccept = accepted;
    }];
    [self backgroundApp];
    [UnitTestCommonMethods answerNotificationPrompt:true];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertTrue(didAccept);
}


- (void)testPromptedButNeveranswerNotificationPrompt {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    // Don't make a network call right away
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    
    // Triggers the 30 fallback to register device right away.
    [OneSignal performSelector:NSSelectorFromString(@"registerUser")];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @-19);
}

- (void)testNotificationTypesWhenAlreadyAcceptedWithAutoPromptOffOnFristStartPreIos10 {
    OneSignalHelperOverrider.mockIOSVersion = 8;
    [UnitTestCommonMethods setCurrentNotificationPermission:true];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @7);
}


- (void)testNeverPromptedStatus {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
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
    // Don't make a network call right away
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    
    [UnitTestCommonMethods answerNotificationPrompt:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"players"));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"identifier"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
}

- (void)testIdsAvailableNotAcceptingNotifications {
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    __block BOOL idsAvailable1Called = false;
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        idsAvailable1Called = true;
    }];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self registerForPushNotifications];
    
    [UnitTestCommonMethods answerNotificationPrompt:false];
    
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertTrue(idsAvailable1Called);

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
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

    [OneSignal setAppSettings:@{kOSSettingsKeyInAppAlerts: @(true)}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [OneSignal setNotificationOpenedHandler:^(OSNotificationOpenedResult *result) {
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
    XCTAssertTrue(openedWasFire);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55ba"));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"opened"], @1);
    
    // Make sure if the device received a duplicate we don't fire the open network call again.
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // Notification is received.
    // The Notification Service Extension runs where the notification received id tracked.
    //   Note: This is normally a separate process but can't emulate that here.
    let response = [self createNotificationResponseForAnalyticsTests];
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
    [UnitTestCommonMethods backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSDateOverrider advanceSystemTimeBy:41];
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // TODO: Test carry over causes this influence_open not to fire
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    __block BOOL openedWasFire = false;
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [OneSignal setNotificationOpenedHandler:^(OSNotificationOpenedResult *result) {
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

// Testing iOS 10 - old pre-2.4.0 button format - with original aps payload format
- (void)testNotificationOpenFromButtonPress {
    __block BOOL openedWasFire = false;

    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [OneSignal setNotificationOpenedHandler:^(OSNotificationOpenedResult *result) {
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
    XCTAssertTrue(openedWasFire);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55ba"));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"opened"], @1);
    
    // Make sure if the device received a duplicate we don't fire the open network call again.
    OneSignalClientOverrider.lastUrl = nil;
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(OneSignalClientOverrider.lastUrl);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
}


// Testing iOS 10 - 2.4.0+ button format - with os_data aps payload format
- (void)testNotificationOpenFromButtonPressWithNewFormat {
    __block BOOL openedWasFire = false;

    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [OneSignal setNotificationOpenedHandler:^(OSNotificationOpenedResult *result) {
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
    XCTAssertTrue(openedWasFire);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"notifications/b2f7f966-d8cc-11e4-bed1-df8f05be55ba"));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"opened"], @1);
    
    // Make sure if the device received a duplicate we don't fire the open network call again.
    OneSignalClientOverrider.lastUrl = nil;
    OneSignalClientOverrider.lastHTTPRequest = nil;
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    
    XCTAssertNil(OneSignalClientOverrider.lastUrl);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
}

// Testing iOS 10 - 2.4.0+ button format - with os_data aps payload format
- (void)notificationAlertButtonsDisplayWithFormat:(NSDictionary *)userInfo {
    __block BOOL openedWasFire = false;

    [OneSignal setAppSettings:@{kOSSettingsKeyInAppAlerts: @(true)}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [OneSignal setNotificationOpenedHandler:^(OSNotificationOpenedResult *result) {
        XCTAssertEqual(result.action.type, OSNotificationActionTypeActionTaken);
        XCTAssertEqualObjects(result.action.actionID, @"id1");
        id actionButons = @[@{@"id": @"id1", @"text": @"text1"}];
        XCTAssertEqualObjects(result.notification.payload.actionButtons, actionButons);
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"actionSelected"], @"id1");
        
        XCTAssertEqualObjects(result.notification.payload.threadId, @"test1");
        
        openedWasFire = true;
    }];
    [UnitTestCommonMethods foregroundApp];
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

    XCTAssertTrue(openedWasFire);
}

- (void)testOldFormatNotificationAlertButtonsDisplay {
    id oldFormat = @{@"aps" : @{
                             @"mutable-content" : @1,
                             @"alert" : @{
                                     @"title" : @"Test Title"
                                     },
                             @"thread-id" : @"test1"
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
                             @"alert": @{@"body": @"Message Body", @"title": @"title"},
                             @"thread-id": @"test1"
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

    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [OneSignal setNotificationOpenedHandler:^(OSNotificationOpenedResult *result) {
        XCTAssertEqualObjects(result.notification.payload.additionalData[@"foo"], @"bar");
        XCTAssertEqual(result.action.type, OSNotificationActionTypeOpened);
        XCTAssertNil(result.action.actionID);
        openedWasFire = true;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    let userInfo = @{@"custom": @{
                      @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                      @"a": @{ @"foo": @"bar" }
                  }};
    
    let notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    let notifCenter = UNUserNotificationCenter.currentNotificationCenter;
    let notifCenterDelegate = notifCenter.delegate;
    
    // UNUserNotificationCenterDelegate method iOS 10 calls directly when a notification is opened.
    [notifCenterDelegate userNotificationCenter:notifCenter didReceiveNotificationResponse:notifResponse withCompletionHandler:^() {}];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue(openedWasFire);
    
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
    XCTAssertTrue(openedWasFire);
    */
}

// Testing iOS 10 - pre-2.4.0 button format - with os_data aps payload format
- (void)receivedCallbackWithButtonsWithUserInfo:(NSDictionary *)userInfo {
    __block BOOL receivedWasFire = false;

    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [OneSignal setNotificationWillShowInForegroundHandler:^(OSNotification *notification) {
        receivedWasFire = true;
        let actionButons = @[ @{@"id": @"id1", @"text": @"text1"} ];
        XCTAssertEqualObjects(notification.payload.actionButtons, actionButons);
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    let notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    let notifCenter = UNUserNotificationCenter.currentNotificationCenter;
    let notifCenterDelegate = notifCenter.delegate;
    
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateInactive;
    
    //iOS 10 calls UNUserNotificationCenterDelegate method directly when a notification is received while the app is in focus.
    [notifCenterDelegate userNotificationCenter:notifCenter
                        willPresentNotification:[notifResponse notification]
                          withCompletionHandler:^(UNNotificationPresentationOptions options) {}];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(receivedWasFire, true);
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
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
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
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
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    NSObjectOverrider.selectorNamesForInstantOnlyForFirstRun = [@[@"sendTagsToServer"] mutableCopy];
    
    [OneSignal sendTag:@"key" value:@"value"];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Do not try to send tag update yet as there isn't a player_id yet.
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 1);
    
    [UnitTestCommonMethods answerNotificationPrompt:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // A single POST player create call should be made with tags included.
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"tags"][@"key"], @"value");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
}

- (void)testPostNotification {
    [UnitTestCommonMethods initOneSignalAndThreadWait];
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
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
}

- (void)testPermissionChangedInSettingsOutsideOfApp {
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [self backgroundModesDisabledInXcode];
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    
    [OneSignal addPermissionObserver:observer];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"identifier"]);
    
    [self backgroundApp];
    [UnitTestCommonMethods setCurrentNotificationPermission:true];
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @15);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
    
    XCTAssertEqual(observer->last.from.accepted, false);
    XCTAssertEqual(observer->last.to.accepted, true);
}

- (void)testPermissionChangedOutsideOfAppOverWithNewSession {
    [self backgroundModesDisabledInXcode];
    
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    [self backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    [UnitTestCommonMethods setCurrentNotificationPermission:true];
    
    [NSDateOverrider advanceSystemTimeBy:30];
    UNUserNotificationCenterOverrider.notifTypesOverride = 0;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusDenied];
    
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // We should be making an on_session since we left the app for 30+ secounds
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"players/1234/on_session"));
    // The on_session call should have a notification_types of 0 to indicate no notification permissions.
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"notification_types"], @0);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"0000000000000000000000000000000000000000000000000000000000000000");
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
}

- (void) testOnSessionWhenResuming {
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // Don't make an on_session call if only out of the app for 20 secounds
    [self backgroundApp];
    NSDateOverrider.timeOffset = 10;
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    
    // Anything over 30 secounds should count as a session.
    [self backgroundApp];
    NSDateOverrider.timeOffset = 41;
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"players/1234/on_session"));
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 3);
}


- (void) testOnSessionOnColdStart {
    // 1. Open app
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // 2. Kill the app and wait 31 seconds
    [self backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [NSDateOverrider advanceSystemTimeBy:31];
    
    // 3. Open app
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // 4. Ensure the last network call is an on_session
    // Total calls - 2 ios_params + player create + on_session = 4
    XCTAssertEqualObjects(OneSignalClientOverrider.lastUrl, serverUrlWithPath(@"players/1234/on_session"));
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
}

// TODO: Add test accepting notification permission while player create is in flight.

// Tests that a slient content-available 1 notification doesn't trigger an on_session or count it has opened.
- (void)testContentAvailableDoesNotTriggerOpen  {
    UIApplicationOverrider.currentUIApplicationState = UIApplicationStateBackground;
    
    __block BOOL receivedWasFire = false;

    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [OneSignal setNotificationWillShowInForegroundHandler:^(OSNotification *result) {
        receivedWasFire = true;
    }];
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

- (UNNotificationCategory*)unNotificagionCategoryWithId:(NSString*)identifier {
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

/*
 Wrapper SDKs call OneSignal init method twice:
    1. App id is null
    2. App id should be valid
 NOTE: The init method uses flags initDone, didCallDownloadParameters, downloadedParameters and these prevent code from executing more than once in specific cases
       initDone BOOL is used to return early in the event of init being called more than once
       didCallDownloadParameters BOOL is used to determine whether iOS params have started being pulled down
       downloadedParameters BOOL is used to determine whether iOS params have successfully been pulled down
 */
- (void)testiOSParams_withNullAppIdInit_andValidAppIdInit {
    // 1. Open app and init with null app id
    [OneSignal setAppId:nil];
    [OneSignal setLaunchOptions:nil];
    [UnitTestCommonMethods foregroundApp];
    
    // 2. Make sure iOS params did not download, since app id was invalid
    XCTAssertFalse(OneSignal.didCallDownloadParameters);
    XCTAssertFalse(OneSignal.downloadedParameters);

    // 3. Init with valid app id
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    // 4. Make sure iOS params have been downloaded, since app_id is valid
    XCTAssertTrue(OneSignal.didCallDownloadParameters);
    XCTAssertTrue(OneSignal.downloadedParameters);
}

- (void)testAddingSharedKeysIfMissing {
    // 1. Init SDK as normal
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // 2. Remove shared keys to simulate the state of coming from a pre-2.12.1 version
    [OneSignalUserDefaults.initShared removeValueForKey:OSUD_APP_ID];
    [OneSignalUserDefaults.initShared removeValueForKey:OSUD_PLAYER_ID_TO];

    // 3. Restart app
    [UnitTestCommonMethods backgroundApp];
    [UnitTestCommonMethods clearStateForAppRestart:self];
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    // 4. Ensure values are present again
    XCTAssertNotNil([OneSignalUserDefaults.initShared getSavedSetForKey:OSUD_APP_ID defaultValue:nil]);
    XCTAssertNotNil([OneSignalUserDefaults.initShared getSavedSetForKey:OSUD_PLAYER_ID_TO defaultValue:nil]);
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
    XCTAssertEqualObjects(content.categoryIdentifier, @"__onesignal__dynamic__b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    // Make sure attachments were NOT added.
    //   We should not try to download attachemts as iOS is about to kill the extension and this will take to much time.
    XCTAssertNil(content.attachments);
}

-(void)testBuildOSRequest {
    let request = [OSRequestSendTagsToServer withUserId:@"12345" appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" tags:@{@"tag1" : @"test1", @"tag2" : @"test2"} networkType:[OneSignalHelper getNetType] withEmailAuthHashToken:nil];
    
    XCTAssert([request.parameters[@"app_id"] isEqualToString:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"]);
    XCTAssert([request.parameters[@"tags"][@"tag1"] isEqualToString:@"test1"]);
    XCTAssert([request.path isEqualToString:@"players/12345"]);
    
    let urlRequest = request.urlRequest;
    
    XCTAssert([urlRequest.URL.absoluteString isEqualToString:serverUrlWithPath(@"players/12345")]);
    XCTAssert([urlRequest.HTTPMethod isEqualToString:@"PUT"]);
    XCTAssert([urlRequest.allHTTPHeaderFields[@"Content-Type"] isEqualToString:@"application/json"]);
}

-(void)testInvalidJSONTags {
    [UnitTestCommonMethods initOneSignalAndThreadWait];
    
    //this test will also print invalid JSON warnings to console
    
    let invalidJson = @{@{@"invalid1" : @"invalid2"} : @"test"}; //Keys are required to be strings, this would crash the app if not handled appropriately
    
    let request = [OSRequestSendTagsToServer withUserId:@"12345" appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" tags:invalidJson networkType:[OneSignalHelper getNetType] withEmailAuthHashToken:nil];
    
    let urlRequest = request.urlRequest;
    
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

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
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
    [UnitTestCommonMethods answerNotificationPrompt:true];
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

// Checks to make sure that media URL's will not fail the extension-type check if they have query parameters
- (void)testHandlingMediaUrlExtensions {
    let testUrl = @"https://images.pexels.com/photos/104827/cat-pet-animal-domestic-104827.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=100";
    
    let cacheName = [OneSignalHelper downloadMediaAndSaveInBundle:testUrl];
    
    XCTAssertNotNil(cacheName);
}

/*
    Tests the privacy functionality to comply with the GDPR
*/
- (void)testPrivacyState {
    [NSBundleOverrider setPrivacyState:true];
    
    [self assertUserConsent];
    
    [NSBundleOverrider setPrivacyState:false];
}

- (void)testOverridePrivacyState {
    //since some wrapper SDK's wont use an info.plist, the SDK also provides a method that can also set the privacy consent setting
    
    [OneSignal setRequiresUserPrivacyConsent:true];
    
    [self assertUserConsent];
    
    [OneSignal setRequiresUserPrivacyConsent:false];
}

- (void)assertUserConsent {
    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    //indicates initialization was delayed
    XCTAssertNil(OneSignal.appId);
    
    XCTAssertTrue([OneSignal requiresUserPrivacyConsent]);
    
    let latestHttpRequest = OneSignalClientOverrider.lastUrl;
    
    [OneSignal sendTags:@{@"test" : @"test"}];
    
    //if lastUrl is null, isEqualToString: will return false, so perform an equality check as well
    XCTAssertTrue([OneSignalClientOverrider.lastUrl isEqualToString:latestHttpRequest] || latestHttpRequest == OneSignalClientOverrider.lastUrl);
    
    [OneSignal consentGranted:true];
    
    XCTAssertTrue([@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" isEqualToString:OneSignal.appId]);
    
    XCTAssertFalse([OneSignal requiresUserPrivacyConsent]);
}

//since apps may manually request push permission while OneSignal privacy consent is not granted,
//the SDK should not do anything with this token while permission is pending
//checks to make sure that, for example, OneSignal does not register the push token with the backend
- (void)testPushNotificationToken {
    [NSBundleOverrider setPrivacyState:true];
    
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    // Triggers the 30 fallback to register device right away.
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertNil(observer->last.from.userId);
    XCTAssertNil(observer->last.to.userId);
    XCTAssertFalse(observer->last.to.subscribed);
    
    [OneSignal setSubscription:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertFalse(observer->last.from.userSubscriptionSetting);
    XCTAssertFalse(observer->last.to.userSubscriptionSetting);
    // Device registered with OneSignal so now make pushToken available.
    XCTAssertNil(observer->last.to.pushToken);
    
    [NSBundleOverrider setPrivacyState:false];
}
  
//tests to make sure that UNNotificationCenter setDelegate: duplicate calls don't double-swizzle for the same object
// TODO: This test causes the UNUserNotificationCenter singleton's Delegate property to get nullified
// Unfortunately the fix is not as simple as just setting it back to the original when the test is done
// To avoid breaking other tests, this test should be executed last, and since tests are alphabetical order, adding Z's does this.
- (void)testZSwizzling {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    
    DummyNotificationCenterDelegate *delegate = [[DummyNotificationCenterDelegate alloc] init];
    
    IMP original = class_getMethodImplementation([delegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
    
    center.delegate = delegate;
    
    IMP swizzled = class_getMethodImplementation([delegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
    
    XCTAssertNotEqual(original, swizzled);
    
    //calling setDelegate: a second time on the same object should not re-exchange method implementations
    //thus the new method implementation should still be the same, swizzled == newSwizzled should be true
    center.delegate = delegate;
    
    IMP newSwizzled = class_getMethodImplementation([delegate class], @selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:));
    
    XCTAssertNotEqual(original, newSwizzled);
    XCTAssertEqual(swizzled, newSwizzled);
  
}

- (UNNotificationAttachment *)deliverNotificationWithJSON:(id)json {
    id notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:json];
    
    [[notifResponse notification].request.content setValue:@"some_category" forKey:@"categoryIdentifier"];
    
    UNMutableNotificationContent* content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];
    
    return content.attachments.firstObject;
}

- (id)exampleNotificationJSONWithMediaURL:(NSString *)urlString {
    return @{@"aps": @{
                     @"mutable-content": @1,
                     @"alert": @"Message Body"
                     },
             @"os_data": @{
                     @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                     @"buttons": @[@{@"i": @"id1", @"n": @"text1"}],
                     @"att": @{ @"id": urlString }
                     }};
}

- (void)testExtractFileExtensionFromFileNameQueryParameter {
    // we allow developers to add ?filename=test.jpg (for example) to attachment URL's in cases where there is no extension & no mime type
    // tests to make sure the SDK correctly extracts the file extension from the `filename` URL query parameter
    // NSURLSessionOverrider returns nil for this URL
    id jpgFormat = [self exampleNotificationJSONWithMediaURL:@"http://domain.com/secondFile?filename=test.jpg"];

    let downloadedJpgFilename = [self deliverNotificationWithJSON:jpgFormat].URL.lastPathComponent;
    XCTAssertTrue([downloadedJpgFilename.supportedFileExtension isEqualToString:@"jpg"]);
}

- (void)testExtractFileExtensionFromMimeType {
    //test to make sure the MIME type parsing works correctly
    //NSURLSessionOverrider returns image/png for this URL
    id pngFormat = [self exampleNotificationJSONWithMediaURL:@"http://domain.com/file"];

    let downloadedPngFilename = [self deliverNotificationWithJSON:pngFormat].URL.lastPathComponent;
    XCTAssertTrue([downloadedPngFilename.supportedFileExtension isEqualToString:@"png"]);
}

- (void)testFileExtensionPrioritizesFileNameParameter {
    //tests to make sure that the filename query parameter is prioritized above the MIME type and URL extension
    //this attachment URL will have a file extension, a MIME type, and a filename query parameter. It should prioritize the filename query parameter (png)
    //NSURLSessionOverrider returns image/png for this URL
    id gifFormat = [self exampleNotificationJSONWithMediaURL:@"http://domain.com/file.gif?filename=test.png"];
    
    let downloadedGifFilename = [self deliverNotificationWithJSON:gifFormat].URL.lastPathComponent;
    XCTAssertTrue([downloadedGifFilename.supportedFileExtension isEqualToString:@"png"]);
}

- (void)testExtractFileExtensionFromAnyParameter {
    //test to make sure the fallback of parsing all parameters for a file type works correctly
    //NSURLSessionOverrider returns an unallowed extension (heic) for this URL to test the fallback
    id pngFormat = [self exampleNotificationJSONWithMediaURL:@"http://domain.com/secondFile?file=test.png&media=image&type=.fakeextension"];

    let downloadedPngFilename = [self deliverNotificationWithJSON:pngFormat].URL.lastPathComponent;
    XCTAssertTrue([downloadedPngFilename.supportedFileExtension isEqualToString:@"png"]);
}

/*
    We now provide a method to prompt users to open push Settings
    If the user has turned off push notifications, when the developer
    calls the new promptForPushNotificationsWithUserResponse:fallbackToSettings:
    the SDK will open iOS Settings (iOS 10 or higher)
*/
- (void)testOpenNotificationSettings {
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    //set up the test so that the user has declined the prompt.
    //we can then call prompt with Settings fallback.
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    
    [self registerForPushNotifications];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [UnitTestCommonMethods answerNotificationPrompt:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(observer->last.to.accepted, false);
    
    //this should result in a dialog being shown, asking the user
    //if they want to open iOS settings for this app
    [OneSignal promptForPushNotificationsWithUserResponse:nil fallbackToSettings:true];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    //assert that the correct dialog was presented
    XCTAssertNotNil([OneSignalDialogControllerOverrider getCurrentDialog]);
    XCTAssertEqualObjects(OneSignalDialogControllerOverrider.getCurrentDialog.title, @"Open Settings");
    
    //answer 'Open Settings' on the prompt
    OneSignalDialogControllerOverrider.getCurrentDialog.completion(true);
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    //make sure the app actually tried to open settings
    XCTAssertNotNil(UIApplicationOverrider.lastOpenedUrl);
    XCTAssertEqualObjects(UIApplicationOverrider.lastOpenedUrl.absoluteString, UIApplicationOpenSettingsURLString);
}

//integration test that makes sure that if APNS doesn't respond within a certain
//window of time, the SDK will register the user with onesignal anyways.
- (void)testRegistersAfterNoApnsResponse {
    
    // simulates no response from APNS
    [UIApplicationOverrider setBlockApnsResponse:true];
    
    // Normally the SDK would wait at least 25 seconds to get a response
    // and 30 seconds between registration attempts.
    // This would be too long for a test, so we artificially set the
    // delay times to be very very short.
    [OneSignal setDelayIntervals:-1 withRegistrationDelay:-1];
    
    // add the subscription observer
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    // create an expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"onesignal_registration_wait"];
    expectation.expectedFulfillmentCount = 1;
    
    // do not answer the prompt (apns will not respond)
    [UnitTestCommonMethods setCurrentNotificationPermissionAsUnanswered];

    [OneSignal setAppSettings:@{kOSSettingsKeyAutoPrompt: @false}];
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // wait for the registration to be re-attempted.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    
    [self waitForExpectations:@[expectation] timeout:0.2];
    
    // If APNS didn't respond within X seconds, the SDK
    // should have registered the user with OneSignal
    // and should have a user ID
    XCTAssertTrue(observer->last.to.userId != nil);
}

/*
 To prevent tests from generating actual HTTP requests, we swizzle
 a method called executeRequest() in the OneSignalClient class
 
 However, this test ensures that HTTP retry logic occurs correctly.
 We have additionally swizzled NSURLSession to prevent real HTTP
 requests from being generated.
 
 TODO: Remove the OneSignalClientOverrider mock entirely and
 instead swizzle NSURLSession
 */
- (void)testHTTPClientTimeout {
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Switches from overriding OneSignalClient to using a
    // swizzled NSURLSession instead. This results in NSURLSession
    // mimicking a no-network connection state
    [OneSignalClientOverrider disableExecuteRequestOverride:true];
    
    let expectation = [self expectationWithDescription:@"timeout_test"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal sendTags:@{@"test_tag_key" : @"test_tag_value"} onSuccess:^(NSDictionary *result) {
        XCTFail(@"Success should not be called");
    } onFailure:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    [self waitForExpectations:@[expectation] timeout:0.5];
    
    // revert the swizzle back to the standard state for tests
    [OneSignalClientOverrider disableExecuteRequestOverride:false];
}

// Regression test to ensure improper button JSON format
// does not cause a crash (iOS SDK issue #401)
- (void)testInvalidButtonFormat {
    NSDictionary *newFormat = @{@"aps": @{
                             @"mutable-content": @1,
                             @"alert": @"Message Body"
                             },
                     @"os_data": @{
                             @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                             @"buttons": @[@{@"i": @"id1", @"title": @"text1"}],
                             @"att": @{ @"id": @"http://domain.com/file.jpg" }
                             }};
    
    let notification = [OSNotificationPayload parseWithApns:newFormat];
    
    XCTAssertTrue(notification.actionButtons.count == 0);
}

- (void)testSetExternalUserIdWithRegistration {
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];

    [UnitTestCommonMethods initOneSignalAndThreadWait];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], TEST_EXTERNAL_USER_ID);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestRegisterUser class]));
}

- (void)testSetExternalUserIdAfterRegistration {
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];

    [UnitTestCommonMethods runBackgroundThreads];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], TEST_EXTERNAL_USER_ID);
}

- (void)testRemoveExternalUserId {
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];

    [UnitTestCommonMethods initOneSignalAndThreadWait];

    [OneSignal removeExternalUserId];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], @"");
}

// Tests to make sure that the SDK will not send an external ID if it already successfully sent the same ID
- (void)testDoesntSendExistingExternalUserIdAfterRegistration {
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];

    [UnitTestCommonMethods initOneSignalAndThreadWait];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestRegisterUser class]));

    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];

    // the PUT request to set external ID should not happen since the external ID
    // is the same as it was during registration
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestRegisterUser class]));
}

- (void)testDoesntSendExistingExternalUserIdBeforeRegistration {
    //mimics a previous session where the external user ID was set
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EXTERNAL_USER_ID withValue:TEST_EXTERNAL_USER_ID];

    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];

    [UnitTestCommonMethods initOneSignalAndThreadWait];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestRegisterUser class]));

    // the registration request should not have included external user ID
    // since it had been set already to the same value in a previous session
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"]);
}

- (void)testSetExternalUserId_forPush_withCompletion {
    // 1. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 2. Call setExternalUserId with callbacks
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID withCompletion:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Make sure only push external id was attempted to be set since no email was set yet
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
    XCTAssertNil(self.CALLBACK_EMAIL_EXTERNAL_USER_ID);
}

- (void)testSetExternalUserId_forPushAndEmail_withCompletion {
    // 1. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 2. Set email
    [OneSignal setEmail:TEST_EMAIL];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Call setExternalUserId with callbacks
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID withCompletion:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Make sure push and email external id were updated in completion callback
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
    XCTAssertEqual(self.CALLBACK_EMAIL_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
}

- (void)testSetExternalUserId_forPush_afterLogoutEmail_withCompletion {
    // 1. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 2. Set email
    [OneSignal setEmail:TEST_EMAIL];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Call setExternalUserId with completion callback
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID withCompletion:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Make sure push and email external id were updated in completion callback
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
    XCTAssertEqual(self.CALLBACK_EMAIL_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);

    // 5. Clear out external user id callback ids
    self.CALLBACK_EXTERNAL_USER_ID = nil;
    self.CALLBACK_EMAIL_EXTERNAL_USER_ID = nil;

    // 6. Log out email
    [OneSignal logoutEmail];
    [UnitTestCommonMethods runBackgroundThreads];

    // 7. Call setExternalUserId with completion callback
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID withCompletion:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 8. Make sure push external id was updated in completion callback
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
    XCTAssertNil(self.CALLBACK_EMAIL_EXTERNAL_USER_ID);
}

- (void)testOverwriteSameExternalUserId_forPushAndEmail_withCompletion {
    // 1. Cache the same external user ids for push and email channel
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EXTERNAL_USER_ID withValue:TEST_EXTERNAL_USER_ID];
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:TEST_EXTERNAL_USER_ID];

    // 2. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 3. Set email
    [OneSignal setEmail:TEST_EMAIL];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Call setExternalUserId with callbacks
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID withCompletion:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 5. Make sure only push external id was attempted to be set since no email was set yet
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
    XCTAssertEqual(self.CALLBACK_EMAIL_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
}

- (void)testOverwriteDifferentExternalUserId_forPushAndEmail_withCompletion {
    // 1. Cache different same external user ids for push and email channel
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EXTERNAL_USER_ID withValue:@"12345"];
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:@"12345"];

    // 2. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 3. Set email
    [OneSignal setEmail:TEST_EMAIL];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Call setExternalUserId with callbacks
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID withCompletion:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 5. Make sure only push external id was attempted to be set since no email was set yet
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
    XCTAssertEqual(self.CALLBACK_EMAIL_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
}

- (void)testOverwriteExternalUserId_forPushAndEmail_withCompletion {
    // 1. Cache two different external user ids for push and email channel
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EXTERNAL_USER_ID withValue:@"12345"];
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:TEST_EXTERNAL_USER_ID];

    // 2. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 3. Set email
    [OneSignal setEmail:TEST_EMAIL];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Call setExternalUserId with callbacks
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID withCompletion:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 5. Make sure only push external id was attempted to be set since no email was set yet
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
    XCTAssertEqual(self.CALLBACK_EMAIL_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
}

- (void)testOverwriteEmailExternalUserId_forPushAndEmail_withCompletion {
    // 1. Cache two different external user ids for push and email channel
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EXTERNAL_USER_ID withValue:TEST_EXTERNAL_USER_ID];
    [OneSignalUserDefaults.initStandard saveStringForKey:OSUD_EMAIL_EXTERNAL_USER_ID withValue:@"12345"];

    // 2. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 3. Set email
    [OneSignal setEmail:TEST_EMAIL];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Call setExternalUserId with callbacks
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID withCompletion:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = TEST_EXTERNAL_USER_ID;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 5. Make sure only push external id was attempted to be set since no email was set yet
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
    XCTAssertEqual(self.CALLBACK_EMAIL_EXTERNAL_USER_ID, TEST_EXTERNAL_USER_ID);
}

- (void)testRemoveExternalUserId_forPush {
    // 1. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 2. Set external user id
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Make sure last request was external id and had the correct external id being used in the request payload
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], TEST_EXTERNAL_USER_ID);

    // 4. Remove the external user id
    [OneSignal removeExternalUserId];
    [UnitTestCommonMethods runBackgroundThreads];

    // 5. Make sure last request was external id and the external id being used was an empty string
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], @"");
}

- (void)testRemoveExternalUserId_forPushAndEmail {
    // 1. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 2. Set email
    [OneSignal setEmail:TEST_EMAIL];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Set external user id
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Make sure last request was external id and had the correct external id being used in the request payload
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], TEST_EXTERNAL_USER_ID);

    // 5. Remove the external user id
    [OneSignal removeExternalUserId];
    [UnitTestCommonMethods runBackgroundThreads];

    // 6. Make sure last request was external id and the external id being used was an empty string
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], @"");
}

- (void)testRemoveExternalUserId_forPush_withCompletion {
    // 1. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 2. Set external user id
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Make sure last request was external id and had the correct external id being used in the request payload
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], TEST_EXTERNAL_USER_ID);

    // 4. Remove the external user id with a callack implemented
    [OneSignal removeExternalUserId:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = @"";

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = @"";
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 5. Make sure last request was external id and the external id being used was an empty string
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], @"");

    // 6. Make sure completion handler was called, push external id is an empty string and email external id is nil since email as never set
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, @"");
    XCTAssertNil(self.CALLBACK_EMAIL_EXTERNAL_USER_ID);
}

- (void)testRemoveExternalUserId_forPushAndEmail_withCompletion {
    // 1. Init OneSignal
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    // 2. Set email
    [OneSignal setEmail:TEST_EMAIL];
    [UnitTestCommonMethods runBackgroundThreads];

    // 3. Set external user id
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];
    [UnitTestCommonMethods runBackgroundThreads];

    // 4. Make sure last request was external id and had the correct external id being used in the request payload
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], TEST_EXTERNAL_USER_ID);

    // 5. Remove the external user id
    [OneSignal removeExternalUserId:^(NSDictionary *results) {
        if (results[@"push"] && results[@"push"][@"success"] && [results[@"push"][@"success"] boolValue])
            self.CALLBACK_EXTERNAL_USER_ID = @"";

        if (results[@"email"] && results[@"email"][@"success"] && [results[@"email"][@"success"] boolValue])
            self.CALLBACK_EMAIL_EXTERNAL_USER_ID = @"";
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // 6. Make sure last request was external id and the external id being used was an empty string
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequestType, NSStringFromClass([OSRequestUpdateExternalUserId class]));
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"external_user_id"], @"");

    // 7. Make sure completion handler was called, push and email external ids are empty strings
    XCTAssertEqual(self.CALLBACK_EXTERNAL_USER_ID, @"");
    XCTAssertEqual(self.CALLBACK_EMAIL_EXTERNAL_USER_ID, @"");
}

// Tests to make sure that the SDK clears out registered categories when it has saved
// more than MAX_CATEGORIES_SIZE number of UNNotificationCategory objects. Also tests
// to make sure that the SDK generates correct
- (void)testCategoryControllerClearsNotificationCategories {
    let controller = [OneSignalNotificationCategoryController new];

    NSMutableArray<NSString *> *generatedIds = [NSMutableArray new];

    for (int i = 0; i < MAX_CATEGORIES_SIZE + 3; i++) {
        let testId = NSUUID.UUID.UUIDString;

        let newId = [controller registerNotificationCategoryForNotificationId:testId];

        let expected = [NSString stringWithFormat:@"__onesignal__dynamic__%@", testId];

        XCTAssertEqualObjects(newId, expected);

        [generatedIds addObject:newId];
    }

    let currentlySavedCategoryIds = [controller existingRegisteredCategoryIds];

    XCTAssertEqual(currentlySavedCategoryIds.count, MAX_CATEGORIES_SIZE);

    for (int i = 0; i < MAX_CATEGORIES_SIZE; i++)
        XCTAssertEqualObjects(generatedIds[generatedIds.count - 1 - i], currentlySavedCategoryIds[currentlySavedCategoryIds.count - 1 - i]);
}

- (void)testNotificationWithButtonsRegistersUniqueCategory {
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal setLaunchOptions:nil];
    [UnitTestCommonMethods runBackgroundThreads];

    let notification = (NSDictionary *)[self exampleNotificationJSONWithMediaURL:@"https://www.onesignal.com"];

    let notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:notification];

    let content = [OneSignal didReceiveNotificationExtensionRequest:[notifResponse notification].request withMutableNotificationContent:nil];

    let ids = OneSignalNotificationCategoryController.sharedInstance.existingRegisteredCategoryIds;

    XCTAssertEqual(ids.count, 1);

    XCTAssertEqualObjects(ids.firstObject, @"__onesignal__dynamic__b2f7f966-d8cc-11e4-bed1-df8f05be55ba");

    XCTAssertEqualObjects(content.categoryIdentifier, @"__onesignal__dynamic__b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
}

- (void)testAllowsIncreasedAPNSTokenSize
{
    [UIApplicationOverrider setAPNSTokenLength:64];

    [UnitTestCommonMethods clearStateForAppRestart:self];
    [UnitTestCommonMethods initOneSignalAndThreadWait];

    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], UIApplicationOverrider.mockAPNSToken);
}

- (void)testHexStringFromDataWithInvalidValues {
    XCTAssertNil([NSString hexStringFromData:nil]);
    XCTAssertNil([NSString hexStringFromData:NULL]);
    XCTAssertNil([NSString hexStringFromData:[NSData new]]);
}


- (void)testGetDeviceVariant {
    // Simulator iPhone
    var deviceModel = [OneSignalHelper getDeviceVariant];
    XCTAssertEqualObjects(@"Simulator iPhone", deviceModel);
    
    // Catalyst ("Mac")
    [UIDeviceOverrider setSystemName:@"Mac OS X"];
    deviceModel = [OneSignalHelper getDeviceVariant];
    XCTAssertEqualObjects(@"Mac", deviceModel);
    
    // Real iPhone
    [OneSignalHelperOverrider setSystemInfoMachine:@"iPhone9,3"];
    deviceModel = [OneSignalHelper getDeviceVariant];
    XCTAssertEqualObjects(@"iPhone9,3", deviceModel);
}
@end
