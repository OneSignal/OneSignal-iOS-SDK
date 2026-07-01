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

import XCTest
import OneSignalCore
import OneSignalOSCore
import OneSignalUser
import OneSignalCoreMocks
import OneSignalUserMocks

@testable import OneSignalLiveActivities

final class OSLiveActivitiesExecutorTests: XCTestCase {

    override func setUpWithError() throws {
        // TODO: Something like the existing [UnitTestCommonMethods beforeEachTest:self];
        // TODO: Need to clear all data between tests for user manager, models, etc.
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        // App ID is set because User Manager has guards against nil App ID
        OneSignalIdentifiers.currentAppId = "test-app-id"
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }

    // Subscribes a user, then resets the client so tests assert only on the requests they make.
    private func setUpSubscribedUser() -> MockOneSignalClient {
        let mockClient = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(mockClient)
        OneSignalUserDefaults.initShared().saveString(forKey: OSUD_LEGACY_PLAYER_ID, withValue: "my-subscription-id")
        OneSignalUserManagerImpl.sharedInstance.start()
        // Wait for any user setup requests to complete
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.2)
        mockClient.reset()
        return mockClient
    }

    func testAppendSetStartTokenWithSuccessfulRequest() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request = OSRequestSetStartToken(key: "my-activity-type", token: "my-token")
        mockClient.setMockResponseForRequest(request: String(describing: request), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(2)

        /* Then */
        XCTAssertEqual(executor.startTokens.items.count, 1)
        XCTAssert(executor.startTokens.items["my-activity-type"] == request)
        XCTAssertTrue(request.requestSuccessful)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request)
    }

    func testRemoveStartTokenWithSuccessfulRequest() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request = OSRequestRemoveStartToken(key: "my-activity-type")
        mockClient.setMockResponseForRequest(request: String(describing: request), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(2)

        /* Then */
        XCTAssertEqual(executor.startTokens.items.count, 0)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request)
    }

    func testSetUpdateTokenWithSuccessfulRequest() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request = OSRequestSetUpdateToken(key: "my-activity-id", token: "my-token")
        mockClient.setMockResponseForRequest(request: String(describing: request), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(2)

        /* Then */
        XCTAssertEqual(executor.updateTokens.items.count, 1)
        XCTAssert(executor.updateTokens.items["my-activity-id"] == request)
        XCTAssertTrue(request.requestSuccessful)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request)
    }

    func testRemoveUpdateTokenWithSuccessfulRequest() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request = OSRequestRemoveUpdateToken(key: "my-activity-id")
        mockClient.setMockResponseForRequest(request: String(describing: request), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(2)

        /* Then */
        XCTAssertEqual(executor.updateTokens.items.count, 0)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request)
    }

    func testReceiveReceiptsWithSuccessfulRequest() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request = OSRequestLiveActivityReceiveReceipts(key: "notification-id", activityType: "my-activity-type", activityId: "my-activity-id")
        mockClient.setMockResponseForRequest(request: String(describing: request), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(2)

        /* Then */
        // The sent receipt is kept as a dedup marker so the same notificationId isn't reported again.
        XCTAssertEqual(executor.receiveReceipts.items.count, 1)
        XCTAssertTrue(executor.receiveReceipts.items["notification-id"]?.requestSuccessful ?? false)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request)
    }

    func testClickEventWithSuccessfulRequest() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request = OSRequestLiveActivityClicked(key: "unique-click-id", activityType: "my-activity-type", activityId: "my-activity-id", notificationId: "my-notif-id")
        mockClient.setMockResponseForRequest(request: String(describing: request), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(2)

        /* Then */
        XCTAssertEqual(executor.clickEvents.items.count, 0)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request)
    }

    func testRequestWillNotExecuteWhenNoSubscription() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(mockClient)
        let request = OSRequestSetStartToken(key: "my-activity-type", token: "my-token")

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(1)

        /* Then */
        XCTAssertEqual(executor.startTokens.items.count, 1)
        XCTAssert(executor.startTokens.items["my-activity-type"] == request)
        XCTAssertFalse(request.requestSuccessful)
        XCTAssertEqual(mockClient.executedRequests.count, 0)
    }

    func testRequestStaysInCacheForRetryableError() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request = OSRequestSetStartToken(key: "my-activity-type", token: "my-token")
        mockClient.setMockFailureResponseForRequest(request: String(describing: request), error: OneSignalClientError(code: 500, message: "not-important", responseHeaders: nil, response: nil, underlyingError: nil))

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(1)

        /* Then */
        XCTAssertEqual(executor.startTokens.items.count, 1)
        XCTAssert(executor.startTokens.items["my-activity-type"] == request)
        XCTAssertFalse(request.requestSuccessful)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request)
    }

    func testRequestRemovedFromCacheForNonRetryableError() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request = OSRequestSetStartToken(key: "my-activity-type", token: "my-token")
        mockClient.setMockFailureResponseForRequest(request: String(describing: request), error: OneSignalClientError(code: 401, message: "not-important", responseHeaders: nil, response: nil, underlyingError: nil))

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request)
        mockDispatchQueue.waitForDispatches(2)

        /* Then */
        XCTAssertEqual(executor.startTokens.items.count, 0)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request)
    }

    func testRequestsUncacheCorrectly() throws {
        /* Setup */
        let mockClient = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(mockClient)
        let mockDispatchQueue = MockDispatchQueue()
        let executor1 = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)

        /* When */
        let setStartToken = OSRequestSetStartToken(key: "key-setStartToken", token: "my-token")
        let removeStartToken = OSRequestRemoveStartToken(key: "key-removeStartToken")
        let setUpdateToken = OSRequestSetUpdateToken(key: "key-setUpdateToken", token: "my-token")
        let removeUpdateToken = OSRequestRemoveUpdateToken(key: "key-removeUpdateToken")
        let receiveReceipt = OSRequestLiveActivityReceiveReceipts(key: "key-receiveReceipt", activityType: "my-activity-type", activityId: "my-activity-id")
        let clickEvent = OSRequestLiveActivityClicked(key: "key-clickEvent", activityType: "my-activity-type", activityId: "my-activity-id", notificationId: "notification-id")

        executor1.append(setStartToken)
        executor1.append(removeStartToken)
        executor1.append(setUpdateToken)
        executor1.append(removeUpdateToken)
        executor1.append(receiveReceipt)
        executor1.append(clickEvent)
        mockDispatchQueue.waitForDispatches(6)

        // create a new executor which will uncache requests
        let executor2 = OSLiveActivitiesExecutor(requestDispatch: MockDispatchQueue())

        /* Then */
        XCTAssertEqual(executor2.startTokens.items.count, 2)
        XCTAssertTrue(executor2.startTokens.items["key-setStartToken"] is OSRequestSetStartToken)
        XCTAssertTrue(executor2.startTokens.items["key-removeStartToken"] is OSRequestRemoveStartToken)

        XCTAssertEqual(executor2.updateTokens.items.count, 2)
        XCTAssertTrue(executor2.updateTokens.items["key-setUpdateToken"] is OSRequestSetUpdateToken)
        XCTAssertTrue(executor2.updateTokens.items["key-removeUpdateToken"] is OSRequestRemoveUpdateToken)

        XCTAssertEqual(executor2.receiveReceipts.items.count, 1)
        XCTAssertTrue(executor2.receiveReceipts.items["key-receiveReceipt"] is OSRequestLiveActivityReceiveReceipts)

        XCTAssertEqual(executor2.clickEvents.items.count, 1)
        XCTAssertTrue(executor2.clickEvents.items["key-clickEvent"] is OSRequestLiveActivityClicked)
    }

    func testSetStartRequestNotExecutedWithSameActivityTypeAndToken() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestSetStartToken(key: "my-activity-type", token: "my-token")
        let request2 = OSRequestSetStartToken(key: "my-activity-type", token: "my-token")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request1)
        executor.append(request2)
        mockDispatchQueue.waitForDispatches(3)

        /* Then */
        XCTAssertEqual(executor.startTokens.items.count, 1)
        XCTAssert(executor.startTokens.items["my-activity-type"] == request1)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request1)
    }

    func testSetStartRequestNotExecutedWithSameActivityTypeAndDiffToken() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestSetStartToken(key: "my-activity-type", token: "my-token-1")
        let request2 = OSRequestSetStartToken(key: "my-activity-type", token: "my-token-2")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request1)
        executor.append(request2)
        mockDispatchQueue.waitForDispatches(3)

        /* Then */
        XCTAssertEqual(executor.startTokens.items.count, 1)
        XCTAssert(executor.startTokens.items["my-activity-type"] == request2)
        XCTAssertEqual(mockClient.executedRequests.count, 2)
        XCTAssertTrue(mockClient.executedRequests[0] == request1)
        XCTAssertTrue(mockClient.executedRequests[1] == request2)
    }

    func testSetStartRequestFollowedByRemoveStartIsSuccessful() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestSetStartToken(key: "my-activity-type", token: "my-token-1")
        let request2 = OSRequestRemoveStartToken(key: "my-activity-type")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request1)
        executor.append(request2)
        mockDispatchQueue.waitForDispatches(4)

        /* Then */
        XCTAssertEqual(executor.startTokens.items.count, 0)
        XCTAssertEqual(mockClient.executedRequests.count, 2)
        XCTAssertTrue(mockClient.executedRequests[0] == request1)
        XCTAssertTrue(mockClient.executedRequests[1] == request2)
    }

    func testSetUpdateRequestNotExecutedWithSameActivityIdAndToken() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestSetUpdateToken(key: "my-activity-id", token: "my-token")
        let request2 = OSRequestSetUpdateToken(key: "my-activity-id", token: "my-token")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request1)
        executor.append(request2)
        mockDispatchQueue.waitForDispatches(3)

        /* Then */
        XCTAssertEqual(executor.updateTokens.items.count, 1)
        XCTAssert(executor.updateTokens.items["my-activity-id"] == request1)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request1)
    }

    func testSetUpdateRequestNotExecutedWithSameActivityIdAndDiffToken() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestSetUpdateToken(key: "my-activity-id", token: "my-token-1")
        let request2 = OSRequestSetUpdateToken(key: "my-activity-id", token: "my-token-2")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request1)
        executor.append(request2)
        mockDispatchQueue.waitForDispatches(3)

        /* Then */
        XCTAssertEqual(executor.updateTokens.items.count, 1)
        XCTAssert(executor.updateTokens.items["my-activity-id"] == request2)
        XCTAssertEqual(mockClient.executedRequests.count, 2)
        XCTAssertTrue(mockClient.executedRequests[0] == request1)
        XCTAssertTrue(mockClient.executedRequests[1] == request2)
    }

    func testSetUpdateRequestFollowedByRemoveUpdateIsSuccessful() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestSetUpdateToken(key: "my-activity-id", token: "my-token-1")
        let request2 = OSRequestRemoveUpdateToken(key: "my-activity-id")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request1)
        executor.append(request2)
        mockDispatchQueue.waitForDispatches(4)

        /* Then */
        XCTAssertEqual(executor.updateTokens.items.count, 0)
        XCTAssertEqual(mockClient.executedRequests.count, 2)
        XCTAssertTrue(mockClient.executedRequests[0] == request1)
        XCTAssertTrue(mockClient.executedRequests[1] == request2)
    }

    func testReceiveReceiptsRequestNotExecutedWithSameNotificationId() throws {
        /* Setup */
        let mockDispatchQueue = MockDispatchQueue()
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestLiveActivityReceiveReceipts(key: "my-notification-id", activityType: "my-activity-type-1", activityId: "my-activity-id-1")
        let request2 = OSRequestLiveActivityReceiveReceipts(key: "my-notification-id", activityType: "my-activity-type-2", activityId: "my-activity-id-2")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        /* When */
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request1)
        executor.append(request2)
        mockDispatchQueue.waitForDispatches(3)

        /* Then */
        // request2 is suppressed as a duplicate of request1, which is kept as a dedup marker.
        XCTAssertEqual(executor.receiveReceipts.items.count, 1)
        XCTAssertEqual(mockClient.executedRequests.count, 1)
        XCTAssertTrue(mockClient.executedRequests[0] == request1)
    }

    /**
     A receive receipt must be sent at most once per device, even across app launches. The second executor
     reloads the persisted cache with in-memory state gone, simulating a relaunch where ActivityKit re-emits
     the active activity's current content and the same notificationId is reported again.
     */
    func testReceiveReceiptsNotResentForSameNotificationIdAfterRelaunch() throws {
        /* Setup */
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestLiveActivityReceiveReceipts(key: "my-notification-id", activityType: "my-activity-type", activityId: "my-activity-id")
        let request2 = OSRequestLiveActivityReceiveReceipts(key: "my-notification-id", activityType: "my-activity-type", activityId: "my-activity-id")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        /* When */
        // First launch: the receipt is sent and succeeds.
        let firstLaunch = MockDispatchQueue()
        let executor1 = OSLiveActivitiesExecutor(requestDispatch: firstLaunch)
        executor1.append(request1)
        firstLaunch.waitForDispatches(2)
        XCTAssertEqual(mockClient.executedRequests.count, 1)

        // Relaunch: a fresh executor reloads the persisted cache; ActivityKit re-emits the same content.
        let secondLaunch = MockDispatchQueue()
        let executor2 = OSLiveActivitiesExecutor(requestDispatch: secondLaunch)
        executor2.append(request2)
        secondLaunch.waitForDispatches(1)

        /* Then */
        XCTAssertEqual(mockClient.executedRequests.count, 1, "Receive receipt must not be re-sent for the same notificationId after relaunch")
        XCTAssertTrue(mockClient.executedRequests[0] == request1)
    }
}

