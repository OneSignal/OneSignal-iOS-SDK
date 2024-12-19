/*
 Modified MIT License
 
 Copyright 2024 OneSignal
 
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
#import "OSInAppMessageBridgeEvent.h"
#import "OSInAppMessagingRequests.h"

@interface IAMRequestTests : XCTestCase

@end

@implementation IAMRequestTests {
    NSString *testAppId;
    NSString *testSubscriptionId;
    NSString *testMessageId;
    NSString *testVariantId;
    NSString *testPageId;
    OSInAppMessageBridgeEvent *testBridgeEvent;
    OSInAppMessageClickResult *testClickResult;
}

- (void)setUp {
    testAppId = @"test_app_id";
    testSubscriptionId = @"test_subscription_id";
    testMessageId = @"test_message_id";
    testVariantId = @"test_in_app_message_variant_id";
    testPageId = @"test_page_id";
    testBridgeEvent = [OSInAppMessageBridgeEvent instanceWithJson:@{
        @"type" : @"action_taken",
        @"body" : @{
                @"id" : @"test_id",
                @"url" : @"https://www.onesignal.com",
                @"url_target" : @"browser",
                @"close" : @false
                }
        }];

    testClickResult = testBridgeEvent.userAction;
    testClickResult.firstClick = true;
}

- (void)tearDown { }

NSString *correctUrlWithPath(NSString *path) {
    return [OS_API_SERVER_URL stringByAppendingString:path];
}

BOOL checkHttpBody(NSData *bodyData, NSDictionary *correct) {
    NSError *error;
    NSDictionary *serialized = [NSJSONSerialization JSONObjectWithData:bodyData options:NSJSONReadingAllowFragments error:&error];

    if (error) {
        return false;
    }

    return [serialized isEqualToDictionary:correct];
}

- (void)testInAppMessageViewed {
    OSRequestInAppMessageViewed *request = [OSRequestInAppMessageViewed
                                withAppId:testAppId
                                withPlayerId:testSubscriptionId
                                withMessageId:testMessageId
                                forVariantId:testVariantId];
    NSString *correctUrl = correctUrlWithPath([NSString stringWithFormat:@"in_app_messages/%@/impression", testMessageId]);

    XCTAssertEqualObjects(correctUrl, request.urlRequest.URL.absoluteString);
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
       @"device_type": @0,
       @"player_id": testSubscriptionId,
       @"app_id": testAppId,
       @"variant_id": testVariantId
    }));
}

- (void)testInAppMessageViewed_withNilArguments {
    OSRequestInAppMessageViewed *request = [OSRequestInAppMessageViewed
                                withAppId:testAppId
                                withPlayerId:nil
                                withMessageId:testMessageId
                                forVariantId:nil];

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
       @"device_type": @0,
       @"app_id": testAppId
    }));
}

- (void)testInAppMessagePageViewed {
    OSRequestInAppMessagePageViewed *request = [OSRequestInAppMessagePageViewed
                    withAppId:testAppId
                    withPlayerId:testSubscriptionId
                    withMessageId:testMessageId
                    withPageId:testPageId
                    forVariantId:testVariantId];
    NSString *correctUrl = correctUrlWithPath([NSString stringWithFormat:@"in_app_messages/%@/pageImpression", testMessageId]);

    XCTAssertEqualObjects(correctUrl, request.urlRequest.URL.absoluteString);
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
       @"device_type": @0,
       @"player_id": testSubscriptionId,
       @"app_id": testAppId,
       @"variant_id": testVariantId,
       @"page_id": testPageId
    }));
}

- (void)testInAppMessagePageViewed_withNilArguments {
    OSRequestInAppMessagePageViewed *request = [OSRequestInAppMessagePageViewed
                    withAppId:testAppId
                    withPlayerId:nil
                    withMessageId:testMessageId
                    withPageId:nil
                    forVariantId:nil];

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
       @"device_type": @0,
       @"app_id": testAppId,
    }));
}

- (void)testInAppMessageClicked {
    OSRequestInAppMessageClicked *request = [OSRequestInAppMessageClicked
                   withAppId:testAppId
                   withPlayerId:testSubscriptionId
                   withMessageId:testMessageId
                   forVariantId:testVariantId
                   withAction:testClickResult];
    NSString *correctUrl = correctUrlWithPath([NSString stringWithFormat:@"in_app_messages/%@/click", testMessageId]);

    XCTAssertEqualObjects(correctUrl, request.urlRequest.URL.absoluteString);
    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
       @"app_id": testAppId,
       @"device_type": @0,
       @"player_id": testSubscriptionId,
       @"click_id": testClickResult.clickId ?: @"",
       @"variant_id": testVariantId,
       @"first_click": @(testClickResult.firstClick)
   }));
}

- (void)testInAppMessageClicked_withNilArguments {
    OSRequestInAppMessageClicked *request = [OSRequestInAppMessageClicked
                   withAppId:testAppId
                   withPlayerId:nil
                   withMessageId:testMessageId
                   forVariantId:nil
                   withAction:testClickResult];

    XCTAssertTrue(checkHttpBody(request.urlRequest.HTTPBody, @{
       @"app_id": testAppId,
       @"device_type": @0,
       @"click_id": testClickResult.clickId ?: @"",
       @"first_click": @(testClickResult.firstClick)
   }));
}

@end
