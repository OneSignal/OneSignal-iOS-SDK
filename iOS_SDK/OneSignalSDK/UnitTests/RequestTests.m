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
#import "OSRequests.h"
#import "OSOutcomesRequests.h"
#import "OSFocusRequests.h"
#import "OSInAppMessagingRequests.h"
#import "OSLocationRequests.h"
#import "OSOutcomeEvent.h"
#import "OneSignalHelper.h"
#import "OSInfluenceDataDefines.h"
#import "OneSignalCommonDefines.h"
#import "OSInAppMessageBridgeEvent.h"
#import "OSInAppMessagingHelpers.h"
#import "OSFocusInfluenceParam.h"
#import "OneSignalClientOverrider.h"
#import "UnitTestCommonMethods.h"

@interface RequestTests : XCTestCase

@end

@implementation RequestTests {
    NSString *testAppId;
    NSString *testUserId;
    NSString *testExternalUserId;
    NSString *testExternalUserIdHashToken;
    NSString *testEmailUserId;
    NSString *testMessageId;
    NSString *testEmailAddress;
    NSString *testInAppMessageId;
    NSString *testInAppMessageAppId;
    NSString *testInAppMessageVariantId;
    NSString *testInAppMessagePageId;
    NSString *testLiveActivityId;
    NSString *testLiveActivityToken;
    NSString *testNotificationId;
    OSOutcomeEvent *testOutcome;
    NSNumber *testDeviceType;
    
    OSInAppMessageBridgeEvent *testBridgeEvent;
    OSInAppMessageAction *testAction;
}

/*
 Put setup code here
 This method is called before the invocation of each test method in the class
 */
- (void)setUp {
    [super setUp];
    [UnitTestCommonMethods beforeEachTest:self];
    
    testAppId = @"test_app_id";
    testUserId = @"test_user_id";
    testEmailUserId = @"test_email_user_id";
    testExternalUserId = @"test_external_id";
    testExternalUserIdHashToken = @"testExternalUserIdHashToken";
    testEmailAddress = @"test@test.com";
    testMessageId = @"test_message_id";
    testInAppMessageId = @"test_in_app_message_id";
    testInAppMessageAppId = @"test_in_app_message_app_id";
    testInAppMessageVariantId = @"test_in_app_message_variant_id";
    testInAppMessagePageId = @"test_in_app_message_page_id";
    testLiveActivityId = @"test_live_activity_id";
    testLiveActivityToken = @"test_live_activity_token";
    testNotificationId = @"test_notification_id";
    
    testOutcome = [[OSOutcomeEvent new] initWithSession:UNATTRIBUTED
                                        notificationIds:@[]
                                                   name:@"test_outcome_id"
                                              timestamp:@0
                                                 weight:@0];
    
    testDeviceType = @0;
    
    testBridgeEvent = [OSInAppMessageBridgeEvent instanceWithJson:@{
        @"type" : @"action_taken",
        @"body" : @{
                @"id" : @"test_id",
                @"url" : @"https://www.onesignal.com",
                @"url_target" : @"browser",
                @"close" : @false
                }
        }];

    testAction = testBridgeEvent.userAction;
    testAction.firstClick = true;
    
}

/*
 Put teardown code here
 This method is called after the invocation of each test method in the class
 */
- (void)tearDown {
    [super tearDown];
}

NSString *urlStringForRequest(OneSignalRequest *request) {
    return correctUrlWithPath(request.path);
}

NSString *correctUrlWithPath(NSString *path) {
    return [OS_API_SERVER_URL stringByAppendingString:path];
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
            if (![second[key] isKindOfClass:[NSDictionary class]])
                return false;
            if (!dictionariesAreEquivalent((NSDictionary *)first[key], (NSDictionary *)second[key]))
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

BOOL checkHttpHeaders(NSDictionary *additionalHeaders, NSDictionary *correct) {
    return dictionariesAreEquivalent(additionalHeaders, correct);
}

- (void)testBuildGetTags {
    let request = [OSRequestGetTags withUserId:testUserId appId:testAppId];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@?app_id=%@", testUserId, testAppId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
}

- (void)testBuildGetIosParams {
    let request = [OSRequestGetIosParams withUserId:testUserId appId:testAppId];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"apps/%@/ios_params.js?player_id=%@", testAppId, testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
}

- (void)testBuildPostNotification {
    let request = [OSRequestPostNotification withAppId:testAppId withJson:[@{} mutableCopy]];
    
    let correctUrl = correctUrlWithPath(@"notifications");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId}));
}

