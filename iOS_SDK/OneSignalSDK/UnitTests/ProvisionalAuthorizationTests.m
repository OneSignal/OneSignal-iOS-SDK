/*
 Modified MIT License

 Copyright 2017 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <XCTest/XCTest.h>
// TODO: Commented out 🧪
//#import "UnitTestCommonMethods.h"
//#import "OneSignalExtensionBadgeHandler.h"
//#import "UNUserNotificationCenterOverrider.h"
//#import "UNUserNotificationCenter+OneSignal.h"
//#import "OneSignalHelperOverrider.h"
//#import "OneSignalHelper.h"
//#import "OneSignalInternal.h"
//#import "OneSignalCommonDefines.h"
//#import "OneSignalClientOverrider.h"
//
//@interface ProvisionalAuthorizationTests : XCTestCase
//
//@end
//
//@implementation ProvisionalAuthorizationTests
//
///*
// Put setup code here
// This method is called before the invocation of each test method in the class
// */
//- (void)setUp {
//    [super setUp];
//    [UnitTestCommonMethods beforeEachTest:self];
//}
//
///*
// Put teardown code here
// This method is called after the invocation of each test method in the class
// */
//- (void)tearDown {
//    [super tearDown];
//}
//
//- (OSPermissionStateTestObserver *)setupProvisionalTest {
//    [UnitTestCommonMethods clearStateForAppRestart:self];
//
//    [UNUserNotificationCenterOverrider setNotifTypesOverride:0];
//    [UNUserNotificationCenterOverrider setAuthorizationStatus:@0];
//
//    OneSignalHelperOverrider.mockIOSVersion = 12;
//
//    [OneSignalClientOverrider setShouldUseProvisionalAuth:true];
//
//    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
//    [OneSignal addPermissionObserver:observer];
//    return observer;
//}
//
///*
// Tests to make sure that apps set to use Provisional authorization work & register correctly
// */
//- (void)testProvisionalPermissionState {
//    if (@available(iOS 12, *)) {
//        OSPermissionStateTestObserver* observer = [self setupProvisionalTest];
//        [UNUserNotificationCenterOverrider setShouldSetProvisionalAuthorizationStatus:true];
//
//        OSSubscriptionStateTestObserver *subscriptionObserver = [OSSubscriptionStateTestObserver new];
//        [OneSignal addSubscriptionObserver:subscriptionObserver];
//
//        [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//        let state = [OneSignal getPermissionSubscriptionState];
//        XCTAssertFalse(state.permissionStatus.reachable);
//        [UnitTestCommonMethods runBackgroundThreads];
//
//        [UNUserNotificationCenterOverrider fireLastRequestAuthorizationWithGranted:true];
//        [UnitTestCommonMethods runBackgroundThreads];
//
//        let options = PROVISIONAL_UNAUTHORIZATIONOPTION + DEFAULT_UNAUTHORIZATIONOPTIONS;
//
//        XCTAssertTrue(UNUserNotificationCenterOverrider.lastRequestedAuthorizationOptions == options);
//
//        XCTAssertTrue(observer->last.to.provisional);
//        XCTAssertFalse(observer->last.from.provisional);
//
//        XCTAssertTrue(observer->last.to.reachable);
//        XCTAssertFalse(observer->last.from.reachable);
//
//        XCTAssertEqual(observer->last.from.status, OSNotificationPermissionNotDetermined);
//        XCTAssertEqual(observer->last.to.status, OSNotificationPermissionProvisional);
//
//        //make sure registration occurred
//        XCTAssertEqual(subscriptionObserver->last.to.userId, @"1234");
//    }
//}
//
///*
// Tests to make sure that apps can still prompt for regular
// Push authorization when they use Provisional authorization
// */
//- (void)testPromptWorksWithProvisional {
//    if (@available(iOS 12, *)) {
//        OSPermissionStateTestObserver* observer = [self setupProvisionalTest];
//        [UNUserNotificationCenterOverrider setShouldSetProvisionalAuthorizationStatus:true];
//
//        [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//        [UNUserNotificationCenterOverrider fireLastRequestAuthorizationWithGranted:true];
//        [UnitTestCommonMethods runBackgroundThreads];
//
//        XCTAssertTrue(observer->last.to.provisional);
//        XCTAssertFalse(observer->last.from.provisional);
//
//        XCTAssertTrue(observer->last.to.reachable);
//        XCTAssertFalse(observer->last.from.reachable);
//
//        XCTAssertEqual(observer->last.from.status, OSNotificationPermissionNotDetermined);
//        XCTAssertEqual(observer->last.to.status, OSNotificationPermissionProvisional);
//
//        [OneSignal promptForPushNotificationsWithUserResponse:nil];
//        [UnitTestCommonMethods runBackgroundThreads];
//
//        [UnitTestCommonMethods answerNotificationPrompt:true];
//        [UnitTestCommonMethods runBackgroundThreads];
//
//        XCTAssertTrue(observer->last.to.reachable);
//        XCTAssertTrue(observer->last.from.reachable);
//
//        XCTAssertFalse(UNUserNotificationCenterOverrider.lastRequestedAuthorizationOptions == PROVISIONAL_UNAUTHORIZATIONOPTION);
//        XCTAssertFalse(observer->last.to.provisional);
//        XCTAssertTrue(observer->last.from.provisional);
//
//        XCTAssertEqual(observer->last.to.status, OSNotificationPermissionAuthorized);
//    }
//}
//
///*
// If the app sets autoPrompt to true, there is no point in requesting provisional authorization
//    thus, the SDK should never request it if autoPrompt = true
// */
//- (void)testProvisionalOverridenByAutoPrompt {
//    if (@available(iOS 12, *)) {
//        OSPermissionStateTestObserver* observer = [self setupProvisionalTest];
//
//        [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//        //ensure the SDK did not request provisional authorization
//        XCTAssertFalse(observer->last.to.provisional);
//        XCTAssertFalse(observer->last.from.provisional);
//    }
//}
//
//- (void)testNoProvisionalAuthorization {
//    if (@available(iOS 12, *)) {
//        [UnitTestCommonMethods clearStateForAppRestart:self];
//
//        [UNUserNotificationCenterOverrider setNotifTypesOverride:0];
//        [UNUserNotificationCenterOverrider setAuthorizationStatus:@0];
//
//        OneSignalHelperOverrider.mockIOSVersion = 12;
//
//        [OneSignalClientOverrider setShouldUseProvisionalAuth:false];
//
//        OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
//        [OneSignal addPermissionObserver:observer];
//
//        [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//        //ensure the SDK did not request provisional authorization
//        XCTAssertFalse(observer->last.to.provisional);
//        XCTAssertFalse(observer->last.from.provisional);
//
//        XCTAssertEqual(observer->last.to.status, OSNotificationPermissionNotDetermined);
//    }
//}
//
//- (void)testOSDeviceHasEmailAddress {
//    NSString *testEmail = @"test@onesignal.com";
//
//    [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//    XCTAssertNil([OneSignal getDeviceState].emailAddress);
//
//    [OneSignal setEmail:testEmail];
//    [UnitTestCommonMethods runBackgroundThreads];
//
//    XCTAssertEqual(testEmail, [OneSignal getDeviceState].emailAddress);
//}
//
//- (void)testOSDeviceHasEmailId {
//    NSString *testEmail = @"test@onesignal.com";
//
//    [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//    XCTAssertNil([OneSignal getDeviceState].emailAddress);
//
//    [OneSignal setEmail:testEmail];
//    [UnitTestCommonMethods runBackgroundThreads];
//
//    XCTAssertNotNil([OneSignal getDeviceState].emailAddress);
//}
//
//- (void)testOSDeviceHasUserId {
//    [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//    XCTAssertNotNil([OneSignal getDeviceState].userId);
//}
//
//- (void)testOSDeviceHasPushToken {
//    [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//    XCTAssertNotNil([OneSignal getDeviceState].pushToken);
//}
//
//- (void)testOSDeviceSubscribed {
//    [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//    XCTAssertTrue([OneSignal getDeviceState].isSubscribed);
//}
//
//- (void)testOSDeviceUserSubscribed {
//    [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//    XCTAssertFalse([OneSignal getDeviceState].isPushDisabled);
//}
//
//- (void)testOSDeviceNotificationReachable {
//    [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//    XCTAssertTrue([OneSignal getDeviceState].hasNotificationPermission);
//}
//
//- (void)testOSDeviceHasNotificationPermissionStatus {
//    [UnitTestCommonMethods initOneSignal_andThreadWait];
//
//    XCTAssertEqual(OSNotificationPermissionAuthorized, [OneSignal getDeviceState].notificationPermissionStatus);
//}
//
//@end
