/*
 Modified MIT License

 Copyright 2026 OneSignal

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
#import <OneSignalCore/OneSignalCore.h>
#import <OneSignalExtension/OneSignalExtension.h>

@interface OSReceiveReceiptsRecordingClient : NSObject <IOneSignalClient>
@property (strong, nonatomic, nullable) OneSignalRequest *lastRequest;
@property (strong, nonatomic, nullable) XCTestExpectation *executed;
@end

@implementation OSReceiveReceiptsRecordingClient
- (void)executeRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSClientFailureBlock)failureBlock {
    self.lastRequest = request;
    if (successBlock) {
        successBlock(@{});
    }
    [self.executed fulfill];
}
@end

/// The confirmed receipt the NSE sends, built from the identifiers it reads out of shared UserDefaults.
@interface ReceiveReceiptsRequestTests : XCTestCase
@end

@implementation ReceiveReceiptsRequestTests {
    OSReceiveReceiptsRecordingClient *client;
    id<IOneSignalClient> previousClient;
}

- (void)setUp {
    [super setUp];
    previousClient = OneSignalCoreImpl.sharedClient;
    client = [OSReceiveReceiptsRecordingClient new];
    [OneSignalCoreImpl setSharedClient:client];
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_RECEIVE_RECEIPTS_ENABLED withValue:YES];
    [OneSignalUserDefaults.initShared removeValueForKey:OS_SNAPSHOT_ONESIGNAL_ID];
}

- (void)tearDown {
    [OneSignalUserDefaults.initShared removeValueForKey:OSUD_RECEIVE_RECEIPTS_ENABLED];
    [OneSignalUserDefaults.initShared removeValueForKey:OS_SNAPSHOT_ONESIGNAL_ID];
    [OneSignalCoreImpl setSharedClient:previousClient];
    [super tearDown];
}

- (NSDictionary *)sendReceiptAndReadParameters {
    client.executed = [self expectationWithDescription:@"receipt handed to the client"];
    [[OneSignalReceiveReceiptsController new] sendReceiveReceiptWithPlayerId:@"test-subscription-id"
                                                              notificationId:@"test-notification-id"
                                                                       appId:@"test-app-id"
                                                                       delay:0
                                                                successBlock:nil
                                                                failureBlock:nil];
    [self waitForExpectations:@[client.executed] timeout:5];
    return client.lastRequest.parameters;
}

- (void)testReceiveReceiptCarriesOnesignalIdFromSharedDefaults {
    [OneSignalUserDefaults.initShared saveStringForKey:OS_SNAPSHOT_ONESIGNAL_ID withValue:@"test-onesignal-id"];

    NSDictionary *parameters = [self sendReceiptAndReadParameters];

    XCTAssertEqualObjects(client.lastRequest.path, @"notifications/test-notification-id/report_received");
    XCTAssertEqualObjects(parameters[@"onesignal_id"], @"test-onesignal-id");
    XCTAssertEqualObjects(parameters[@"player_id"], @"test-subscription-id");
    XCTAssertEqualObjects(parameters[@"app_id"], @"test-app-id");
    XCTAssertEqualObjects(parameters[@"device_type"], @0);
}

- (void)testReceiveReceiptOmitsOnesignalIdWhenSharedDefaultsHasNone {
    NSDictionary *parameters = [self sendReceiptAndReadParameters];

    XCTAssertNil(parameters[@"onesignal_id"]);
    XCTAssertEqualObjects(parameters[@"player_id"], @"test-subscription-id");
    XCTAssertEqualObjects(parameters[@"app_id"], @"test-app-id");
}

- (void)testReceiveReceiptOmitsOnesignalIdWhenSharedDefaultsHasEmptyString {
    [OneSignalUserDefaults.initShared saveStringForKey:OS_SNAPSHOT_ONESIGNAL_ID withValue:@""];

    NSDictionary *parameters = [self sendReceiptAndReadParameters];

    XCTAssertNil(parameters[@"onesignal_id"]);
}

@end
