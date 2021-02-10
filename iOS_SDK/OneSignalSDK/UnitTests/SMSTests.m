/*
 Modified MIT License
 
 Copyright 2021 OneSignal
 
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
#import "Requests.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalClientOverrider.h"
#import "UnitTestCommonMethods.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "NSBundleOverrider.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalSetSMSParameters.h"
#import "OneSignalHelper.h"
#import "NSDateOverrider.h"
#import "OneSignalTracker.h"

@interface OneSignal ()
void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message);
+ (NSString *)getSMSAuthToken;
+ (NSString *)getSMSUserId;
+ (OneSignalSetSMSParameters *)delayedSMSParameters;
+ (void)registerUserInternal;
+ (void)setImmediateOnSessionRetry:(BOOL)retry;
@end

@interface SMSTests : XCTestCase

@property NSError* CALLBACK_SMS_NUMBER_FAIL_RESPONSE;
@property NSDictionary* CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE;
@property NSString* ONESIGNAL_SMS_NUMBER;
@property NSString* ONESIGNAL_SMS_HASH_TOKEN;

@end

@implementation SMSTests

/*
 Put setup code here
 This method is called before the invocation of each test method in the class
 */
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"]};
    
    [OneSignalClientOverrider setRequiresSMSAuth:false];
    
    self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = nil;
    self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = nil;
    self.ONESIGNAL_SMS_NUMBER = @"123456789";
    self.ONESIGNAL_SMS_HASH_TOKEN = @"c7e76fb9579df964fa9dffd418619aa30767b864b1c025f5df22458cae65033c";
    
    [OneSignal setLogLevel:ONE_S_LL_VERBOSE visualLevel:ONE_S_LL_NONE];
}

/*
 Put teardown code here
 This method is called after the invocation of each test method in the class
 */
- (void)tearDown {
    [super tearDown];
}

- (void)testSetAuthenticatedSMSNumber {
    [UnitTestCommonMethods initOneSignal_andThreadWait];

    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];

    // Check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertFalse([OneSignalClientOverrider.lastHTTPRequest objectForKey:@"parent_player_id"]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_KEY], self.ONESIGNAL_SMS_NUMBER);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_AUTH_HASH_KEY], self.ONESIGNAL_SMS_HASH_TOKEN);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNotNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertEqual(self.ONESIGNAL_SMS_HASH_TOKEN, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:SMS_NUMBER_KEY]);
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);

    // Reset Callbacks
    self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = nil;
    self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = nil;
    NSString *newSMSNumber = @"new_sms_number";
    //we will change the sms number and make sure the HTTP call to update the device token is made
    [OneSignal setSMSNumber:newSMSNumber withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Check to make sure the server gets updated with the new email
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], newSMSNumber);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_AUTH_HASH_KEY], self.ONESIGNAL_SMS_HASH_TOKEN );
    
    XCTAssertEqual(newSMSNumber, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);

    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(newSMSNumber, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:SMS_NUMBER_KEY]);
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);

    XCTAssertEqual(OneSignalClientOverrider.smsUserId, [OneSignal getSMSUserId]);
    XCTAssertEqual( self.ONESIGNAL_SMS_HASH_TOKEN, [OneSignal getSMSAuthToken]);
}

- (void)testUnauthenticatedSMS {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertFalse([OneSignalClientOverrider.lastHTTPRequest objectForKey:@"parent_player_id"]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_KEY], self.ONESIGNAL_SMS_NUMBER);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_AUTH_HASH_KEY]);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNotNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:SMS_NUMBER_KEY]);
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);

    // Reset Callbacks
    self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = nil;
    self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = nil;
    NSString *newSMSNumber = @"new_sms_number";
    // We will change the sms number and make sure the HTTP call to update the device token is made
    [OneSignal setSMSNumber:newSMSNumber withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Check to make sure the server gets updated with the new email
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"identifier"], newSMSNumber);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_AUTH_HASH_KEY]);
    
    XCTAssertEqual(newSMSNumber, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);

    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(newSMSNumber, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:SMS_NUMBER_KEY]);
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);

    XCTAssertEqual(OneSignalClientOverrider.smsUserId, [OneSignal getSMSUserId]);
    XCTAssertNil([OneSignal getSMSAuthToken]);
}

/*
 Tests to make sure the SDK correctly rejects setSMSNumber when authToken == nil if
 The auth token is required (via iOS params file) for this application
 */
