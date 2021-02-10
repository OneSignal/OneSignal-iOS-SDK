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
#import "NSObjectOverrider.h"
#import "OneSignalTracker.h"

@interface OneSignalTracker ()
+ (void)setLastOpenedTime:(NSTimeInterval)lastOpened;
@end

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
@property NSString* ONESIGNAL_EXTERNAL_USER_ID;
@property NSString* ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN;

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
    self.ONESIGNAL_EXTERNAL_USER_ID = @"test_external_user_id";
    self.ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN = @"test_external_user_id_hash_token";
    
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

- (void)testRegister {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    
    OneSignalRequest *createDeviceRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:2];
    OneSignalRequest *updateDeviceRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:3];
    NSString *expectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.pushUserId];
    XCTAssertEqualObjects(@"players", createDeviceRequest.path);
    XCTAssertEqualObjects(expectedUrl, updateDeviceRequest.path);
    
    XCTAssertEqual(7, createDeviceRequest.parameters.count);
    XCTAssertTrue([createDeviceRequest.parameters objectForKey:@"app_id"]);
    XCTAssertTrue([createDeviceRequest.parameters objectForKey:@"notification_types"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.pushUserId, [createDeviceRequest.parameters objectForKey:@"device_player_id"]);
    XCTAssertEqualObjects(@(DEVICE_TYPE_SMS), [createDeviceRequest.parameters objectForKey:@"device_type"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_NUMBER, createDeviceRequest.parameters[@"identifier"]);
    XCTAssertEqualObjects([NSNull null], [createDeviceRequest.parameters objectForKey:@"external_user_id_auth_hash"]);
    XCTAssertEqualObjects([NSNull null], [createDeviceRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
    
    XCTAssertEqual(2, updateDeviceRequest.parameters.count);
    XCTAssertTrue([updateDeviceRequest.parameters objectForKey:@"app_id"]);
    XCTAssertFalse([updateDeviceRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_NUMBER, updateDeviceRequest.parameters[SMS_NUMBER_KEY]);
}

- (void)testRegisterWithAuthToken {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    
    OneSignalRequest *createDeviceRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:2];
    OneSignalRequest *updateDeviceRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:3];
    NSString *expectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.pushUserId];
    XCTAssertEqualObjects(@"players", createDeviceRequest.path);
    XCTAssertEqualObjects(expectedUrl, updateDeviceRequest.path);
    
    XCTAssertEqual(7, createDeviceRequest.parameters.count);
    XCTAssertTrue([createDeviceRequest.parameters objectForKey:@"app_id"]);
    XCTAssertTrue([createDeviceRequest.parameters objectForKey:@"notification_types"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.pushUserId, [createDeviceRequest.parameters objectForKey:@"device_player_id"]);
    XCTAssertEqualObjects(@(DEVICE_TYPE_SMS), [createDeviceRequest.parameters objectForKey:@"device_type"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_NUMBER, createDeviceRequest.parameters[@"identifier"]);
    XCTAssertEqualObjects([NSNull null], [createDeviceRequest.parameters objectForKey:@"external_user_id_auth_hash"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_HASH_TOKEN, [createDeviceRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
    
    XCTAssertEqual(3, updateDeviceRequest.parameters.count);
    XCTAssertTrue([updateDeviceRequest.parameters objectForKey:@"app_id"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_HASH_TOKEN, [updateDeviceRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_NUMBER, updateDeviceRequest.parameters[SMS_NUMBER_KEY]);
}

- (void)testRegisterWithAuthTokenAndExternalId {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // We have 4 network calls at this point
    [OneSignal setExternalUserId:self.ONESIGNAL_EXTERNAL_USER_ID withExternalIdAuthHashToken:self.ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN withSuccess:nil withFailure:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 6);
    
    OneSignalRequest *pushExternalIdRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:4];
    OneSignalRequest *smsExternalIdRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:5];
    NSString *pushExpectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.pushUserId];
    NSString *smsExpectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.smsUserId];
    XCTAssertEqualObjects(pushExpectedUrl, pushExternalIdRequest.path);
    XCTAssertEqualObjects(smsExpectedUrl, smsExternalIdRequest.path);

    XCTAssertEqual(4, smsExternalIdRequest.parameters.count);
    XCTAssertTrue([smsExternalIdRequest.parameters objectForKey:@"app_id"]);
    XCTAssertEqualObjects(self.ONESIGNAL_EXTERNAL_USER_ID, [smsExternalIdRequest.parameters objectForKey:@"external_user_id"]);
    XCTAssertEqualObjects(self.ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN, [smsExternalIdRequest.parameters objectForKey:@"external_user_id_auth_hash"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_HASH_TOKEN, [smsExternalIdRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
}

- (void)testExternalIdNotSetOnSMSRegister {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setExternalUserId:self.ONESIGNAL_EXTERNAL_USER_ID withExternalIdAuthHashToken:self.ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN withSuccess:nil withFailure:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 5);
    
    OneSignalRequest *createDeviceRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:3];
    OneSignalRequest *updateDeviceRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:4];
    NSString *expectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.pushUserId];
    XCTAssertEqualObjects(@"players", createDeviceRequest.path);
    XCTAssertEqualObjects(expectedUrl, updateDeviceRequest.path);
    
    XCTAssertEqual(7, createDeviceRequest.parameters.count);
    XCTAssertTrue([createDeviceRequest.parameters objectForKey:@"app_id"]);
    XCTAssertTrue([createDeviceRequest.parameters objectForKey:@"notification_types"]);
    XCTAssertEqualObjects(OneSignalClientOverrider.pushUserId, [createDeviceRequest.parameters objectForKey:@"device_player_id"]);
    XCTAssertEqualObjects(@(DEVICE_TYPE_SMS), [createDeviceRequest.parameters objectForKey:@"device_type"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_NUMBER, createDeviceRequest.parameters[@"identifier"]);
    XCTAssertEqualObjects(self.ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN, [createDeviceRequest.parameters objectForKey:@"external_user_id_auth_hash"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_HASH_TOKEN, [createDeviceRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
    
    XCTAssertEqual(4, updateDeviceRequest.parameters.count);
    XCTAssertTrue([updateDeviceRequest.parameters objectForKey:@"app_id"]);
    XCTAssertEqualObjects(self.ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN, [updateDeviceRequest.parameters objectForKey:@"external_user_id_auth_hash"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_HASH_TOKEN, [updateDeviceRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_NUMBER, updateDeviceRequest.parameters[SMS_NUMBER_KEY]);
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

- (void)testSendTags {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // At this point we have 4 requests
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    
    [OneSignal sendTags:@{@"tag_1" : @"test_value"}];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    // Increse in 2 the quantity of requests, 1 per avialable channel (PUSH, SMS)
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 6);
    
    OneSignalRequest *pushTagsRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:4];
    OneSignalRequest *smsTagsRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:5];
    NSString *pushExpectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.pushUserId];
    NSString *smsExpectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.smsUserId];
    XCTAssertEqualObjects(pushExpectedUrl, pushTagsRequest.path);
    XCTAssertEqualObjects(smsExpectedUrl, smsTagsRequest.path);
    
    XCTAssertEqual(3, smsTagsRequest.parameters.count);
    XCTAssertTrue([smsTagsRequest.parameters objectForKey:@"app_id"]);
    XCTAssertTrue([smsTagsRequest.parameters objectForKey:@"net_type"]);
    XCTAssertEqualObjects(@"test_value", smsTagsRequest.parameters[@"tags"][@"tag_1"]);
}

- (void)testSendTagsWithAuthToken {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // At this point we have 4 requests
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 4);
    
    [OneSignal sendTags:@{@"tag_1" : @"test_value"}];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    // Increse in 2 the quantity of requests, 1 per avialable channel (PUSH, SMS)
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 6);
    
    OneSignalRequest *pushTagsRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:4];
    OneSignalRequest *smsTagsRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:5];
    NSString *pushExpectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.pushUserId];
    NSString *smsExpectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.smsUserId];
    XCTAssertEqualObjects(pushExpectedUrl, pushTagsRequest.path);
    XCTAssertEqualObjects(smsExpectedUrl, smsTagsRequest.path);
    
    XCTAssertEqual(4, smsTagsRequest.parameters.count);
    XCTAssertTrue([smsTagsRequest.parameters objectForKey:@"app_id"]);
    XCTAssertTrue([smsTagsRequest.parameters objectForKey:@"net_type"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_HASH_TOKEN, [smsTagsRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
    XCTAssertEqualObjects(@"test_value", smsTagsRequest.parameters[@"tags"][@"tag_1"]);
}

- (void)testSendTagsWithAuthTokenAndExternalId {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    [UnitTestCommonMethods foregroundApp];
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignal setExternalUserId:self.ONESIGNAL_EXTERNAL_USER_ID withExternalIdAuthHashToken:self.ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN withSuccess:nil withFailure:nil];
    [UnitTestCommonMethods runBackgroundThreads];
    
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 6);
    
    [OneSignal sendTags:@{@"tag_1" : @"test_value"}];
    [NSObjectOverrider runPendingSelectors];
    [UnitTestCommonMethods runBackgroundThreads];
    [NSObjectOverrider runPendingSelectors];
    
    // Increse in 2 the quantity of requests, 1 per avialable channel (PUSH, SMS)
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 8);
    
    OneSignalRequest *pushTagsRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:6];
    OneSignalRequest *smsTagsRequest = [OneSignalClientOverrider.executedRequests objectAtIndex:7];
    NSString *pushExpectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.pushUserId];
    NSString *smsExpectedUrl = [NSString stringWithFormat:@"players/%@", OneSignalClientOverrider.smsUserId];
    XCTAssertEqualObjects(pushExpectedUrl, pushTagsRequest.path);
    XCTAssertEqualObjects(smsExpectedUrl, smsTagsRequest.path);
    
    XCTAssertEqual(5, smsTagsRequest.parameters.count);
    XCTAssertTrue([smsTagsRequest.parameters objectForKey:@"app_id"]);
    XCTAssertTrue([smsTagsRequest.parameters objectForKey:@"net_type"]);
    XCTAssertEqualObjects(self.ONESIGNAL_SMS_HASH_TOKEN, [smsTagsRequest.parameters objectForKey:SMS_NUMBER_AUTH_HASH_KEY]);
    XCTAssertEqualObjects(self.ONESIGNAL_EXTERNAL_USER_ID_HASH_TOKEN, [smsTagsRequest.parameters objectForKey:@"external_user_id_auth_hash"]);
    XCTAssertEqualObjects(@"test_value", smsTagsRequest.parameters[@"tags"][@"tag_1"]);
}

- (void)testOnFocusSMSRequest {
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
    
    [OneSignal setSMSNumber:self.ONESIGNAL_SMS_NUMBER withSMSAuthHashToken:self.ONESIGNAL_SMS_HASH_TOKEN];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignalClientOverrider reset:self];
    
    // Check to make sure request count gets reset to 0
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 0);
    
    [OneSignalTracker setLastOpenedTime:now - 4000];
    [OneSignalTracker onFocus:false];
    [UnitTestCommonMethods runBackgroundThreads];
    
    [OneSignalTracker setLastOpenedTime:now - 4000];
    [OneSignalTracker onFocus:true];
    [UnitTestCommonMethods runBackgroundThreads];
    
    // on_focus should fire off two requests, one for the SMS player ID and one for push player ID
    XCTAssertTrue([OneSignalClientOverrider hasExecutedRequestOfType:[OSRequestOnFocus class]]);
    XCTAssertEqual(OneSignalClientOverrider.networkRequestCount, 2);
}

@end
