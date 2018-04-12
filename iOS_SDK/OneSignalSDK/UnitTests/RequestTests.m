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
#import "Requests.h"
#import "OneSignalHelper.h"
#import "Requests.h"
#import "OneSignalCommonDefines.h"

@interface RequestTests : XCTestCase

@end

@implementation RequestTests {
    NSString *testAppId;
    NSString *testUserId;
    NSString *testEmailUserId;
    NSString *testMessageId;
    NSString *testEmailAddress;
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    testAppId = @"test_app_id";
    testUserId = @"test_user_id";
    testEmailUserId = @"test_email_user_id";
    testEmailAddress = @"test@test.com";
    testMessageId = @"test_message_id";
}

NSString *urlStringForRequest(OneSignalRequest *request) {
    return correctUrlWithPath(request.path);
}

NSString *correctUrlWithPath(NSString *path) {
    return [[SERVER_URL stringByAppendingString:API_VERSION] stringByAppendingString:path];
}

// only works for dictionaries with values that are strings, numbers, or sub-dictionaries/arrays of strings and numbers
// since this is all our SDK uses, it should suffice.
BOOL dictionariesAreEquivalent(NSDictionary *first, NSDictionary *second) {
    let firstKeys = first.allKeys;
    let secondKeys = second.allKeys;
    
    if (firstKeys.count != secondKeys.count)
        return false;
    
    for (id key in firstKeys) {
        if (![secondKeys containsObject:key]) {
            return false;
        } else if ([first[key] isKindOfClass:[NSString class]] && ![(NSString *)first[key] isEqualToString:(NSString *)second[key]]) {
            return false;
        } else if ([first[key] isKindOfClass:[NSNumber class]] && ![(NSNumber *)first[key] isEqualToNumber:(NSNumber *)second[key]]) {
            return false;
        } else if ([first[key] isKindOfClass:[NSDictionary class]]) {
            if (![second[key] isKindOfClass:[NSDictionary class]] && !dictionariesAreEquivalent((NSDictionary *)first[key], (NSDictionary *)second[key]))
                return false;
        } else if ([first[key] isKindOfClass:[NSArray class]]) {
            if (![second[key] isKindOfClass:[NSArray class]])
                return false;
            
            let firstArray = (NSArray *)first[key];
            let secondArray = (NSArray *)second[key];
            
            for (id element in firstArray)
                if (![secondArray containsObject:element])
                    return false;
        }
    }
    
    return true;
}

BOOL checkHttpBody(NSData *bodyData, NSDictionary *correct) {
    NSError *error;
    NSDictionary *serialized = [NSJSONSerialization JSONObjectWithData:bodyData options:NSJSONReadingAllowFragments error:&error];
    
    if (error)
        return false;
    
    return dictionariesAreEquivalent(serialized, correct);
}

- (void)testBuildGetTags {
    let request = [OSRequestGetTags withUserId:testUserId appId:testAppId];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@?app_id=%@", testUserId, testAppId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
}

- (void)testBuildGetIosParams {
    let request = [OSRequestGetIosParams withUserId:testUserId appId:testAppId];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"apps/%@/ios_params.js?player_id=%@", testAppId, testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
}

- (void)testBuildPostNotification {
    let request = [OSRequestPostNotification withAppId:testAppId withJson:[@{} mutableCopy]];
    
    let correctUrl = correctUrlWithPath(@"notifications");
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"app_id" : testAppId}));
}

- (void)testSendTags {
    let request = [OSRequestSendTagsToServer withUserId:testUserId appId:testAppId tags:@{} networkType:@0 withEmailAuthHashToken:nil];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"app_id" : testAppId, @"tags" : @{}, @"net_type" : @0}));
}

- (void)testUpdateDeviceToken {
    let request = [OSRequestUpdateDeviceToken withUserId:testUserId appId:testAppId deviceToken:@"test_device_token" notificationTypes:@0 withParentId:@"test_parent_id" emailAuthToken:nil email:testEmailAddress];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"app_id" : testAppId, @"email" : testEmailAddress, @"notification_types" : @0, @"identifier" : @"test_device_token", @"parent_player_id" : @"test_parent_id"}));
}

