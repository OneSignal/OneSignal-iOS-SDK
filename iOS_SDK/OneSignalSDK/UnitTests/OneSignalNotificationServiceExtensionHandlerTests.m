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
#import <UserNotifications/UserNotifications.h>
#import <OneSignalCore/OneSignalCore.h>
#import <OneSignalExtension/OneSignalExtension.h>

@interface OSReceiveReceiptRecordingClient : NSObject <IOneSignalClient>
- (NSUInteger)receiveReceiptCountForNotificationId:(NSString *)notificationId;
@end

@implementation OSReceiveReceiptRecordingClient {
    NSMutableArray<NSString *> *_requestPaths;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestPaths = [NSMutableArray new];
    }
    return self;
}

- (void)executeRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSClientFailureBlock)failureBlock {
    @synchronized (self) {
        [_requestPaths addObject:request.path];
    }
    successBlock(@{});
}

- (NSUInteger)receiveReceiptCountForNotificationId:(NSString *)notificationId {
    NSString *receiptPath = [NSString stringWithFormat:@"notifications/%@/report_received", notificationId];
    @synchronized (self) {
        return [_requestPaths indexesOfObjectsPassingTest:^BOOL(NSString *path, NSUInteger idx, BOOL *stop) {
            return [path isEqualToString:receiptPath];
        }].count;
    }
}

@end

@interface OneSignalNotificationServiceExtensionHandlerTests : XCTestCase
@end

@implementation OneSignalNotificationServiceExtensionHandlerTests {
    id<IOneSignalClient> _originalClient;
    OSReceiveReceiptRecordingClient *_client;
    NSDictionary<NSString *, id> *_originalSharedValues;
}

+ (NSArray<NSString *> *)sharedKeysUnderTest {
    return @[OSUD_APP_ID,
             OSUD_PUSH_SUBSCRIPTION_ID,
             OSUD_RECEIVE_RECEIPTS_ENABLED,
             OSUD_NSE_PROCESSED_NOTIFICATION_IDS,
             OSUD_CACHED_RECEIVED_NOTIFICATION_IDS];
}

- (void)setUp {
    [super setUp];

    OneSignalUserDefaults *sharedUserDefaults = OneSignalUserDefaults.initShared;
    NSMutableDictionary<NSString *, id> *originalValues = [NSMutableDictionary new];
    for (NSString *key in OneSignalNotificationServiceExtensionHandlerTests.sharedKeysUnderTest) {
        originalValues[key] = [sharedUserDefaults getSavedObjectForKey:key defaultValue:nil];
        [sharedUserDefaults removeValueForKey:key];
    }
    _originalSharedValues = originalValues;

    [sharedUserDefaults saveStringForKey:OSUD_APP_ID withValue:@"test-app-id"];
    [sharedUserDefaults saveStringForKey:OSUD_PUSH_SUBSCRIPTION_ID withValue:@"test-subscription-id"];
    [sharedUserDefaults saveBoolForKey:OSUD_RECEIVE_RECEIPTS_ENABLED withValue:YES];

    _originalClient = OneSignalCoreImpl.sharedClient;
    _client = [OSReceiveReceiptRecordingClient new];
    [OneSignalCoreImpl setSharedClient:_client];
}

- (void)tearDown {
    [OneSignalCoreImpl setSharedClient:_originalClient];

    OneSignalUserDefaults *sharedUserDefaults = OneSignalUserDefaults.initShared;
    for (NSString *key in OneSignalNotificationServiceExtensionHandlerTests.sharedKeysUnderTest) {
        id originalValue = _originalSharedValues[key];
        if (originalValue) {
            [sharedUserDefaults saveObjectForKey:key withValue:originalValue];
        } else {
            [sharedUserDefaults removeValueForKey:key];
        }
    }

    [super tearDown];
}

- (UNNotificationRequest *)requestForNotificationId:(NSString *)notificationId {
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.body = @"body";
    content.userInfo = @{
        @"aps": @{@"alert": @"body", @"mutable-content": @1},
        @"custom": @{@"i": notificationId}
    };
    return [UNNotificationRequest requestWithIdentifier:NSUUID.UUID.UUIDString content:content trigger:nil];
}

/*
 Runs off the main thread because the extension run waits for its confirmed delivery, which the SDK sends on the main queue.
 The timeout is shorter than MAX_NSE_LIFETIME_SECOUNDS, so a run that never signals its semaphore fails the test.
 */
