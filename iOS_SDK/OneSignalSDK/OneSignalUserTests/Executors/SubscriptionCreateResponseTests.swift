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
 How the subscription executor handles a CreateSubscription success response.
 */
final class SubscriptionCreateResponseTests: XCTestCase {

    private let email = "test@example.com"
    private let onesignalId = "test-onesignal-id"

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OSConsistencyManager.shared.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }

    /**
     The server answers a create for a subscription that already exists on the user with a 2xx and no
     subscription object. The request is finished, not retried, the model is left as it was, and a
     fetch waiting on this user's read-your-write token is released because none is coming.
     */
    func testResponseWithoutSubscription_completesWithoutHydratingAndReleasesWaiters() throws {
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        client.setMockResponseForRequest(request: createRequestKey, response: [:])

        let executor = OSSubscriptionOperationExecutor(newRecordsState: OSNewRecordsState())
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: onesignalId)
        let model = makeEmailSubscriptionModel()

        // Only a resolve can release this waiter, so it stays blocked if the response is dropped instead of handled.
        let released = expectation(description: "IAM fetch waiter was not released")
        DispatchQueue.global().async {
            _ = OSConsistencyManager.shared.getRywTokenFromAwaitableCondition(UnmetIamFetchCondition(), forId: self.onesignalId)
            released.fulfill()
        }
        OneSignalCoreMocks.waitUntil("Waiter was not registered") { self.waiterCount(forId: self.onesignalId) == 1 }

        executor.enqueueDelta(addDelta(for: model, identityModelId: user.identityModel.modelId))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("Create subscription request did not complete") {
            client.hasCompletedRequestOfType(OSRequestCreateSubscription.self)
        }
        waitForAddRequestQueueToDrain()

        XCTAssertTrue(client.allRequestsHandled)
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCreateSubscription.self, expectedCount: 1))
        XCTAssertNil(model.subscriptionId)
        wait(for: [released], timeout: 3.0)
    }

    /**
     `ryw_token` and `ryw_delay` are siblings of the subscription object, not fields of it.
     */
    func testResponseWithSubscription_hydratesModelAndRecordsTopLevelRywToken() throws {
        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)
        client.setMockResponseForRequest(
            request: createRequestKey,
            response: [
                "subscription": ["id": "email-subscription-id", "type": "Email", "token": email],
                "ryw_token": "ryw-token-1",
                "ryw_delay": 250
            ]
        )

        let executor = OSSubscriptionOperationExecutor(newRecordsState: OSNewRecordsState())
        let user = OneSignalUserMocks.setUserManagerInternalUser(onesignalId: onesignalId)
        let model = makeEmailSubscriptionModel()

        executor.enqueueDelta(addDelta(for: model, identityModelId: user.identityModel.modelId))
        executor.processDeltaQueue(inBackground: false)
        // Hydration is the last step of the success handler, after the token is recorded.
        OneSignalCoreMocks.waitUntil("Subscription model was not hydrated") {
            model.subscriptionId == "email-subscription-id"
        }

        XCTAssertTrue(client.allRequestsHandled)
        let recorded = OSConsistencyManager.shared.getRywTokenFromAwaitableCondition(
            SubscriptionUpdateTokenCondition(id: onesignalId),
            forId: onesignalId
        )
        XCTAssertEqual(recorded?.rywToken, "ryw-token-1")
        XCTAssertEqual(recorded?.rywDelay?.intValue, 250)
    }

    // MARK: - Helpers

    private var createRequestKey: String {
        "<OSRequestCreateSubscription with token: \(email)>"
    }

    private func makeEmailSubscriptionModel() -> OSSubscriptionModel {
        OSSubscriptionModel(
            type: .email,
            address: email,
            subscriptionId: nil,
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
    }

    private func addDelta(for model: OSSubscriptionModel, identityModelId: String) -> OSDelta {
        OSDelta(
            name: OS_ADD_SUBSCRIPTION_DELTA,
            identityModelId: identityModelId,
            model: model,
            property: model.type.rawValue,
            value: model.address ?? ""
        )
    }

    private func waiterCount(forId id: String) -> Int {
        OSConsistencyManager.shared.queue.sync {
            OSConsistencyManager.shared.indexedConditions[id]?.count ?? 0
        }
    }

    private func waitForAddRequestQueueToDrain() {
        OneSignalCoreMocks.waitUntil("Create subscription request was not removed from the cache") {
            let requests = OneSignalUserDefaults.initShared().getSavedCodeableData(
                forKey: OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY,
                defaultValue: []
            ) as? [OSRequestCreateSubscription]
            return requests?.isEmpty == true
        }
    }
}

/// Reads back the subscription-update token recorded for an id without waiting on anything.
private final class SubscriptionUpdateTokenCondition: NSObject, OSCondition {
    private let id: String

    init(id: String) {
        self.id = id
    }

    var conditionId: String { "SubscriptionUpdateTokenCondition" }

    func isMet(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> Bool {
        true
    }

    func getNewestToken(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> OSReadYourWriteData? {
        indexedTokens[id]?[NSNumber(value: OSIamFetchOffsetKey.subscriptionUpdate.rawValue)]
    }
}

/// Never met on its own and carries the IAM fetch condition id, so only the executor's resolve releases it.
private final class UnmetIamFetchCondition: NSObject, OSCondition {
    var conditionId: String { OSIamFetchReadyCondition.CONDITIONID }

    func isMet(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> Bool {
        false
    }

    func getNewestToken(indexedTokens: [String: [NSNumber: OSReadYourWriteData]]) -> OSReadYourWriteData? {
        nil
    }
}