- (void)testSendTags {
    let request = [OSRequestSendTagsToServer withUserId:testUserId appId:testAppId tags:@{} networkType:@0 withEmailAuthHashToken:nil withExternalIdAuthHashToken:nil];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"tags" : @{}, @"net_type" : @0}));
}

- (void)testSendDirectOutcome {
    NSArray * testNotificationIds = [NSArray arrayWithObject:testNotificationId];
    testOutcome = [[OSOutcomeEvent new] initWithSession:DIRECT notificationIds:testNotificationIds name:@"test" timestamp:@0 weight:@0];
    
    let request = [OSRequestSendOutcomesV1ToServer directWithOutcome:testOutcome appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"id" : @"test", @"device_type" : testDeviceType, @"direct" : @YES, @"notification_ids" : testNotificationIds}));
}

- (void)testSendIndirectOutcome {
    NSArray * testNotificationIds = [NSArray arrayWithObject:testNotificationId];
    testOutcome = [[OSOutcomeEvent new] initWithSession:INDIRECT notificationIds:testNotificationIds name:@"test" timestamp:@0 weight:@1];
    
    let request = [OSRequestSendOutcomesV1ToServer indirectWithOutcome:testOutcome appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"id" : @"test", @"device_type" : testDeviceType, @"direct" : @NO, @"weight" : @1, @"notification_ids" : testNotificationIds}));
}

- (void)testSendUnattributedOutcome {
    testOutcome = [[OSOutcomeEvent new] initWithSession:UNATTRIBUTED notificationIds:nil name:@"test" timestamp:@0 weight:@0];
    
    let request = [OSRequestSendOutcomesV1ToServer unattributedWithOutcome:testOutcome appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"id" : @"test", @"device_type" : testDeviceType}));
}

- (void)testSendDirectOutcomeWithNotificationV2 {
    NSArray * testNotificationIds = [NSArray arrayWithObject:testNotificationId];
    OSOutcomeSourceBody *sourceBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:testNotificationIds inAppMessagesIds:nil];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:sourceBody indirectBody:nil];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@0 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"sources" : @{
                @"direct" : @{
                        @"notification_ids" : @[testNotificationId]
                },
        }
    }));
}

- (void)testSendIndirectOutcomeWithNotificationV2 {
    NSArray * testNotificationIds = [NSArray arrayWithObject:testNotificationId];
    OSOutcomeSourceBody *sourceBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:testNotificationIds inAppMessagesIds:nil];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:nil indirectBody:sourceBody];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@0 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"sources" : @{
                @"indirect" : @{
                        @"notification_ids" : @[testNotificationId]
                },
        }
    }));
}

- (void)testSendIndirectOutcomeWithNotificationV2AndWeight {
    NSArray * testNotificationIds = [NSArray arrayWithObject:testNotificationId];
    OSOutcomeSourceBody *sourceBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:testNotificationIds inAppMessagesIds:nil];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:nil indirectBody:sourceBody];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@10 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"weight": @10,
        @"sources" : @{
                @"indirect" : @{
                        @"notification_ids" : @[testNotificationId]
                },
        }
    }));
}

- (void)testSendDirectOutcomeWithInAppMessageV2 {
    NSArray * testIAMIds = [NSArray arrayWithObject:testNotificationId];
    OSOutcomeSourceBody *sourceBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:nil inAppMessagesIds:testIAMIds];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:sourceBody indirectBody:nil];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@0 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"sources" : @{
                @"direct" : @{
                        @"in_app_message_ids" : @[testNotificationId]
                },
        }
    }));
}

- (void)testSendIndirectOutcomeWithInAppMessageV2 {
    NSArray * testIAMIds = [NSArray arrayWithObjects:testNotificationId, @"iam_test", nil];
    OSOutcomeSourceBody *sourceBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:nil inAppMessagesIds:testIAMIds];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:nil indirectBody:sourceBody];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@0 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"sources" : @{
                @"indirect" : @{
                        @"in_app_message_ids" : @[testNotificationId, @"iam_test"]
                },
        }
    }));
}