// Receive-receipt dedup robustness: retry poll, TTL expiry, and non-retryable failure.
extension OSLiveActivitiesExecutorTests {
    /**
     After relaunch the persisted success marker is reloaded; the retry poll only re-executes unsent
     requests, so an already-confirmed notificationId must not be sent again.
     */
    func testPollDoesNotResendReloadedSuccessfulReceipt() throws {
        /* Setup */
        let mockClient = setUpSubscribedUser()

        let request = OSRequestLiveActivityReceiveReceipts(key: "my-notification-id", activityType: "my-activity-type", activityId: "my-activity-id")
        mockClient.setMockResponseForRequest(request: String(describing: request), response: [String: Any]())

        // First launch: send the receipt so a success marker is persisted.
        let firstLaunch = MockDispatchQueue()
        let executor1 = OSLiveActivitiesExecutor(requestDispatch: firstLaunch)
        executor1.append(request)
        firstLaunch.waitForDispatches(2)
        XCTAssertEqual(mockClient.executedRequests.count, 1)

        /* When */
        // Relaunch and drive the retry poll directly against the reloaded marker.
        let secondLaunch = MockDispatchQueue()
        let executor2 = OSLiveActivitiesExecutor(requestDispatch: secondLaunch, pollIntervalSeconds: 0)
        XCTAssertTrue(executor2.receiveReceipts.items["my-notification-id"]?.requestSuccessful ?? false, "Success marker must survive reload")
        executor2.pollPendingRequests()
        secondLaunch.waitForDispatches(1)

        /* Then */
        XCTAssertEqual(mockClient.executedRequests.count, 1, "Poll must skip a receipt already marked successful")
    }

