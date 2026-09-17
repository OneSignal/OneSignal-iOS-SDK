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
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalUser

/**
 What each executor records for the in-app message fetch, with and without a `ryw_token` in the response.

 The fetch waits on `OSIamFetchReadyCondition`, which only asks whether the writes it cares about have
 completed. A response with no token still completes the write, so the executor files an entry with no
 token under its own key. A fetch that registers afterwards finds the entry and goes out, instead of
 waiting the full timeout for a token that is never coming.
 */
final class ExecutorReadYourWriteTests: XCTestCase {
    private var client = MockOneSignalClient()
    private var newRecordsState = MockNewRecordsState()
    private var user = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        ConsistencyManagerTestHelpers.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)
        newRecordsState = MockNewRecordsState()
        user = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID, OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(user)
    }

    override func tearDownWithError() throws {
        ConsistencyManagerTestHelpers.reset()
        OneSignalCoreMocks.clearUserDefaults()
    }

    // MARK: - Tests

    func testACreateUserResponseWithNoTokenStillReadiesTheFetch() {
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userA_EUID)
        let executor = OSUserExecutor(
            newRecordsState: newRecordsState,
            identityVerificationService: OneSignalUserManagerImpl.sharedInstance.identityVerificationService,
            auth: auth
        )
        let identity = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())

        executor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userA_EUID, identityModel: identity)

        OneSignalCoreMocks.waitUntil("A tokenless Create User left the fetch waiting") { self.fetchIsReady(for: userA_OSID) }
    }

    func testAnUpdatePropertiesResponseWithNoTokenStillReadiesTheFetch() {
        let executor = OSPropertyOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(OSDelta(
            name: OS_UPDATE_PROPERTIES_DELTA,
            identityModelId: user.modelId,
            externalId: user.externalId,
            model: OSModel(changeNotifier: OSEventProducer()),
            property: "language",
            value: "en"
        ))

        executor.processDeltaQueue(inBackground: false)

        OneSignalCoreMocks.waitUntil("A tokenless Update Properties left the fetch waiting") { self.fetchIsReady(for: userA_OSID) }
    }

    func testACreateSubscriptionResponseWithNoTokenStillReadiesAFetchHeldForIt() {
        holdTheFetchForASubscriptionUpdate()
        let email = "a@example.com"
        MockUserRequests.setAddEmailResponse(with: client, email: email)
        let executor = OSSubscriptionOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(subscriptionDelta(OS_ADD_SUBSCRIPTION_DELTA, model: subscription(type: .email, address: email, id: nil)))

        executor.processDeltaQueue(inBackground: false)

        OneSignalCoreMocks.waitUntil("A tokenless Create Subscription left the fetch waiting") { self.fetchIsReady(for: userA_OSID) }
    }

    /// The create response carries `ryw_token` beside `subscription`, and it has to be read from there.
    func testACreateSubscriptionResponseWithATokenFilesItForTheFetch() {
        let email = "a@example.com"
        client.setMockResponseForRequest(
            request: "<OSRequestCreateSubscription with token: \(email)>",
            response: [
                "subscription": ["id": "\(email)_id", "type": "Email", "token": email],
                "ryw_token": "0900",
                "ryw_delay": 250
            ]
        )
        let executor = OSSubscriptionOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(subscriptionDelta(OS_ADD_SUBSCRIPTION_DELTA, model: subscription(type: .email, address: email, id: nil)))

        executor.processDeltaQueue(inBackground: false)

        OneSignalCoreMocks.waitUntil("The Create Subscription token was not filed") {
            self.filedEntry(for: userA_OSID, key: .subscriptionUpdate)?.rywToken == "0900"
        }
        XCTAssertEqual(filedEntry(for: userA_OSID, key: .subscriptionUpdate)?.rywDelay?.intValue, 250)
    }

    func testAnUpdateSubscriptionResponseWithNoTokenStillReadiesAFetchHeldForIt() {
        holdTheFetchForASubscriptionUpdate()
        let executor = OSSubscriptionOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        let push = subscription(type: .push, address: "push-token", id: "push-sub-id")
        executor.enqueueDelta(subscriptionDelta(OS_UPDATE_SUBSCRIPTION_DELTA, model: push))

        executor.processDeltaQueue(inBackground: false)

        OneSignalCoreMocks.waitUntil("A tokenless Update Subscription left the fetch waiting") { self.fetchIsReady(for: userA_OSID) }
    }

    // MARK: - Helpers

    private var auth: OSRequestAuthorizing {
        return OneSignalUserManagerImpl.sharedInstance.requestAuth
    }

    /// Whether a fetch for the user would go out now rather than wait.
    private func fetchIsReady(for onesignalId: String) -> Bool {
        return OSIamFetchReadyCondition.sharedInstance(withId: onesignalId)
            .isMet(indexedTokens: OSConsistencyManager.shared.snapshotTokens())
    }

    /// What is on file for the user under one key, or nil when nothing has been filed there.
    private func filedEntry(for onesignalId: String, key: OSIamFetchOffsetKey) -> OSReadYourWriteData? {
        return OSConsistencyManager.shared.snapshotTokens()[onesignalId]?[NSNumber(value: key.rawValue)]
    }

    /// A subscription update in flight holds the fetch until that write completes, even with a user token on file.
    private func holdTheFetchForASubscriptionUpdate() {
        OSIamFetchReadyCondition.sharedInstance(withId: userA_OSID).setSubscriptionUpdatePending(value: true)
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: userA_OSID)
        XCTAssertFalse(fetchIsReady(for: userA_OSID), "the fetch has to be held before the write completes")
    }

    private func subscription(type: OSSubscriptionType, address: String, id: String?) -> OSSubscriptionModel {
        return OSSubscriptionModel(
            type: type,
            address: address,
            subscriptionId: id,
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
    }

    private func subscriptionDelta(_ name: String, model: OSSubscriptionModel) -> OSDelta {
        return OSDelta(name: name, identityModelId: user.modelId, externalId: user.externalId, model: model, property: "optedIn", value: true)
    }
}