- (void)testSendIndirectOutcomeWithInAppMessageV2AndWeight {
    NSArray * testIAMIds = [NSArray arrayWithObjects:testNotificationId, @"iam_test", nil];
    OSOutcomeSourceBody *sourceBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:nil inAppMessagesIds:testIAMIds];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:nil indirectBody:sourceBody];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@9.99999 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"weight" : @9.99999,
        @"sources" : @{
                @"indirect" : @{
                        @"in_app_message_ids" : @[testNotificationId, @"iam_test"]
                },
        }
    }));
}

- (void)testSendDirectOutcomeWithNotificationAndInAppMessageV2 {
    NSArray * testNotificationIds = [NSArray arrayWithObject:testNotificationId];
    NSArray * testIAMIds = [NSArray arrayWithObject:testNotificationId];
    OSOutcomeSourceBody *sourceBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:testNotificationIds inAppMessagesIds:testIAMIds];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:sourceBody indirectBody:nil];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@0 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"sources" : @{
                @"direct" : @{
                        @"notification_ids" : @[testNotificationId],
                        @"in_app_message_ids" : @[testNotificationId]
                },
        }
    }));
}

- (void)testSendIndirectOutcomeWithNotificationAndInAppMessageV2 {
    NSArray * testNotificationIds = [NSArray arrayWithObjects:testNotificationId, @"notification_test", nil];
    NSArray * testIAMIds = [NSArray arrayWithObjects:testNotificationId, @"iam_test", nil];
    OSOutcomeSourceBody *sourceBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:testNotificationIds inAppMessagesIds:testIAMIds];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:nil indirectBody:sourceBody];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@0 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"sources" : @{
                @"indirect" : @{
                        @"notification_ids" : @[testNotificationId, @"notification_test"],
                        @"in_app_message_ids" : @[testNotificationId, @"iam_test"]
                },
        }
    }));
}

- (void)testSendDirectAndIndirectOutcomeWithNotificationAndInAppMessageV2 {
    NSArray * testNotificationIds = [NSArray arrayWithObject:testNotificationId];
    NSArray * testIAMIds = [NSArray arrayWithObject:testNotificationId];
    OSOutcomeSourceBody *directBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:testNotificationIds inAppMessagesIds:testIAMIds];
    OSOutcomeSourceBody *indirectBody = [[OSOutcomeSourceBody alloc] initWithNotificationIds:testNotificationIds inAppMessagesIds:testIAMIds];
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:directBody indirectBody:indirectBody];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@0 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"sources" : @{
                @"direct" : @{
                        @"notification_ids" : @[testNotificationId],
                        @"in_app_message_ids" : @[testNotificationId]
                },
                @"indirect" : @{
                        @"notification_ids" : @[testNotificationId, @"notification_test"],
                        @"in_app_message_ids" : @[testNotificationId, @"iam_test"]
                }
        }
    }));
}

- (void)testSendUnattributedOutcomeV2 {
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:nil indirectBody:nil];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@0 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"sources" : @{}
    }));
}

- (void)testSendUnattributedOutcomeV2WithWeight {
    OSOutcomeSource *outcomeSource = [[OSOutcomeSource alloc] initWithDirectBody:nil indirectBody:nil];
    OSOutcomeEventParams *eventParams = [[OSOutcomeEventParams alloc] initWithOutcomeId:@"test" outcomeSource:outcomeSource weight:@9.9999999999 timestamp:@0];
    
    let request = [OSRequestSendOutcomesV2ToServer measureOutcomeEvent:eventParams appId:testAppId deviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath(@"outcomes/measure_sources");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
        @"app_id" : testAppId,
        @"device_type" : testDeviceType,
        @"id" : @"test",
        @"weight" : @9.9999999999,
        @"sources" : @{}
    }));
}

- (void)testUpdateDeviceToken {
    let request = [OSRequestUpdateDeviceToken withUserId:testUserId appId:testAppId deviceToken:@"test_device_token" notificationTypes:@0 externalIdAuthToken:@"external_id_auth_token"];

    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"notification_types" : @0, @"identifier" : @"test_device_token", @"external_user_id_auth_hash" : @"external_id_auth_token"}));
}

- (void)testUpdateEmailDeviceToken {
    let request = [OSRequestUpdateDeviceToken withUserId:testUserId appId:testAppId deviceToken:@"test_device_token" withParentId:@"test_parent_id" emailAuthToken:nil email:testEmailAddress externalIdAuthToken:@"external_id_auth_token"];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"email" : testEmailAddress, @"identifier" : @"test_device_token", @"parent_player_id" : @"test_parent_id", @"external_user_id_auth_hash" : @"external_id_auth_token"}));
}

