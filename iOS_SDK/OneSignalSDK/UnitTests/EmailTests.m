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



@interface EmailTests : XCTestCase

@end

@implementation EmailTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
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

- (void)testSetEmail {
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
            handleNotificationAction:nil
                            settings:@{kOSSettingsKeyAutoPrompt: @false}];
    
    OSSubscriptionStateTestObserver* observer = [OSSubscriptionStateTestObserver new];
    [OneSignal addSubscriptionObserver:observer];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c" withSuccess:nil withFailure:nil];
    
    [UnitTestCommonMethods runBackgroundThreads];
    NSLog(@"EMAIL AFTER IS: %@", OneSignalClientOverrider.lastHTTPRequest[@"email"]);
    XCTAssertTrue([@"OSRequestCreateDevice" isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"device_type"], @11);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], @"test@test.com");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"email_auth_hash"], @"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c");
    
    [OneSignal setEmail:@"test@test.com" withEmailAuthHashToken:@"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c" withSuccess:nil withFailure:nil];
    
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertTrue([@"OSRequestUpdateDeviceToken" isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    
    //test email logout
    let expectation = [self expectationWithDescription:@"email_logout"];
    expectation.expectedFulfillmentCount = 1;
    
    [OneSignal logoutEmailWithSuccess:^{
        [expectation fulfill];
    } withFailure:^(NSError *error) {
        XCTFail("Failed with error: %@", error);
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
