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
#import "UnitTestCommonMethods.h"
#import "OneSignalExtensionBadgeHandler.h"
#import "NSUserDefaultsOverrider.h"
#import "UNUserNotificationCenterOverrider.h"
#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalHelperOverrider.h"
#import "OneSignalHelper.h"
#import "OneSignalNotificationServiceExtensionHandler.h"

@interface BadgeTests : XCTestCase

@end

@implementation BadgeTests

- (void)setUp {
    [super setUp];
    
    OneSignalHelperOverrider.mockIOSVersion = 10;
    
    [OneSignalUNUserNotificationCenter setUseiOS10_2_workaround:true];
    
    UNUserNotificationCenterOverrider.notifTypesOverride = 7;
    UNUserNotificationCenterOverrider.authorizationStatus = [NSNumber numberWithInteger:UNAuthorizationStatusAuthorized];
    
    [NSUserDefaultsOverrider clearInternalDictionary];
    
    [UnitTestCommonMethods clearStateForAppRestart:self];
    
    [UnitTestCommonMethods beforeAllTest];
}
- (void)testBadgeExtensionUpdate {
    [OneSignalExtensionBadgeHandler updateCachedBadgeValue:0];
    
    //test that manually setting the badge number also updates NSUserDefaults for our app group
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
    
    XCTAssert(OneSignalExtensionBadgeHandler.currentCachedBadgeValue == 1);
    
    NSMutableDictionary * userInfo = [@{
        @"aps": @{
            @"mutable-content": @1,
            @"alert": @"Message Body"
        },
        @"os_data": @{
            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
            @"badge_inc" : @2
        }
    } mutableCopy];
    
    UNNotificationResponse *notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
    //test that receiving a notification with badge_inc updates the badge icon number
    [OneSignalNotificationServiceExtensionHandler didReceiveNotificationExtensionRequest:notifResponse.notification.request withMutableNotificationContent:nil];
    
    XCTAssert(OneSignalExtensionBadgeHandler.currentCachedBadgeValue == 3);
    
    //test that a negative badge_inc value decrements correctly
    [userInfo setObject:@{@"badge_inc" : @-1, @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"} forKey:@"os_data"];
    
    UNNotificationResponse *newNotifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
    [OneSignalNotificationServiceExtensionHandler didReceiveNotificationExtensionRequest:newNotifResponse.notification.request withMutableNotificationContent:nil];
    
    XCTAssert(OneSignalExtensionBadgeHandler.currentCachedBadgeValue == 2);
}

//tests to make sure that setting the badge works along with incrementing/decrementing
- (void)testSetBadgeExtensionUpdate {
    [OneSignalExtensionBadgeHandler updateCachedBadgeValue:0];
    
    NSMutableDictionary * userInfo = [@{
        @"aps": @{
            @"mutable-content": @1,
            @"alert": @"Message Body",
            @"badge" : @54
        },
        @"os_data": @{
            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"
        }
    } mutableCopy];
    
    UNNotificationResponse *notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
    //test that receiving a notification with badge_inc updates the badge icon number
    [OneSignalNotificationServiceExtensionHandler didReceiveNotificationExtensionRequest:notifResponse.notification.request withMutableNotificationContent:nil];
    
    XCTAssert(OneSignalExtensionBadgeHandler.currentCachedBadgeValue == 54);
    
    [userInfo setObject:@{@"mutable-content" : @1, @"alert" : @"test msg"} forKey:@"aps"];
    [userInfo setObject:@{@"badge_inc" : @-1, @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"} forKey:@"os_data"];
    
    UNNotificationResponse *newNotifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent *mutableContent = [newNotifResponse.notification.request.content mutableCopy];
    
    //tests to make sure the extension is correctly modifying the badge value of the replacement content
    let replacementContent = [OneSignalNotificationServiceExtensionHandler didReceiveNotificationExtensionRequest:newNotifResponse.notification.request withMutableNotificationContent:mutableContent];
    
    XCTAssert([replacementContent.badge intValue] == 53);
    
    XCTAssert(OneSignalExtensionBadgeHandler.currentCachedBadgeValue == 53);
}

//tests to make sure that the SDK never tries to set negative badge values
- (void)testDecrementZeroValue {
    [OneSignalExtensionBadgeHandler updateCachedBadgeValue:0];
    
    NSMutableDictionary * userInfo = [@{
        @"aps": @{
            @"mutable-content": @1,
            @"alert": @"Message Body"
        },
        @"os_data": @{
            @"i": @"b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
            @"badge_inc" : @-5
        }
    } mutableCopy];
    
    UNNotificationResponse *notifResponse = [UnitTestCommonMethods createBasiciOSNotificationResponseWithPayload:userInfo];
    
    UNMutableNotificationContent *mutableContent = [notifResponse.notification.request.content mutableCopy];
    
    //Since the notification is trying to set a negative value, the SDK should keep the badge count == 0
    let replacementContent = [OneSignalNotificationServiceExtensionHandler didReceiveNotificationExtensionRequest:notifResponse.notification.request withMutableNotificationContent:mutableContent];
    
    XCTAssert(replacementContent.badge.intValue == 0);
    
    XCTAssert(OneSignalExtensionBadgeHandler.currentCachedBadgeValue == 0);
}

@end
