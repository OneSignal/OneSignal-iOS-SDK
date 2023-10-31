/**
 * Modified MIT License
 *
 * Copyright 2020 OneSignal
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
#import "UnitTestCommonMethods.h"
#import "OneSignalLocationManager.h"
#import "OneSignalLocationOverrider.h"
#import "OneSignalHelper.h"
#import "OneSignalHelperOverrider.h"
#import "UIDeviceOverrider.h"
#import "NSBundleOverrider.h"
#import "OneSignalClientOverrider.h"
#import "OneSignalCommonDefines.h"

@interface RemoteParamsTests : XCTestCase
@end

@implementation RemoteParamsTests

/*
 Put setup code here
 This method is called before the invocation of each test method in the class
 */
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    // Clear last location stored
    [OneSignalLocationManager clearLastLocation];

    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalHelperOverrider reset];
    [UIDeviceOverrider reset];
}

/*
 Put teardown code here
 This method is called after the invocation of each test method in the class
 */
- (void)tearDown {
    [super tearDown];
}

- (void)testLocationPromptAcceptedWithSetLocationShared_iOS9_WhenInUseUsage {
    OneSignalHelperOverrider.mockIOSVersion = 9;
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"],
                                             @"NSLocationWhenInUseUsageDescription" : @YES
                                             };

    NSMutableDictionary *params = [[OneSignalClientOverrider remoteParamsResponse] mutableCopy];
    [params removeObjectForKey:IOS_LOCATION_SHARED];
    [OneSignalClientOverrider setRemoteParamsResponse:params];
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];

     // Set location shared false
    [OneSignal setLocationShared:false];
    // Simulate user granting location services
    [OneSignalLocationOverrider grantLocationServices];
    // Last location should not exist since we are not sharing location
    XCTAssertFalse([OneSignalLocationManager lastLocation]);
       
    // Set location shared true
    [OneSignal setLocationShared:true];
    // Simulate user granting location services
    [OneSignalLocationOverrider grantLocationServices];
    [UnitTestCommonMethods runLongBackgroundThreads];
    // Last location should exist since we are sharing location
    XCTAssertTrue([OneSignalLocationManager lastLocation]);
}

- (void)testLocationPromptAcceptedWithSetLocationSharedTrueFromRemoteParams_iOS9_WhenInUseUsage {
    OneSignalHelperOverrider.mockIOSVersion = 9;
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"],
                                             @"NSLocationWhenInUseUsageDescription" : @YES
                                             };
    
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    // location_shared set as true on remote params
    XCTAssertTrue([OneSignal isLocationShared]);
    // Last location should not exist since we didn't grant permission
    XCTAssertFalse([OneSignalLocationManager lastLocation]);
    // Simulate user granting location services
    [OneSignalLocationOverrider grantLocationServices];
    [UnitTestCommonMethods runLongBackgroundThreads];
    // Last location should exist since we are sharing location
    XCTAssertTrue([OneSignalLocationManager lastLocation]);
}

- (void)testLocationPromptAcceptedWithSetLocationSharedFalseFromRemoteParams_iOS9_WhenInUseUsage {
    OneSignalHelperOverrider.mockIOSVersion = 9;
    
    NSBundleOverrider.nsbundleDictionary = @{@"UIBackgroundModes": @[@"remote-notification"],
                                             @"NSLocationWhenInUseUsageDescription" : @YES
                                             };
    
    NSMutableDictionary *params = [[OneSignalClientOverrider remoteParamsResponse] mutableCopy];
    [params setObject:@NO forKey:IOS_LOCATION_SHARED];
    [OneSignalClientOverrider setRemoteParamsResponse:params];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    // location_shared set as false on remote params
    XCTAssertFalse([OneSignal isLocationShared]);
    // Last location should not exist since we didn't grant permission
    XCTAssertFalse([OneSignalLocationManager lastLocation]);
    // Simulate user granting location services
    [OneSignalLocationOverrider grantLocationServices];
    // Last location should not exist since we are not sharing location
    XCTAssertFalse([OneSignalLocationManager lastLocation]);
}

- (void)testLocationSharedTrueFromRemoteParams {
    NSBundleOverrider.nsbundleDictionary = @{
                                             @"NSLocationWhenInUseUsageDescription" : @YES
                                            };
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    // location_shared set as true on remote params
    XCTAssertTrue([OneSignal isLocationShared]);
    // Last location should not exist since we didn't grant permission
    XCTAssertFalse([OneSignalLocationManager lastLocation]);
    // Simulate user granting location services
    [OneSignalLocationOverrider grantLocationServices];
    [UnitTestCommonMethods runLongBackgroundThreads];
    // Last location should exist since we are sharing location
    XCTAssertTrue([OneSignalLocationManager lastLocation]);
}

- (void)testLocationSharedFalseFromRemoteParams {
    NSBundleOverrider.nsbundleDictionary = @{
                                             @"NSLocationWhenInUseUsageDescription" : @YES
                                            };
    NSMutableDictionary *params = [[OneSignalClientOverrider remoteParamsResponse] mutableCopy];
    [params setObject:@NO forKey:IOS_LOCATION_SHARED];
    [OneSignalClientOverrider setRemoteParamsResponse:params];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    // location_shared set as false on remote params
    XCTAssertFalse([OneSignal isLocationShared]);
    // Last location should not exist since we didn't grant permission
    XCTAssertFalse([OneSignalLocationManager lastLocation]);
    // Simulate user granting location services
    [OneSignalLocationOverrider grantLocationServices];
    // Last location should not exist since we are not sharing location
    XCTAssertFalse([OneSignalLocationManager lastLocation]);
}