- (void)testCreateDevice {
    let request = [OSRequestCreateDevice withAppId:testAppId withDeviceType:@0 withEmail:testEmailAddress withPlayerId:testUserId withEmailAuthHash:nil withExternalUserId:nil withExternalIdAuthToken:nil];
    
    let correctUrl = correctUrlWithPath(@"players");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"device_type" : @0, @"identifier" : testEmailAddress, @"email_auth_hash" : [NSNull null], @"external_user_id_auth_hash" : [NSNull null], @"device_player_id" : testUserId}));
}

- (void)testCreateDeviceWithAuthHash {
    let request = [OSRequestCreateDevice withAppId:testAppId withDeviceType:@0 withEmail:testEmailAddress withPlayerId:testUserId withEmailAuthHash:nil withExternalUserId: @"external_user_id" withExternalIdAuthToken:@"external_id_auth_token"];
    
    let correctUrl = correctUrlWithPath(@"players");
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"device_type" : @0, @"identifier" : testEmailAddress, @"email_auth_hash" : [NSNull null], @"device_player_id" : testUserId, @"external_user_id" : @"external_user_id", @"external_user_id_auth_hash" : @"external_id_auth_token"}));
}

- (void)testUpdateNotificationTypes {
    let request = [OSRequestUpdateNotificationTypes withUserId:testUserId appId:testAppId notificationTypes:@0];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"notification_types" : @0}));
}

- (void)testSendPurchases {
    let standardRequest = [OSRequestSendPurchases withUserId:testUserId externalIdAuthToken:@"external_id_auth_hash" appId:testAppId withPurchases:@[]];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_purchase", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:standardRequest.urlRequest.URL.absoluteString]);
    
    let emailRequest = [OSRequestSendPurchases withUserId:testUserId emailAuthToken:@"email_auth_token" appId:testAppId withPurchases:@[]];
    
    XCTAssertTrue([correctUrl isEqualToString:emailRequest.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(standardRequest.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"purchases" : @[], @"external_user_id_auth_hash" : @"external_id_auth_hash"}));
    
    XCTAssertTrue(checkHttpBody(emailRequest.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"purchases" : @[], @"email_auth_hash" : @"email_auth_token"}));
}

- (void)testSubmitNotificationOpened {
    let request = [OSRequestSubmitNotificationOpened withUserId:testUserId appId:testAppId wasOpened:true messageId:testMessageId withDeviceType:testDeviceType];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"notifications/%@", testMessageId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"player_id" : testUserId, @"app_id" : testAppId, @"opened" : @1, @"device_type": testDeviceType}));
}

- (void)testRegisterUser {
    let request = [OSRequestRegisterUser withData:@{@"test_key" : @"test_value"} userId:testUserId];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_session", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"test_key" : @"test_value"}));
}

- (void)testSyncHashedEmail {
    let request = [OSRequestSyncHashedEmail withUserId:testUserId appId:testAppId email:testEmailAddress networkType:@1];
    
    let lowerCase = [testEmailAddress lowercaseString];
    let md5Hash = [OneSignalHelper hashUsingMD5:lowerCase];
    let sha1Hash = [OneSignalHelper hashUsingSha1:lowerCase];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"em_m" : md5Hash, @"em_s" : sha1Hash, @"net_type" : @1}));
}

- (void)testSendLocation {
    os_last_location *location = (os_last_location*)malloc(sizeof(os_last_location));
    
    location->verticalAccuracy = 1.0;
    location->horizontalAccuracy = 2.0;
    location->cords.latitude = 3.0;
    location->cords.longitude = 4.0;
    
    let request = [OSRequestSendLocation withUserId:testUserId appId:testAppId location:location networkType:@0 backgroundState:true emailAuthHashToken:nil externalIdAuthToken:nil];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"lat" : @3.0, @"long" : @4.0, @"loc_acc_vert" : @1.0, @"loc_acc" : @2.0, @"net_type" : @0, @"loc_bg" : @1}));
}