    /**
     A success marker only suppresses re-sends until its TTL elapses. Once expired and pruned, the same
     notificationId can be confirmed again on a later relaunch.
     */
    func testReceiveReceiptResentAfterMarkerExpires() throws {
        /* Setup */
        let mockClient = setUpSubscribedUser()

        let expiredNotif = "expired-notification-id"
        let request1 = OSRequestLiveActivityReceiveReceipts(key: expiredNotif, activityType: "my-activity-type", activityId: "my-activity-id")
        let request2 = OSRequestLiveActivityReceiveReceipts(key: expiredNotif, activityType: "my-activity-type", activityId: "my-activity-id")
        mockClient.setMockResponseForRequest(request: String(describing: request1), response: [String: Any]())
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())

        // First launch: send the receipt, then age its persisted marker past the TTL.
        let firstLaunch = MockDispatchQueue()
        let executor1 = OSLiveActivitiesExecutor(requestDispatch: firstLaunch)
        executor1.append(request1)
        firstLaunch.waitForDispatches(2)
        executor1.receiveReceipts.items[expiredNotif]?.timestamp = Date(timeIntervalSinceNow: -(ReceiveReceiptsRequestCache.OneDayInSeconds + 60))

        // Any later save prunes the expired marker; append an unrelated receipt to trigger one.
        let other = OSRequestLiveActivityReceiveReceipts(key: "other-notification-id", activityType: "my-activity-type", activityId: "my-activity-id")
        mockClient.setMockResponseForRequest(request: String(describing: other), response: [String: Any]())
        executor1.append(other)
        firstLaunch.waitForDispatches(4)
        XCTAssertNil(executor1.receiveReceipts.items[expiredNotif], "Expired marker should be pruned on the next save")

