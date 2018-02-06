//
//  EmailTests.m
//  UnitTests
//
//  Created by Brad Hesse on 1/30/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OneSignalClientOverrider.h"
#import "UnitTestCommonMethods.h"
#import "OSSubscription.h"
#import "UIApplicationOverrider.h"
#import "NSObjectOverrider.h"
#import "OneSignalHelperOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "NSBundleOverrider.h"
#import "NSUserDefaultsOverrider.h"
#import "OneSignalCommonDefines.h"


@interface OneSignal ()
void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message);
+ (NSString *)mEmailUserId;
+ (NSString *)mEmailAuthToken;
@end

@interface EmailTests : XCTestCase

@end

@implementation EmailTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [UnitTestCommonMethods beforeAllTest];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEmailValidation {
    XCTAssertFalse([OneSignalHelper isValidEmail:@"test@test"]);
    
    XCTAssertTrue([OneSignalHelper isValidEmail:@"john.doe233@unlv.nevada.edu"]);
    
    XCTAssertFalse([OneSignalHelper isValidEmail:@"testing123@22."]);
}

- (void)testSetAuthenticatedEmail {
    
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
    
    //the userId should already be set at this point, check to make sure.
    XCTAssertEqualObjects(observer->last.to.userId, @"1234");
    
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c" withSuccess:nil withFailure:nil];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    //check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNotNil([[NSUserDefaults standardUserDefaults] objectForKey:EMAIL_USERID]);
    XCTAssertNotNil([[NSUserDefaults standardUserDefaults] objectForKey:EMAIL_AUTH_CODE]);
    
    //check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"parent_player_id"], @"1234");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"email"], @"test@test.com");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"email_auth_hash"], @"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c");
    
    //we will change the email and make sure the HTTP call to update the device token is made
    [OneSignal setEmail:@"test2@test.com" withEmailAuthHashToken:@"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c" withSuccess:nil withFailure:nil];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    //check to make sure the server gets updated with the new email
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"test2@test.com");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"email_auth_hash"], @"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c");
    
    XCTAssertEqual([OneSignal mEmailUserId], @"1234");
    XCTAssertEqual([OneSignal mEmailAuthToken], @"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c");
    
    [self logoutEmail];
    
    XCTAssertNil([OneSignal mEmailUserId]);
    XCTAssertNil([OneSignal mEmailAuthToken]);
}

- (void)testUnauthenticatedEmail {
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
    
    //the userId should already be set at this point, check to make sure.
    XCTAssertEqualObjects(observer->last.to.userId, @"1234");
    
    [OneSignal setUnauthenticatedEmail:@"test@test.com" withSuccess:nil withFailure:nil];
    
    [UnitTestCommonMethods runBackgroundThreads];
    NSLog(@"LAST REQ: %@", OneSignalClientOverrider.lastHTTPRequest);
    //check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"parent_player_id"], @"1234");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"email"], @"test@test.com");
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"email_auth_hash"]);
    
    //now we will change the unauthenticated email to something else
    [OneSignal setEmail:@"test2@test.com" withEmailAuthHashToken:nil withSuccess:nil withFailure:nil];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    //check to make sure the server gets updated with the new email
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"test2@test.com");
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"email_auth_hash"]);
    
    XCTAssertEqual([OneSignal mEmailUserId], @"1234");
    XCTAssertNil([OneSignal mEmailAuthToken]);
    
    [self logoutEmail];
    
    XCTAssertNil([OneSignal mEmailUserId]);
    XCTAssertNil([OneSignal mEmailAuthToken]);
}

- (void)testInvalidEmail {
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
    
    //the userId should already be set at this point, check to make sure.
    XCTAssertEqualObjects(observer->last.to.userId, @"1234");
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setUnauthenticatedEmail:@"bad_email" withSuccess:^{
        XCTFail(@"setEmail: should reject invalid emails");
        
    } withFailure:^(NSError *error) {
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
}

- (void)logoutEmail {
    //test email logout
    let expectation = [self expectationWithDescription:@"email_logout"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal logoutEmailWithSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail("Failed with error: %@", error);
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
}

- (void)testMultipleRequests {
    let first = [OSRequestGetTags withUserId:@"test1" appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    let second = [OSRequestGetTags withUserId:@"test2" appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    let expectation = [self expectationWithDescription:@"multiple_requests"];
    
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignalClient.sharedClient executeSimultaneousRequests:@{@"first" : first, @"second" : second} withSuccess:^(NSDictionary<NSString *,NSDictionary *> *results) {
        [expectation fulfill];
    } onFailure:^(NSDictionary<NSString *,NSError *> *errors) {
        XCTFail("Failed with error: %@", errors);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.5];
}

@end