- (void)testSendLocationWithAuthToken {
    os_last_location *location = (os_last_location*)malloc(sizeof(os_last_location));
    
    location->verticalAccuracy = 1.0;
    location->horizontalAccuracy = 2.0;
    location->cords.latitude = 3.0;
    location->cords.longitude = 4.0;
    
    let request = [OSRequestSendLocation withUserId:testUserId appId:testAppId location:location networkType:@0 backgroundState:true emailAuthHashToken:nil externalIdAuthToken:@"external_id_auth_token"];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    
    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"lat" : @3.0, @"long" : @4.0, @"loc_acc_vert" : @1.0, @"loc_acc" : @2.0, @"net_type" : @0, @"loc_bg" : @1, @"external_user_id_auth_hash" : @"external_id_auth_token"}));
}

- (void)testOnFocus {
    let firstRequest = [OSRequestBadgeCount withUserId:testUserId appId:testAppId badgeCount:@0 emailAuthToken:nil externalIdAuthToken:nil];
    
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);
    NSArray * testNotificationIds = [NSArray arrayWithObject:testNotificationId];
    
    XCTAssertTrue([correctUrl isEqualToString:firstRequest.urlRequest.URL.absoluteString]);
    
    OSFocusInfluenceParam *influenceParams = [[OSFocusInfluenceParam alloc] initWithParamsInfluenceIds:[NSArray arrayWithObject:testNotificationId] influenceKey:@"notification_ids" directInfluence:NO influenceDirectKey:@"direct"];
    let secondRequest = [OSRequestOnFocus withUserId:testUserId appId:testAppId activeTime:@2 netType:@3 deviceType:testDeviceType influenceParams:[NSArray arrayWithObject:influenceParams]];

    let secondCorrectUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@/on_focus", testUserId]);
    
    XCTAssertTrue([secondCorrectUrl isEqualToString:secondRequest.urlRequest.URL.absoluteString]);
    
    XCTAssertTrue(checkHttpBody(firstRequest.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"badgeCount" : @0}));
    
    XCTAssertTrue(checkHttpBody(secondRequest.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"state" : @"ping", @"type" : @1, @"active_time" : @2, @"net_type" : @3, @"device_type" : testDeviceType, @"direct" : @NO, @"notification_ids": testNotificationIds}));
}

- (void)testInAppMessageViewed {
    let request = [OSRequestInAppMessageViewed withAppId:testAppId withPlayerId:testUserId withMessageId:testInAppMessageId forVariantId:testInAppMessageVariantId];
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"in_app_messages/%@/impression", testInAppMessageId]);

    XCTAssertEqualObjects(correctUrl, request.urlRequest.URL.absoluteString);
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
       @"device_type": @0,
       @"player_id": testUserId,
       @"app_id": testAppId,
       @"variant_id": testInAppMessageVariantId
    }));
}

- (void)testInAppMessageClicked {
    let request = [OSRequestInAppMessageClicked
                   withAppId:testAppId
                   withPlayerId:testUserId
                   withMessageId:testInAppMessageId
                   forVariantId:testInAppMessageVariantId
                   withAction:testAction];
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"in_app_messages/%@/click", testInAppMessageId]);

    XCTAssertEqualObjects(correctUrl, request.urlRequest.URL.absoluteString);
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
       @"app_id": testAppId,
       @"device_type": @0,
       @"player_id": testUserId,
       @"click_id": testAction.clickId ?: @"",
       @"variant_id": testInAppMessageVariantId,
       @"first_click": @(testAction.firstClick)
   }));
}

- (void)testLoadMessageContent {
    [UnitTestCommonMethods initOneSignal];

    let htmlContents = [OSInAppMessageTestHelper testInAppMessageGetContainsWithHTML:OS_DUMMY_HTML];
    [OneSignalClientOverrider setMockResponseForRequest:NSStringFromClass([OSRequestLoadInAppMessageContent class]) withResponse:htmlContents];

    let request = [OSRequestLoadInAppMessageContent withAppId:testInAppMessageAppId withMessageId:testInAppMessageId withVariantId:testInAppMessageVariantId];

    let iamUrlPath = [NSString stringWithFormat:@"in_app_messages/%@/variants/%@/html?app_id=%@",
                      testInAppMessageId,
                      testInAppMessageVariantId,
                      testInAppMessageAppId
    ];

    XCTAssertEqualObjects(request.urlRequest.URL.absoluteString, correctUrlWithPath(iamUrlPath));
    XCTAssertEqualObjects(request.urlRequest.HTTPMethod, @"GET");
    XCTAssertEqualObjects(request.urlRequest.allHTTPHeaderFields[@"Accept"], @"application/vnd.onesignal.v1+json");
    XCTAssertFalse(request.dataRequest);
}

