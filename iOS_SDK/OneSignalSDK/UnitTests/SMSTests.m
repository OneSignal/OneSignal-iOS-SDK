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
#import "NSUserDefaultsOverrider.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalTracker.h"
#import "OneSignalInternal.h"

@interface OneSignalTracker ()
+ (void)setLastOpenedTime:(NSTimeInterval)lastOpened;
@end

@interface OneSignal ()
void onesignal_Log(ONE_S_LOG_LEVEL logLevel, NSString* message);
+ (NSString *)getSMSAuthToken;
+ (NSString *)getSMSUserId;
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
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"sms_number"], self.ONESIGNAL_SMS_NUMBER);
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"sms_auth_hash"], self.ONESIGNAL_SMS_HASH_TOKEN);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNotNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertEqual(self.ONESIGNAL_SMS_HASH_TOKEN, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:@"sms_number"]);
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
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"sms_auth_hash"], self.ONESIGNAL_SMS_HASH_TOKEN );
    
    XCTAssertEqual(newSMSNumber, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);

    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(newSMSNumber, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:@"sms_number"]);
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);

    XCTAssertEqual([OneSignal getSMSUserId], @"1234");
    XCTAssertEqual([OneSignal getSMSAuthToken], self.ONESIGNAL_SMS_HASH_TOKEN);
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
    XCTAssertEqual(OneSignalClientOverrider.lastHTTPRequest[@"sms_number"], self.ONESIGNAL_SMS_NUMBER);
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"sms_auth_hash"]);
    
    // Check to make sure that the push token & auth were saved to NSUserDefaults
    XCTAssertNotNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_PLAYER_ID defaultValue:nil]);
    XCTAssertNil([OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_AUTH_CODE defaultValue:nil]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);
    
    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(self.ONESIGNAL_SMS_NUMBER, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:@"sms_number"]);
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
    XCTAssertNil(OneSignalClientOverrider.lastHTTPRequest[@"sms_auth_hash"]);
    
    XCTAssertEqual(newSMSNumber, [OneSignalUserDefaults.initStandard getSavedStringForKey:OSUD_SMS_NUMBER defaultValue:nil]);

    XCTAssertNotNil(self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE);
    XCTAssertEqual(1, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE count]);
    XCTAssertEqual(newSMSNumber, [self.CALLBACK_SMS_NUMBER_SUCCESS_RESPONSE objectForKey:@"sms_number"]);
    XCTAssertNil(self.CALLBACK_SMS_NUMBER_FAIL_RESPONSE);

    XCTAssertEqual([OneSignal getSMSUserId], @"1234");
    XCTAssertNil([OneSignal getSMSAuthToken]);
}

@end
