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

import XCTest
import OneSignalCore
import OneSignalCoreMocks
import OneSignalUserMocks
@testable import OneSignalOSCore
@testable import OneSignalUser

/**
 Regression coverage for stale UpdateSubscription races after permission grant.
 */
final class SubscriptionUpdateRaceTests: XCTestCase {

    private let subscriptionId = "test-subscription-id"
    private let pushToken = "test-push-token"
    /// Typical iOS alert+badge+sound permission bitmask after Accept.
    private let subscribedNotificationTypes = 31
    private let promptedNeverAnswered = Int(ERROR_PUSH_PROMPT_NEVER_ANSWERED)

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }

    /**
     Parameters are built from the live model at init and refreshed again in prepareForExecution before send
     */
    func testPrepareForExecutionRefreshesEnabledAndNotificationTypesFromLiveModel() throws {
        let model = makePushSubscriptionModel(notificationTypes: promptedNeverAnswered, subscriptionId: subscriptionId)
        XCTAssertFalse(model.enabled)

        let request = OSRequestUpdateSubscription(subscriptionModel: model)
        let atInit = try XCTUnwrap(request.parameters?["subscription"] as? [String: Any])
        XCTAssertEqual(atInit["notification_types"] as? Int, promptedNeverAnswered)
        XCTAssertEqual(atInit["enabled"] as? Bool, false)

        // Permission granted — live model is now subscribed.
        model.notificationTypes = subscribedNotificationTypes
        XCTAssertTrue(model.enabled)

        XCTAssertTrue(request.prepareForExecution(newRecordsState: OSNewRecordsState()))

        let refreshed = try XCTUnwrap(request.parameters?["subscription"] as? [String: Any])
        XCTAssertEqual(refreshed["notification_types"] as? Int, subscribedNotificationTypes)
        XCTAssertEqual(refreshed["enabled"] as? Bool, true)
    }

    /**
     Regression: a pre-permission UpdateSubscription left pending must not send `-19`
     after permission is granted. Coalesce + live refresh should yield only subscribed payload(s).
     */
    func testPendingPrePermissionUpdateSendsLiveSubscribedPayloadAfterGrant() throws {
        let client = MockOneSignalClient()
        client.executeInstantaneously = false
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)

        let executor = OSSubscriptionOperationExecutor(newRecordsState: OSNewRecordsState())
        // Without a subscriptionId, prepareForExecution keeps the update pending.
        let model = makePushSubscriptionModel(notificationTypes: promptedNeverAnswered, subscriptionId: nil)
        let identityModelId = UUID().uuidString

        executor.enqueueDelta(OSDelta(
            name: OS_UPDATE_SUBSCRIPTION_DELTA,
            identityModelId: identityModelId,
            model: model,
            property: "notificationTypes",
            value: promptedNeverAnswered
        ))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.2)

        XCTAssertTrue(client.executedRequests.isEmpty, "Update should still be pending without subscriptionId")

        // User accepts — live model subscribed — then hydrate subscription id and flush again.
        model.notificationTypes = subscribedNotificationTypes
        model.subscriptionId = subscriptionId
        XCTAssertTrue(model.enabled)

        executor.enqueueDelta(OSDelta(
            name: OS_UPDATE_SUBSCRIPTION_DELTA,
            identityModelId: identityModelId,
            model: model,
            property: "notificationTypes",
            value: subscribedNotificationTypes
        ))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        let updateRequests = client.executedRequests.compactMap { $0 as? OSRequestUpdateSubscription }
        XCTAssertFalse(updateRequests.isEmpty, "Expected at least one UpdateSubscription after id hydration")

        let payloads = updateRequests.compactMap { $0.parameters?["subscription"] as? [String: Any] }
        let sentMinus19 = payloads.contains {
            ($0["notification_types"] as? Int) == promptedNeverAnswered && ($0["enabled"] as? Bool) == false
        }
        let allSubscribed = payloads.allSatisfy {
            ($0["notification_types"] as? Int) == subscribedNotificationTypes && ($0["enabled"] as? Bool) == true
        }

        XCTAssertFalse(sentMinus19, "Must not send stale enabled:false / notification_types:-19 after grant")
        XCTAssertTrue(allSubscribed, "All executed UpdateSubscription payloads should reflect the live subscribed model")
        XCTAssertEqual(updateRequests.count, 1, "Unsent updates for the same subscription should be coalesced")
    }

    /**
     An UpdateSubscription already on the wire must not race a follow-up PATCH.
     The follow-up stays queued until the in-flight request completes, then sends live state.
     */
    func testInFlightUpdateBlocksFollowUpUntilCompleteThenSendsLiveState() throws {
        let client = MockOneSignalClient()
        client.holdResponses = true
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)

        let executor = OSSubscriptionOperationExecutor(newRecordsState: OSNewRecordsState())
        let model = makePushSubscriptionModel(notificationTypes: promptedNeverAnswered, subscriptionId: subscriptionId)
        let identityModelId = UUID().uuidString

        executor.enqueueDelta(OSDelta(
            name: OS_UPDATE_SUBSCRIPTION_DELTA,
            identityModelId: identityModelId,
            model: model,
            property: "notificationTypes",
            value: promptedNeverAnswered
        ))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.2)

        XCTAssertEqual(client.startedRequests.count, 1, "First UpdateSubscription should be in flight")
        let firstPayload = try XCTUnwrap(
            (client.startedRequests[0] as? OSRequestUpdateSubscription)?.parameters?["subscription"] as? [String: Any]
        )
        XCTAssertEqual(firstPayload["notification_types"] as? Int, promptedNeverAnswered)
        XCTAssertEqual(firstPayload["enabled"] as? Bool, false)

        // Permission granted while first PATCH is still in flight.
        model.notificationTypes = subscribedNotificationTypes
        XCTAssertTrue(model.enabled)

        executor.enqueueDelta(OSDelta(
            name: OS_UPDATE_SUBSCRIPTION_DELTA,
            identityModelId: identityModelId,
            model: model,
            property: "notificationTypes",
            value: subscribedNotificationTypes
        ))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.2)

        XCTAssertEqual(client.startedRequests.count, 1, "Follow-up must wait for in-flight UpdateSubscription")

        client.holdResponses = false
        client.releaseHeldResponses()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertEqual(client.startedRequests.count, 2, "Pending follow-up should send after in-flight completes")
        let secondPayload = try XCTUnwrap(
            (client.startedRequests[1] as? OSRequestUpdateSubscription)?.parameters?["subscription"] as? [String: Any]
        )
        XCTAssertEqual(secondPayload["notification_types"] as? Int, subscribedNotificationTypes)
        XCTAssertEqual(secondPayload["enabled"] as? Bool, true)
    }

    /**
     A retryable failure (e.g. 500/timeout) must not leave the single-flight gate locked.
     The failed request becomes resendable and later updates for the model still go out.
     */
    func testRetryableFailureDoesNotBlockSubsequentUpdates() throws {
        let client = MockOneSignalClient()
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)

        let executor = OSSubscriptionOperationExecutor(newRecordsState: OSNewRecordsState())
        let model = makePushSubscriptionModel(notificationTypes: promptedNeverAnswered, subscriptionId: subscriptionId)
        let identityModelId = UUID().uuidString

        // Fail the first update with a retryable error (mock responses are keyed by request description).
        let requestKey = "OSRequestUpdateSubscription with model: \(model.modelId)"
        client.setMockFailureResponseForRequest(
            request: requestKey,
            error: OneSignalClientError(code: 500, message: "retryable", responseHeaders: nil, response: nil, underlyingError: nil)
        )

        executor.enqueueDelta(OSDelta(
            name: OS_UPDATE_SUBSCRIPTION_DELTA,
            identityModelId: identityModelId,
            model: model,
            property: "notificationTypes",
            value: promptedNeverAnswered
        ))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertEqual(client.executedRequests.count, 1, "First update should have been attempted and failed retryably")

        // Server recovers; user accepts permission.
        client.setMockResponseForRequest(request: requestKey, response: [:])
        model.notificationTypes = subscribedNotificationTypes
        XCTAssertTrue(model.enabled)

        executor.enqueueDelta(OSDelta(
            name: OS_UPDATE_SUBSCRIPTION_DELTA,
            identityModelId: identityModelId,
            model: model,
            property: "notificationTypes",
            value: subscribedNotificationTypes
        ))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        let updateRequests = client.executedRequests.compactMap { $0 as? OSRequestUpdateSubscription }
        XCTAssertEqual(updateRequests.count, 2, "Follow-up update must still send after a retryable failure")
        let lastPayload = try XCTUnwrap(updateRequests.last?.parameters?["subscription"] as? [String: Any])
        XCTAssertEqual(lastPayload["notification_types"] as? Int, subscribedNotificationTypes)
        XCTAssertEqual(lastPayload["enabled"] as? Bool, true)
    }

    // MARK: - Helpers

    private func makePushSubscriptionModel(notificationTypes: Int, subscriptionId: String?) -> OSSubscriptionModel {
        let model = OSSubscriptionModel(
            type: .push,
            address: pushToken,
            subscriptionId: subscriptionId,
            reachable: notificationTypes > 0,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
        model.notificationTypes = notificationTypes
        return model
    }
}