        /* When */
        // Relaunch: the expired notificationId is re-emitted and must be sent again.
        let secondLaunch = MockDispatchQueue()
        let executor2 = OSLiveActivitiesExecutor(requestDispatch: secondLaunch)
        executor2.append(request2)
        secondLaunch.waitForDispatches(2)

        /* Then */
        XCTAssertTrue(mockClient.executedRequests.contains { $0 == request2 }, "Receipt should be re-sent after its marker expires")
    }

    /**
     A non-retryable failure removes the receipt from the cache, leaving no marker, so a later re-emit of
     the same notificationId is sent again rather than suppressed.
     */
    func testReceiveReceiptResentAfterNonRetryableFailure() throws {
        /* Setup */
        let mockClient = setUpSubscribedUser()

        let request1 = OSRequestLiveActivityReceiveReceipts(key: "my-notification-id", activityType: "my-activity-type", activityId: "my-activity-id")
        mockClient.setMockFailureResponseForRequest(request: String(describing: request1), error: OneSignalClientError(code: 401, message: "not-important", responseHeaders: nil, response: nil, underlyingError: nil))

        /* When */
        let mockDispatchQueue = MockDispatchQueue()
        let executor = OSLiveActivitiesExecutor(requestDispatch: mockDispatchQueue)
        executor.append(request1)
        mockDispatchQueue.waitForDispatches(2)
        XCTAssertEqual(executor.receiveReceipts.items.count, 0, "A non-retryable failure should leave no dedup marker")

        // Re-emit the same notificationId; this time it succeeds and must be sent again.
        let request2 = OSRequestLiveActivityReceiveReceipts(key: "my-notification-id", activityType: "my-activity-type", activityId: "my-activity-id")
        mockClient.setMockResponseForRequest(request: String(describing: request2), response: [String: Any]())
        executor.append(request2)
        mockDispatchQueue.waitForDispatches(4)

        /* Then */
        XCTAssertEqual(mockClient.executedRequests.count, 2, "Receipt should be re-sent after a non-retryable failure")
        XCTAssertTrue(executor.receiveReceipts.items["my-notification-id"]?.requestSuccessful ?? false)
    }
}