- (void)testSendExternalUserId {
    let request = [OSRequestUpdateExternalUserId withUserId:testExternalUserId withUserIdHashToken:nil withOneSignalUserId:testUserId appId:testAppId];

    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);

    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"external_user_id" : testExternalUserId}));
}

- (void)testSendExternalUserIdWithForwardSlashes {
    let externalUserId = @"abc/123";
    let request = [OSRequestUpdateExternalUserId withUserId:externalUserId withUserIdHashToken:nil withOneSignalUserId:testUserId appId:testAppId];
    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);

    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"external_user_id" : externalUserId}));
}

- (void)testSendExternalWithAuthUserId {
    let request = [OSRequestUpdateExternalUserId withUserId:testExternalUserId withUserIdHashToken:testExternalUserIdHashToken withOneSignalUserId:testUserId appId:testAppId];

    let correctUrl = correctUrlWithPath([NSString stringWithFormat:@"players/%@", testUserId]);

    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId, @"external_user_id" : testExternalUserId, @"external_user_id_auth_hash" : testExternalUserIdHashToken}));
}

- (void)testSendTrackUsageRequest {
    NSString *testUsageData = @"test usage data";
    let request = [OSRequestTrackV1 trackUsageData:testUsageData appId:testAppId];
    let correctUrl = correctUrlWithPath(@"v1/track");

    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"app_id" : testAppId}));
    XCTAssertTrue(checkHttpHeaders(request.additionalHeaders, @{@"app_id" : testAppId,
                                                                @"OS-Usage-Data" : testUsageData,
                                                              }));
}

- (void)testEnterLiveActivity {
    let request = [OSRequestLiveActivityEnter withUserId:testUserId appId:testAppId activityId:testLiveActivityId token:testLiveActivityToken];
    
    let testEnterLiveActivityUrlPath = [NSString stringWithFormat:@"apps/%@/live_activities/%@/token",
                                        testAppId,
                                        testLiveActivityId];
    
    let correctUrl = correctUrlWithPath(testEnterLiveActivityUrlPath);

    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{@"push_token" : testLiveActivityToken, @"subscription_id" : testUserId }));
    
    XCTAssertEqualObjects(request.urlRequest.HTTPMethod, @"POST");
    XCTAssertEqualObjects(request.urlRequest.allHTTPHeaderFields[@"Accept"], @"application/vnd.onesignal.v1+json");
}

- (void)testExitLiveActivity {
    let request = [OSRequestLiveActivityExit withUserId:testUserId appId:testAppId activityId:testLiveActivityId];
    
    let testExitLiveActivityUrlPath = [NSString stringWithFormat:@"apps/%@/live_activities/%@/token/%@",
                                        testAppId,
                                        testLiveActivityId,
                                        testUserId];
    
    let correctUrl = correctUrlWithPath(testExitLiveActivityUrlPath);

    XCTAssertTrue([correctUrl isEqualToString:request.urlRequest.URL.absoluteString]);
    
    XCTAssertEqualObjects(request.urlRequest.HTTPBody, nil);
    XCTAssertEqualObjects(request.urlRequest.HTTPMethod, @"DELETE");
    XCTAssertEqualObjects(request.urlRequest.allHTTPHeaderFields[@"Accept"], @"application/vnd.onesignal.v1+json");
}

- (void)testAdditionalHeaders {
    // Create a fake request
    let request = [OneSignalRequest new];
    let params = [NSMutableDictionary new];
    let headers = [NSMutableDictionary new];
    params[@"app_id"] = testAppId;
    headers[@"app_id"] = testAppId;
    headers[@"test-header"] = @"test_header_value";
    request.method = POST;
    request.path = @"test/path";
    request.parameters = params;
    request.additionalHeaders = headers;
    
    // Properties must be set in the request before accessing urlRequest
    let urlRequest = request.urlRequest;
    let requestHeaders = urlRequest.allHTTPHeaderFields;
    // Verify that all headers we added via additionalHeaders are in the request's header fields
    for (NSString *key in headers) {
        XCTAssertTrue(requestHeaders[key] != nil);
    }
}

@end
