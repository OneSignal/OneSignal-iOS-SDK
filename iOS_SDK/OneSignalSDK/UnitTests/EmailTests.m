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
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OneSignalUserDefaults.h"
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
#import "OneSignalCommonDefines.h"
#import "OneSignalTracker.h"
#import "OneSignalInternal.h"

@interface OneSignalTracker ()
+ (void)setLastOpenedTime:(NSTimeInterval)lastOpened;
@end

@interface OneSignal () 
void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message);
+ (NSString *)mEmailUserId;
+ (NSString *)mEmailAuthToken;
+ (void)registerUserInternal;
+ (void)setImmediateOnSessionRetry:(BOOL)retry;
@end

@interface EmailTests : XCTestCase

@end

@implementation EmailTests

/*
 Put setup code here
 This method is called before the invocation of each test method in the class
 */
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [OneSignalClientOverrider setRequiresEmailAuth:false];
}

/*
 Put teardown code here
 This method is called after the invocation of each test method in the class
 */
- (void)tearDown {
    [super tearDown];
}

- (void)testEmailValidation {
    XCTAssertFalse([OneSignalHelper isValidEmail:@"test@test"]);
    
    XCTAssertTrue([OneSignalHelper isValidEmail:@"john.doe233@unlv.nevada.edu"]);
    
    XCTAssertFalse([OneSignalHelper isValidEmail:@"testing123@22."]);
}

- (void)testSetAuthenticatedEmail {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignal setEmail:@"test@test.com"
 withEmailAuthHashToken:@"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c"
            withSuccess:nil
            withFailure:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    //check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNotNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_EMAIL_PLAYER_ID defaultValue:nil]);
    XCTAssertNotNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_EMAIL_AUTH_CODE defaultValue:nil]);
    
    //check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"parent_player_id"], @"1234");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"email"], @"test@test.com");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"email_auth_hash"], @"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c");
    
    //we will change the email and make sure the HTTP call to update the device token is made
    [OneSignal setEmail:@"test2@test.com"
 withEmailAuthHashToken:@"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c"
             withSuccess:nil
            withFailure:nil];
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
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignal setEmail:@"test@test.com"
            withSuccess:nil
            withFailure:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
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
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
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

/*
 Tests to make sure the SDK correctly rejects setEmail when authToken == nil if
 The auth token is required (via iOS params file) for this application
 */
- (void)testRequiresEmailAuth {
    [OneSignalClientOverrider setRequiresEmailAuth:true];
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
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
}

- (void)testDoesNotRequireEmailAuth {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setEmail:@"testEmail@test.com" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered error: %@", error);
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
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
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    let unsubscribedSubscriptionStatus = [OneSignal getPermissionSubscriptionState].emailSubscriptionStatus;
    
    XCTAssertNil(unsubscribedSubscriptionStatus.emailAuthCode);
    XCTAssertNil(unsubscribedSubscriptionStatus.emailAddress);
    XCTAssertNil(unsubscribedSubscriptionStatus.emailUserId);
    XCTAssertFalse(unsubscribedSubscriptionStatus.isSubscribed);
    
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
    XCTAssertEqual(loggedInSubscriptionStatus.isSubscribed, true);
    
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
    XCTAssertFalse(loggedOutSubscriptionStatus.isSubscribed);
}

- (void)testEmailSubscriptionObserver {
    let observer = [OSEmailSubscriptionStateTestObserver new];
    [OneSignal addEmailSubscriptionObserver:observer];
    
    [OneSignalClientOverrider setRequiresEmailAuth:true];
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"test-hash-token" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered error: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
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
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertNil(observer->last.to.emailAddress);
    XCTAssertNil(observer->last.to.emailAuthCode);
    XCTAssertNil(observer->last.to.emailUserId);
}

/*
 When the user is logged in with email, on_focus requests should be duplicated for the email player id as well
 */
