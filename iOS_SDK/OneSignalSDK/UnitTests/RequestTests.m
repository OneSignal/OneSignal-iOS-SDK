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
#import "Requests.h"
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OneSignalClientOverrider.h"
#import "UnitTestCommonMethods.h"
#import "OSSubscription.h"
#import "OSEmailSubscription.h"
#import "UIApplicationOverrider.h"
#import "NSObjectOverrider.h"
#import "OneSignalHelperOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "NSBundleOverrider.h"
#import "NSUserDefaultsOverrider.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalTracker.h"

@interface RequestTests : XCTestCase

@end

@implementation RequestTests {
    NSString *testAppId;
    NSString *testUserId;
    NSString *testEmailUserId;
    NSString *testMessageId;
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    testAppId = @"test_app_id";
    testUserId = @"test_user_id";
    testEmailUserId = @"test_email_user_id";
    testMessageId = @"test_message_id";
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [UnitTestCommonMethods beforeAllTest];
    
    [OneSignalClientOverrider runBackgroundThreads];
}

NSString *urlStringForRequest(OneSignalRequest *request) {
    return correctUrlWithPath(request.path);
}

NSString *correctUrlWithPath(NSString *path) {
    return [[SERVER_URL stringByAppendingString:API_VERSION] stringByAppendingString:path];
}

- (void)testBuildGetTags {
    let request = [OSRequestGetTags withUserId:testUserId appId:testAppId].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@?app_id=%@", testUserId, testAppId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testBuildGetIosParams {
    let request = [OSRequestGetIosParams withUserId:testUserId appId:testAppId].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"apps/%@/ios_params.js?player_id=%@", testAppId, testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testBuildPostNotification {
    let request = [OSRequestPostNotification withAppId:testAppId withJson:[@{} mutableCopy]].request;
    
    let correctUrl = correctUrlWithPath(@"notifications");
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testSendTags {
    let request = [OSRequestSendTagsToServer withUserId:testUserId appId:testAppId tags:@{} networkType:@0 withEmailAuthHashToken:nil].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testUpdateDeviceToken {
    let request = [OSRequestUpdateDeviceToken withUserId:testUserId appId:testAppId deviceToken:nil notificationTypes:nil withParentId:nil emailAuthToken:nil email:nil].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testCreateDevice {
    let request = [OSRequestCreateDevice withAppId:testAppId withDeviceType:@0 withEmail:nil withPlayerId:nil withEmailAuthHash:nil].request;
    
    let correctUrl = correctUrlWithPath(@"players");
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testLogoutEmail {
    let request = [OSRequestLogoutEmail withAppId:testAppId emailPlayerId:testEmailUserId devicePlayerId:testUserId emailAuthHash:nil].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/email_logout", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testUpdateNotificationTypes {
    let request = [OSRequestUpdateNotificationTypes withUserId:testUserId appId:testAppId notificationTypes:@0].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testSendPurchases {
    let standardRequest = [OSRequestSendPurchases withUserId:testUserId appId:testAppId withPurchases:@[]].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_purchase", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:standardRequest.URL.absoluteString]);
    
    let emailRequest = [OSRequestSendPurchases withUserId:testUserId emailAuthToken:@"" appId:testAppId withPurchases:@[]].request;
    
    XCTAssertTrue([correctUrl isEqualToString:emailRequest.URL.absoluteString]);
}

- (void)testSubmitNotificationOpened {
    let request = [OSRequestSubmitNotificationOpened withUserId:testUserId appId:testAppId wasOpened:true messageId:testMessageId].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"notifications/%@", testMessageId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testRegisterUser {
    let request = [OSRequestRegisterUser withData:@{} userId:testUserId].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_session", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testSyncHashedEmail {
    let request = [OSRequestSyncHashedEmail withUserId:testUserId appId:testAppId email:@"" networkType:@1].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testSendLocation {
    os_last_location *location = (os_last_location*)malloc(sizeof(os_last_location));
    
    location->verticalAccuracy = 0.0;
    location->horizontalAccuracy = 0.0;
    location->cords.latitude = 0.0;
    location->cords.longitude = 0.0;
    
    let request = [OSRequestSendLocation withUserId:testUserId appId:testAppId location:location networkType:@0 backgroundState:true emailAuthHashToken:nil].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.URL.absoluteString]);
}

- (void)testOnFocus {
    let firstRequest = [OSRequestOnFocus withUserId:testUserId appId:testAppId badgeCount:@0 emailAuthToken:nil].request;
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:firstRequest.URL.absoluteString]);
    
    let secondRequest = [OSRequestOnFocus withUserId:testUserId appId:testAppId state:@"" type:@0 activeTime:@0 netType:@0 emailAuthToken:nil].request;
    
    let secondCorrectUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_focus", testUserId]);
    
    XCTAssertTrue([secondCorrectUrl isEqualToString:secondRequest.URL.absoluteString]);
}



@end