- (void)testRequiresSMSAuthWithHashToken {
    [OneSignalClientOverrider setRequiresSMSAuth:true];
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertTrue([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"app_id"], @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba");
    XCTAssertFalse([OneSignalClientOverrider.lastHTTPRequest objectForKey:@"parent_player_id"]);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_KEY], self.ONESIGNAL_SMS_NUMBER);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_AUTH_HASH_KEY], self.ONESIGNAL_SMS_HASH_TOKEN);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNotNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertEqual(self.ONESIGNAL_SMS_HASH_TOKEN, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:SMS_NUMBER_KEY]);
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);
}

- (void)testRequiresSMSAuthWithNoHashToken {
    [OneSignalClientOverrider setRequiresSMSAuth:true];
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertFalse([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);
    XCTAssertEqual(@"com.onesignal.sms", self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.domain);
    XCTAssertEqual(0, self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.code);
    XCTAssertEqual(@"SMS authentication (auth token) is set to REQUIRED for this application. Please provide an auth token from your backend server or change the setting in the OneSignal dashboard.", [self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.userInfo objectForKey:@"error"]);
}

- (void)testInvalidNilSMSNumber {
    [OneSignalClientOverrider setRequiresSMSAuth:true];
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignal setSMSNumber:nil withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertFalse([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);
    XCTAssertEqual(@"com.onesignal.sms", self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.domain);
    XCTAssertEqual(0, self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.code);
    XCTAssertEqual(@"SMS number is invalid", [self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.userInfo objectForKey:@"error"]);
}

- (void)testInvalidEmptySMSNumber {
    [OneSignalClientOverrider setRequiresSMSAuth:true];
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    
    [OneSignal setSMSNumber:@"" withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertFalse([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);
    XCTAssertEqual(@"com.onesignal.sms", self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.domain);
    XCTAssertEqual(0, self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.code);
    XCTAssertEqual(@"SMS number is invalid", [self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE.userInfo objectForKey:@"error"]);
}

- (void)testPopulatedDelayedSMSParams {
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN withSuccess:^(NSDictionary *results) {
        self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE = results;
    } withFailure:^(NSError *error) {
        self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE = error;
    }];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Check to make sure the OSRequestCreateDevice HTTP call was made, and was formatted correctly
    XCTAssertFalse([NSStringFromClass([OSRequestUpdateDeviceToken class]) isEqualToString:OneSignalClientOverrider.lastHTTPRequestType]);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNotNil([OneSignal delayedSMSParameters]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [OneSignal delayedSMSParameters].smsNumber);
    XCTAssertEqual(self.ONESIGNAL_SMS_HASH_TOKEN, [OneSignal delayedSMSParameters].authToken);
    XCTAssertNotNil([OneSignal delayedSMSParameters].successBlock);
    XCTAssertNotNil([OneSignal delayedSMSParameters].failureBlock);
}

- (void)testOnSessionRequest {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [UnitTestCommonMethods backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Reset network request count back to zero
    [OneSignalClientOverrider reset:self];
    
    [NSDateOverrider advanceSystemTimeBy:30];
    
    // After foreground on_session call for both sms and push should happen
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    NSString *expectedUrl = [NSString stringWithFormat:@"https://api.onesignal.com/players/%@/on_session", OneSignalClientOverrider.smsUserId];
    // Should make two requests (one for sms player Id, one for push)
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    XCTAssertEqualObjects(expectedUrl, OneSignalClientOverrider.lastUrl);
    XCTAssertEqualObjects(@(DEVICE_TYPE_SMS), OneSignalClientOverrider.lastHTTPRequest[@"device_type"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.pushUserId, OneSignalClientOverrider.lastHTTPRequest[@"device_player_id"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_NUMBER, OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_KEY]);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_AUTH_HASH_KEY]);
}

- (void)testOnSessionRequestWithAuthToken {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [UnitTestCommonMethods backgroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // Reset network request count back to zero
    [OneSignalClientOverrider reset:self];
    
    [NSDateOverrider advanceSystemTimeBy:30];
    
    // After foreground on_session call for both sms and push should happen
    [UnitTestCommonMethods foregroundApp];
    [UnitTestCommonMethods runBackgroundThreads];
    
    NSString *expectedUrl = [NSString stringWithFormat:@"https://api.onesignal.com/players/%@/on_session", OneSignalClientOverrider.smsUserId];
    // Should make two requests (one for sms player Id, one for push)
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
    XCTAssertEqualObjects(expectedUrl, OneSignalClientOverrider.lastUrl);
    XCTAssertEqualObjects(@(DEVICE_TYPE_SMS), OneSignalClientOverrider.lastHTTPRequest[@"device_type"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.pushUserId, OneSignalClientOverrider.lastHTTPRequest[@"device_player_id"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_NUMBER, OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_KEY]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_HASH_TOKEN, OneSignalClientOverrider.lastHTTPRequest[SMS_NUMBER_AUTH_HASH_KEY]);
}

@end