- (void)receiveNotificationWithId:(NSString *)notificationId {
    UNNotificationRequest *request = [self requestForNotificationId:notificationId];
    XCTestExpectation *contentHandled = [self expectationWithDescription:@"content handler called"];
    XCTestExpectation *runReturned = [self expectationWithDescription:@"extension run returned"];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [OneSignalNotificationServiceExtensionHandler didReceiveNotificationExtensionRequest:request
                                                             withMutableNotificationContent:nil
                                                                         withContentHandler:^(UNNotificationContent *content) {
            [contentHandled fulfill];
        }];
        [runReturned fulfill];
    });
    [self waitForExpectations:@[contentHandled, runReturned] timeout:5];
}

- (void)testSendsOneReceiveReceiptWhenTheExtensionRunsTwiceForOneNotification {
    NSString *notificationId = NSUUID.UUID.UUIDString;

    [self receiveNotificationWithId:notificationId];
    [self receiveNotificationWithId:notificationId];

    XCTAssertEqual([_client receiveReceiptCountForNotificationId:notificationId], 1);
}

- (void)testSendsReceiveReceiptForEachNotification {
    NSString *firstNotificationId = NSUUID.UUID.UUIDString;
    NSString *secondNotificationId = NSUUID.UUID.UUIDString;

    [self receiveNotificationWithId:firstNotificationId];
    [self receiveNotificationWithId:secondNotificationId];

    XCTAssertEqual([_client receiveReceiptCountForNotificationId:firstNotificationId], 1);
    XCTAssertEqual([_client receiveReceiptCountForNotificationId:secondNotificationId], 1);
}

- (void)testSendsOneReceiveReceiptWhenTheExtensionRunsConcurrentlyForOneNotification {
    // Run once first so the first-run migrations do not run concurrently.
    [self receiveNotificationWithId:NSUUID.UUID.UUIDString];

    NSString *notificationId = NSUUID.UUID.UUIDString;
    UNNotificationRequest *request = [self requestForNotificationId:notificationId];
    int runCount = 10;
    XCTestExpectation *runsReturned = [self expectationWithDescription:@"extension runs returned"];
    runsReturned.expectedFulfillmentCount = runCount;

    for (int i = 0; i < runCount; i++) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [OneSignalNotificationServiceExtensionHandler didReceiveNotificationExtensionRequest:request
                                                                 withMutableNotificationContent:nil
                                                                             withContentHandler:^(UNNotificationContent *content) {}];
            [runsReturned fulfill];
        });
    }
    [self waitForExpectations:@[runsReturned] timeout:5];

    XCTAssertEqual([_client receiveReceiptCountForNotificationId:notificationId], 1);
}

- (void)testSkipsReceiveReceiptForNotificationProcessedByAnEarlierExtensionProcess {
    NSString *notificationId = NSUUID.UUID.UUIDString;
    [OneSignalUserDefaults.initShared saveObjectForKey:OSUD_NSE_PROCESSED_NOTIFICATION_IDS withValue:@[notificationId]];

    [self receiveNotificationWithId:notificationId];

    XCTAssertEqual([_client receiveReceiptCountForNotificationId:notificationId], 0);
}

- (void)testSkipsReceiveReceiptWhenSharedUserDefaultsLosesAnIdThisProcessHandled {
    NSString *notificationId = NSUUID.UUID.UUIDString;
    [self receiveNotificationWithId:notificationId];
    [OneSignalUserDefaults.initShared removeValueForKey:OSUD_NSE_PROCESSED_NOTIFICATION_IDS];

    [self receiveNotificationWithId:notificationId];

    XCTAssertEqual([_client receiveReceiptCountForNotificationId:notificationId], 1);
}

- (void)testKeepsOnlyTheMostRecentProcessedNotificationIds {
    NSMutableArray<NSString *> *notificationIds = [NSMutableArray new];
    for (int i = 0; i <= MAX_NSE_PROCESSED_NOTIFICATION_IDS; i++) {
        NSString *notificationId = NSUUID.UUID.UUIDString;
        [notificationIds addObject:notificationId];
        [self receiveNotificationWithId:notificationId];
    }

    NSArray<NSString *> *savedIds = [OneSignalUserDefaults.initShared getSavedObjectForKey:OSUD_NSE_PROCESSED_NOTIFICATION_IDS defaultValue:nil];
    NSArray<NSString *> *expectedIds = [notificationIds subarrayWithRange:NSMakeRange(1, MAX_NSE_PROCESSED_NOTIFICATION_IDS)];
    XCTAssertEqualObjects(savedIds, expectedIds);

    NSString *evictedNotificationId = notificationIds.firstObject;
    [self receiveNotificationWithId:evictedNotificationId];
    XCTAssertEqual([_client receiveReceiptCountForNotificationId:evictedNotificationId], 2);
}

@end