- (void)testCreateDevice {
    let request = [OSRequestCreateDevice withAppId:testAppId withDeviceType:@0 withEmail:testEmailAddress withPlayerId:testUserId withEmailAuthHash:nil];
    
    let correctUrl = correctUrlWithPath(@"players");
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"app_id" : testAppId, @"device_type" : @0, @"identifier" : testEmailAddress, @"email_auth_hash" : [NSNull null], @"device_player_id" : testUserId}));
}

- (void)testLogoutEmail {
    let request = [OSRequestLogoutEmail withAppId:testAppId emailPlayerId:testEmailUserId devicePlayerId:testUserId emailAuthHash:nil];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/email_logout", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"parent_player_id" : testEmailUserId, @"email_auth_hash" : [NSNull null], @"app_id" : testAppId}));
}

- (void)testUpdateNotificationTypes {
    let request = [OSRequestUpdateNotificationTypes withUserId:testUserId appId:testAppId notificationTypes:@0];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"app_id" : testAppId, @"notification_types" : @0}));
}

- (void)testSendPurchases {
    let standardRequest = [OSRequestSendPurchases withUserId:testUserId appId:testAppId withPurchases:@[]];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_purchase", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:standardRequest.request.URL.absoluteString]);
    
    let emailRequest = [OSRequestSendPurchases withUserId:testUserId emailAuthToken:@"email_auth_token" appId:testAppId withPurchases:@[]];
    
    XCTAssertTrue([correctUrl isEqualToString:emailRequest.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(standardRequest.request.HTTPBody, @{@"app_id" : testAppId, @"purchases" : @[]}));
    
    XCTAssertTrue(checkHttpBody(emailRequest.request.HTTPBody, @{@"app_id" : testAppId, @"purchases" : @[], @"email_auth_hash" : @"email_auth_token"}));
}

- (void)testSubmitNotificationOpened {
    let request = [OSRequestSubmitNotificationOpened withUserId:testUserId appId:testAppId wasOpened:true messageId:testMessageId];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"notifications/%@", testMessageId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"player_id" : testUserId, @"app_id" : testAppId, @"opened" : @1}));
}

- (void)testRegisterUser {
    let request = [OSRequestRegisterUser withData:@{@"test_key" : @"test_value"} userId:testUserId];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_session", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"test_key" : @"test_value"}));
}

- (void)testSyncHashedEmail {
    let request = [OSRequestSyncHashedEmail withUserId:testUserId appId:testAppId email:testEmailAddress networkType:@1];
    
    let lowerCase = [testEmailAddress lowercaseString];
    let md5Hash = [OneSignalHelper hashUsingMD5:lowerCase];
    let sha1Hash = [OneSignalHelper hashUsingSha1:lowerCase];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"app_id" : testAppId, @"em_m" : md5Hash, @"em_s" : sha1Hash, @"net_type" : @1}));
}

- (void)testSendLocation {
    os_last_location *location = (os_last_location*)malloc(sizeof(os_last_location));
    
    location->verticalAccuracy = 1.0;
    location->horizontalAccuracy = 2.0;
    location->cords.latitude = 3.0;
    location->cords.longitude = 4.0;
    
    let request = [OSRequestSendLocation withUserId:testUserId appId:testAppId location:location networkType:@0 backgroundState:true emailAuthHashToken:nil];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.request.HTTPBody, @{@"app_id" : testAppId, @"lat" : @3.0, @"long" : @4.0, @"loc_acc_vert" : @1.0, @"loc_acc" : @2.0, @"net_type" : @0, @"loc_bg" : @1}));
}

- (void)testOnFocus {
    let firstRequest = [OSRequestOnFocus withUserId:testUserId appId:testAppId badgeCount:@0 emailAuthToken:nil];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:firstRequest.request.URL.absoluteString]);
    
    let secondRequest = [OSRequestOnFocus withUserId:testUserId appId:testAppId state:@"test_state" type:@1 activeTime:@2 netType:@3 emailAuthToken:nil];
    
    let secondCorrectUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_focus", testUserId]);
    
    XCTAssertTrue([secondCorrectUrl isEqualToString:secondRequest.request.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(firstRequest.request.HTTPBody, @{@"app_id" : testAppId, @"badgeCount" : @0}));
    
    XCTAssertTrue(checkHttpBody(secondRequest.request.HTTPBody, @{@"app_id" : testAppId, @"state" : @"test_state", @"type" : @1, @"active_time" : @2, @"net_type" : @3}));
}



@end
