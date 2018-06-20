//
//  ProvisionalAuthorizationTests.m
//  UnitTests
//
//  Created by Brad Hesse on 6/19/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "UnitTestCommonMethods.h"
#import "OneSignalExtensionBadgeHandler.h"
#import "NSUserDefaultsOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalHelperOverrider.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalClientOverrider.h"

@interface ProvisionalAuthorizationTests : XCTestCase

@end

@implementation ProvisionalAuthorizationTests

- (OSPermissionStateTestObserver *)setupProvisionalTest {
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [UNUserNotificationCenterOverrider setNotifTypesOverride:0];
    [UNUserNotificationCenterOverrider setAuthorizationStatus:@0];
    
    OneSignalHelperOverrider.mockIOSVersion = 12;
    
    [OneSignalClientOverrider setShouldUseProvisionalAuth:true];
    
    OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
    [OneSignal addPermissionObserver:observer];
    return observer;
}

// Tests to make sure that apps set to use Provisional authorization work & register correctly
- (void)testProvisionalPermissionState {
    if (@available(iOS 12, *)) {
        OSPermissionStateTestObserver* observer = [self setupProvisionalTest];
        [UNUserNotificationCenterOverrider setShouldSetProvisionalAuthorizationStatus:true];
        
        OSSubscriptionStateTestObserver *subscriptionObserver = [OSSubscriptionStateTestObserver new];
        [OneSignal addSubscriptionObserver:subscriptionObserver];
        
        [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
                handleNotificationAction:nil
                                settings:@{kOSSettingsKeyAutoPrompt: @false}];
        
        [UnitTestCommonMethods runBackgroundThreads];
        
        [UNUserNotificationCenterOverrider fireLastRequestAuthorizationWithGranted:true];
        
        [UnitTestCommonMethods runBackgroundThreads];
        
        XCTAssertTrue(UNUserNotificationCenterOverrider.lastRequestedAuthorizationOptions == (UNAuthorizationOptions)(1 << 6));
        
        XCTAssertTrue(observer->last.to.provisional);
        XCTAssertFalse(observer->last.from.provisional);
        
        //make sure registration occurred
        XCTAssertEqual(subscriptionObserver->last.to.userId, @"1234");
    }
}

// tests to make sure that apps can still prompt for regular
// push authorization when they use Provisional authorization
- (void)testPromptWorksWithProvisional {
    if (@available(iOS 12, *)) {
        OSPermissionStateTestObserver* observer = [self setupProvisionalTest];
        [UNUserNotificationCenterOverrider setShouldSetProvisionalAuthorizationStatus:true];
        
        [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
                handleNotificationAction:nil
                                settings:@{kOSSettingsKeyAutoPrompt: @false}];
        
        [UnitTestCommonMethods runBackgroundThreads];
        
        [UNUserNotificationCenterOverrider fireLastRequestAuthorizationWithGranted:true];
        
        [UnitTestCommonMethods runBackgroundThreads];
        
        XCTAssertTrue(observer->last.to.provisional);
        XCTAssertFalse(observer->last.from.provisional);
        
        [OneSignal promptForPushNotificationsWithUserResponse:nil];
        
        [UnitTestCommonMethods runBackgroundThreads];
        
        [UnitTestCommonMethods answerNotificationPrompt:true];
        [UnitTestCommonMethods runBackgroundThreads];
        
        XCTAssertFalse(UNUserNotificationCenterOverrider.lastRequestedAuthorizationOptions == (UNAuthorizationOptions)(1 << 6));
        XCTAssertFalse(observer->last.to.provisional);
        XCTAssertTrue(observer->last.from.provisional);
    }
}

// if the app sets autoPrompt to true, there is no point in requesting provisional authorization
// thus, the SDK should never request it if autoPrompt = true.
- (void)testProvisionalOverridenByAutoPrompt {
    if (@available(iOS 12, *)) {
        OSPermissionStateTestObserver* observer = [self setupProvisionalTest];
        
        [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
                handleNotificationAction:nil
                                settings:@{kOSSettingsKeyAutoPrompt: @true}];
        
        [UnitTestCommonMethods runBackgroundThreads];
        
        //ensure the SDK did not request provisional authorization
        XCTAssertFalse(observer->last.to.provisional);
        XCTAssertFalse(observer->last.from.provisional);
    }
}

- (void)testNoProvisionalAuthorization {
    if (@available(iOS 12, *)) {
        [UnitTestCommonMethods clearStateForAppRestart:self];
        
        [UNUserNotificationCenterOverrider setNotifTypesOverride:0];
        [UNUserNotificationCenterOverrider setAuthorizationStatus:@0];
        
        OneSignalHelperOverrider.mockIOSVersion = 12;
        
        [OneSignalClientOverrider setShouldUseProvisionalAuth:false];
        
        OSPermissionStateTestObserver* observer = [OSPermissionStateTestObserver new];
        [OneSignal addPermissionObserver:observer];
        
        [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
                handleNotificationAction:nil
                                settings:@{kOSSettingsKeyAutoPrompt: @false}];
        
        [UnitTestCommonMethods runBackgroundThreads];
        
        //ensure the SDK did not request provisional authorization
        XCTAssertFalse(observer->last.to.provisional);
        XCTAssertFalse(observer->last.from.provisional);
    }
}

@end
