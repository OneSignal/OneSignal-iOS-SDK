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
#import "OSEmailSubscription.h"
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
    
    [OneSignalClientOverrider runBackgroundThreads];
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
    
    [self setupEmailTest];
    
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
    
    [self setupEmailTest];
    
    [OneSignal setEmail:@"test@test.com" withSuccess:nil withFailure:nil];
    
    [UnitTestCommonMethods runBackgroundThreads];
    NSLog(@"LAST REQ: %@", OneSignalClientOverrider.lastHTTPRequest);
    //check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"parent_player_id"], @"1234");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"email"], @"test@test.com");
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"email_auth_hash"]);
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    //now we will change the unauthenticated email to something else
    [OneSignal setEmail:@"test2@test.com" withEmailAuthHashToken:nil withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"An error occurred: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    NSLog(@"LAST HTTP TYPE: %@", OneSignalClientOverrider.lastHTTPRequestType);
    NSLog(@"LAST HTTP REQ: %@", OneSignalClientOverrider.lastHTTPRequest);
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
    [self setupEmailTest];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setEmail:@"bad_email" withSuccess:^{
        XCTFail(@"setEmail: should reject invalid emails");
        
    } withFailure:^(NSError *error) {
        XCTAssertNotNil(error);
        
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


// tests to make sure the SDK correctly rejects setEmail when authToken == nil if
// the auth token is required (via iOS params file) for this application
- (void)testRequiresEmailAuth {
    [OneSignalClientOverrider setRequiresEmailAuth:true];
    
    [self setupEmailTest];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 3;
    
    //this should work since we are providing a token
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"test_hash_token" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered error: %@", error);
    }];
    
    //logout to clear the email
    [OneSignal logoutEmailWithSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered error: %@", error);
    }];
    
    //this should fail since require_email_auth == true and we aren't providing an auth token
    [OneSignal setEmail:@"test@test.com" withSuccess:^{
        XCTFail(@"Email authentication should be required.");
    } withFailure:^(NSError *error) {
        XCTAssertNotNil(error);
        
        [expectation fulfill];
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    //reset so we don't interfere with other tests
    [OneSignalClientOverrider setRequiresEmailAuth:false];
}

- (void)testDoesNotRequireEmailAuth {
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [OneSignalClientOverrider setRequiresEmailAuth:false];
    
    [self setupEmailTest];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setEmail:@"testEmail@test.com" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered error: %@", error);
    }];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    // Triggers the 30 fallback to register device right away.
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    
    
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
}

- (void)setupEmailTest {
    // Restart App
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    
    // Triggers the 30 fallback to register device right away.
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
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

- (void)testSubscriptionState {
    [OneSignalClientOverrider setRequiresEmailAuth:true];
    
    [self setupEmailTest];
    
    let unsubscribedSubscriptionStatus = [OneSignal getPermissionSubscriptionState].emailSubscriptionStatus;
    
    XCTAssertNil(unsubscribedSubscriptionStatus.emailAuthCode);
    XCTAssertNil(unsubscribedSubscriptionStatus.emailAddress);
    XCTAssertNil(unsubscribedSubscriptionStatus.emailUserId);
    XCTAssertFalse(unsubscribedSubscriptionStatus.subscribed);
    
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 2;
    
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"test-hash-token" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered an error: %@", error);
    }];
    
    let loggedInSubscriptionStatus = [OneSignal getPermissionSubscriptionState].emailSubscriptionStatus;
    
    XCTAssertEqual(loggedInSubscriptionStatus.emailUserId, @"1234");
    XCTAssertEqual(loggedInSubscriptionStatus.emailAddress, @"test@test.com");
    XCTAssertEqual(loggedInSubscriptionStatus.emailAuthCode, @"test-hash-token");
    XCTAssertEqual(loggedInSubscriptionStatus.subscribed, true);
    
    [OneSignal logoutEmailWithSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered an error: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    let loggedOutSubscriptionStatus = [OneSignal getPermissionSubscriptionState].emailSubscriptionStatus;
    
    XCTAssertNil(loggedOutSubscriptionStatus.emailAuthCode);
    XCTAssertNil(loggedOutSubscriptionStatus.emailAddress);
    XCTAssertNil(loggedOutSubscriptionStatus.emailUserId);
    XCTAssertFalse(loggedOutSubscriptionStatus.subscribed);
    
    //reset so we don't interfere with other tests
    [OneSignalClientOverrider setRequiresEmailAuth:false];
}

- (void)testEmailSubscriptionObserver {
    [UnitTestCommonMethods runBackgroundThreads];
    
    let observer = [OSEmailSubscriptionStateTestObserver new];
    [OneSignal addEmailSubscriptionObserver:observer];
    
    [OneSignalClientOverrider setRequiresEmailAuth:true];
    
    [self setupEmailTest];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"test-hash-token" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered error: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    NSLog(@"CHECKING REQUIRES EMAIL AUTH");
    XCTAssertEqual(observer->last.to.emailAddress, @"test@test.com");
    XCTAssertEqual(observer->last.to.emailUserId, @"1234");
    XCTAssertEqual(observer->last.to.emailAuthCode, @"test-hash-token");
    XCTAssertEqual(observer->last.to.requiresEmailAuth, true);
    
    let logoutExpectation = [self expectationWithDescription:@"logout-email"];
    logoutExpectation.expectedFulfillmentCount = 1;
    
    // test that logout clears the observer
    [OneSignal logoutEmailWithSuccess:^{
        [logoutExpectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered error: %@", error);
    }];
     
    [self waitForExpectations:@[logoutExpectation] timeout:0.1];
    
    XCTAssertNil(observer->last.to.emailAddress);
    XCTAssertNil(observer->last.to.emailAuthCode);
    XCTAssertNil(observer->last.to.emailUserId);
    
    //reset so we don't interfere with other tests
    [OneSignalClientOverrider setRequiresEmailAuth:false];
}

@end