- (void)testOnFocusEmailRequest {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [OneSignalClientOverrider reset:self];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    //if we don't artificially set lastOpenedTime back at least 30 seconds, the on_focus request will not execute
    [OneSignalTracker setLastOpenedTime:now - 4000];
    [OneSignalTracker onFocus:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignalTracker setLastOpenedTime:now - 4000];
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue([OneSignalClientOverrider hasExecutedRequestOfType:[OSRequestOnFocus class]]);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 1);
    
    [OneSignalClientOverrider reset:self];
    [OneSignalClientOverrider setRequiresEmailAuth:true];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"test-hash-token" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered an error: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    [OneSignalClientOverrider reset:self];
    
    //check to make sure request count gets reset to 0
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 0);
    
    [OneSignalTracker setLastOpenedTime:now - 4000];
    [OneSignalTracker onFocus:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignalTracker setLastOpenedTime:now - 4000];
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // on_focus should fire off two requests, one for the email player ID and one for push player ID
    XCTAssertTrue([OneSignalClientOverrider hasExecutedRequestOfType:[OSRequestOnFocus class]]);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
}

- (void)testRegistration {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignalClientOverrider setRequiresEmailAuth:true];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"test-hash-token" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Encountered an error: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    //reset network request count back to zero
    [OneSignalClientOverrider reset:self];
    
    //set this flag to true so that registerUserInternal() actually executes
    // TODO: Clean up hack to make player create fire right away
    [OneSignal setImmediateOnSessionRetry:true];
    
    [OneSignal registerUserInternal];
    [UnitTestCommonMethods runBackgroundThreads];
    
    //should make two requests (one for email player ID, one for push)
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqualObjects(OneSignalClientOverrider.lastHTTPRequest[@"email_auth_hash"], @"test-hash-token");
}

- (void)testEmailSubscriptionDescription {
    let observer = [OSEmailSubscriptionStateTestObserver new];
    [OneSignal addEmailSubscriptionObserver:observer];
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    let expectation = [self expectationWithDescription:@"email"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal setEmail:@"test@test.com" withSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail(@"Failed with error: %@", error);
    }];
    
    [self waitForExpectations:@[expectation] timeout:0.1];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue([observer->last.to.description isEqualToString: @"<OSEmailSubscriptionState: emailAddress: test@test.com, emailUserId: 1234, emailAuthCode: (null)>"]);
    XCTAssertTrue([observer->last.from.description isEqualToString:@"<OSEmailSubscriptionState: emailAddress: (null), emailUserId: (null), emailAuthCode: (null)>"]);
    XCTAssertTrue([observer->last.description isEqualToString:@"<OSEmailSubscriptionStateChanges:\nfrom: <OSEmailSubscriptionState: emailAddress: (null), emailUserId: (null), emailAuthCode: (null)>,\nto:   <OSEmailSubscriptionState: emailAddress: test@test.com, emailUserId: 1234, emailAuthCode: (null)>\n>"]);
}

- (void)testSetExternalIdForEmailPlayer {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignal setEmail:@"test@test.com"];
    [UnitTestCommonMethods runBackgroundThreads];
    
    int currentRequestCount = OneSignalClientOverrider.networkRequestCount;
    
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];
    [UnitTestCommonMethods runBackgroundThreads];
    
    let emailPlayerId = OneSignal.getPermissionSubscriptionState.emailSubscriptionStatus.emailUserId;
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, currentRequestCount + 2);
    
    for (OneSignalRequest *request in OneSignalClientOverrider.executedRequests)
        if ([request isKindOfClass:[OSRequestUpdateExternalUserId class]] && [request.urlRequest.URL.absoluteString containsString:emailPlayerId])
            XCTAssertEqualObjects(request.parameters[@"external_user_id"], TEST_EXTERNAL_USER_ID);
    
    // lastly, check to make sure that calling setExternalUserId() again with the same
    // ID doesn't create a duplicate API request
    [OneSignal setExternalUserId:TEST_EXTERNAL_USER_ID];
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, currentRequestCount + 2);
}

@end