- (void)testLocationSharedEnable_UserConfigurationOverrideByRemoteParams {
    [OneSignal setLocationShared:false];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    // location_shared set as true on remote params
    XCTAssertTrue([OneSignal isLocationShared]);
}

- (void)testLocationSharedDisable_UserConfigurationOverrideByRemoteParams {
    [OneSignal setLocationShared:true];
    NSMutableDictionary *params = [[OneSignalClientOverrider remoteParamsResponse] mutableCopy];
    [params setObject:@NO forKey:IOS_LOCATION_SHARED];
    [OneSignalClientOverrider setRemoteParamsResponse:params];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    // location_shared set as false on remote params
    XCTAssertFalse([OneSignal isLocationShared]);
}

- (void)testLocationSharedEnable_UserConfigurationNotOverrideRemoteParams {
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    // location_shared set as true on remote params
    XCTAssertTrue([OneSignal isLocationShared]);
    
    [OneSignal setLocationShared:false];
    XCTAssertTrue([OneSignal isLocationShared]);
}

- (void)testLocationSharedDisable_UserConfigurationNotOverrideRemoteParams {
    NSMutableDictionary *params = [[OneSignalClientOverrider remoteParamsResponse] mutableCopy];
    [params setObject:@NO forKey:IOS_LOCATION_SHARED];
    [OneSignalClientOverrider setRemoteParamsResponse:params];
    [UnitTestCommonMethods initOneSignal_andThreadWait];
    // location_shared set as false on remote params
    XCTAssertFalse([OneSignal isLocationShared]);
    
    [OneSignal setLocationShared:true];
    XCTAssertFalse([OneSignal isLocationShared]);
}

/*
 Tests the privacy functionality to comply with the GDPR
*/
- (void)testPrivacyState {
    [NSBundleOverrider setPrivacyState:true];
    
    [self assertUserConsent];
    
    [NSBundleOverrider setPrivacyState:false];
}

- (void)assertUserConsent {
    [OneSignal setAppId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    [OneSignal initWithLaunchOptions:nil];
    
    //indicates initialization was delayed
    XCTAssertNil(OneSignal.appId);
    
    XCTAssertTrue([OneSignal requiresPrivacyConsent]);
    
    let latestHttpRequest = OneSignalClientOverrider.lastUrl;
    
    [OneSignal sendTags:@{@"test" : @"test"}];
    
    //if lastUrl is null, isEqualToString: will return false, so perform an equality check as well
    XCTAssertTrue([OneSignalClientOverrider.lastUrl isEqualToString:latestHttpRequest] || latestHttpRequest == OneSignalClientOverrider.lastUrl);
    
    [OneSignal setPrivacyConsent:true];
    
    XCTAssertTrue([@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba" isEqualToString:OneSignal.appId]);
    
    XCTAssertFalse([OneSignal requiresPrivacyConsent]);
}

- (void)testUserPrivacyConsentRequired_ByRemoteParams {
    NSMutableDictionary *params = [[OneSignalClientOverrider remoteParamsResponse] mutableCopy];
    [params setObject:@YES forKey:IOS_REQUIRES_USER_PRIVACY_CONSENT];
    [OneSignalClientOverrider setRemoteParamsResponse:params];
    [UnitTestCommonMethods initOneSignal_andThreadWait];

    // requires_user_privacy_consent set as true on remote params
    XCTAssertTrue([OneSignal requiresPrivacyConsent]);
    [NSBundleOverrider setPrivacyState:false];
}

- (void)testUserPrivacyConsentNotRequired_ByRemoteParams {
    [UnitTestCommonMethods initOneSignal_andThreadWait];

    // requires_user_privacy_consent set as false on remote params
    XCTAssertFalse([OneSignal requiresPrivacyConsent]);
    [NSBundleOverrider setPrivacyState:false];
}

- (void)testUserPrivacyConsentRequired_UserConfigurationOverrideByRemoteParams {
    [OneSignal setRequiresPrivacyConsent:false];

    NSMutableDictionary *params = [[OneSignalClientOverrider remoteParamsResponse] mutableCopy];
    [params setObject:@YES forKey:IOS_REQUIRES_USER_PRIVACY_CONSENT];
    [OneSignalClientOverrider setRemoteParamsResponse:params];
    [UnitTestCommonMethods initOneSignal_andThreadWait];

    // requires_user_privacy_consent set as true on remote params
    XCTAssertTrue([OneSignal requiresPrivacyConsent]);
    [NSBundleOverrider setPrivacyState:false];
}

- (void)testUserPrivacyConsentRequired_UserConfigurationNotOverrideRemoteParams {
    NSMutableDictionary *params = [[OneSignalClientOverrider remoteParamsResponse] mutableCopy];
    [params setObject:@YES forKey:IOS_REQUIRES_USER_PRIVACY_CONSENT];
    [OneSignalClientOverrider setRemoteParamsResponse:params];
    [UnitTestCommonMethods initOneSignal_andThreadWait];

    // requires_user_privacy_consent set as true on remote params
    XCTAssertTrue([OneSignal requiresPrivacyConsent]);
    
    [OneSignal setRequiresPrivacyConsent:false];
    XCTAssertTrue([OneSignal requiresPrivacyConsent]);
    [NSBundleOverrider setPrivacyState:false];
}


- (void)testUserPrivacyConsentNotRequired_UserConfigurationNotOverrideRemoteParams {
    [UnitTestCommonMethods initOneSignal_andThreadWait];

    // requires_user_privacy_consent set as false on remote params
    XCTAssertFalse([OneSignal requiresPrivacyConsent]);
    
    [OneSignal setRequiresPrivacyConsent:true];
    XCTAssertFalse([OneSignal requiresPrivacyConsent]);
    [NSBundleOverrider setPrivacyState:false];
}

@end
