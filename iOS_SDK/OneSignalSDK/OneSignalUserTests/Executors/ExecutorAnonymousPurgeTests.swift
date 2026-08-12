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
 What each executor drops from its queues when Identity Verification turns out to be required.

 Only ownership is judged: a Delta or Request carries the `external_id` of the user it was built for, and
 one carrying none can never be signed. The auth layer refuses to send those, so the purge is what keeps
 them from sitting in the queues unsendable for the rest of the session.
 */
final class ExecutorAnonymousPurgeTests: XCTestCase {
    private let anonymousOSID = "test-anonymous-onesignal-id"
    private let ownedToken = "token-a"
    private let anonymousSubscriptionId = "test-anonymous-subscription-id"
    private let ownedSubscriptionId = "test-owned-subscription-id"

    private var client = MockOneSignalClient()
    private var newRecordsState = MockNewRecordsState()
    private var anonymous = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())
    private var owned = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)
        newRecordsState = MockNewRecordsState()
        // Presence is the hold: the production timer is a no-op under TEST.
        newRecordsState.holdWhilePresent = true

        // The purge only ever runs because the requirement came back requiring auth.
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        anonymous = addUserToRepo(externalId: nil, onesignalId: anonymousOSID)
        owned = addUserToRepo(externalId: userA_EUID, onesignalId: userA_OSID)
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    // MARK: - Setup helpers

    /// A user the executors can resolve Deltas and Requests against. The identified one can sign.
    private func addUserToRepo(externalId: String?, onesignalId: String) -> OSIdentityModel {
        var aliases = [OS_ONESIGNAL_ID: onesignalId]
        if let externalId = externalId {
            aliases[OS_EXTERNAL_ID] = externalId
        }
        let model = OSIdentityModel(aliases: aliases, changeNotifier: OSEventProducer())
        if externalId != nil {
            model.jwtBearerToken = ownedToken
        }
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(model)
        return model
    }

    /// Holds both users' ids, and any others passed, so nothing can be sent while they propagate. The
    /// Requests the Deltas became then wait in the executor's queues, which is where the purge is visible.
    private func holdIds(_ ids: String...) {
        for id in [anonymousOSID, userA_OSID] + ids {
            newRecordsState.add(id)
        }
    }

    private var auth: OSRequestAuthorizing {
        return OneSignalUserManagerImpl.sharedInstance.requestAuth
    }

    private func delta(_ name: String, for identityModel: OSIdentityModel, model: OSModel, property: String, value: Any) -> OSDelta {
        return OSDelta(
            name: name,
            identityModelId: identityModel.modelId,
            externalId: identityModel.externalId,
            model: model,
            property: property,
            value: value
        )
    }

    private func subscription(id: String) -> OSSubscriptionModel {
        return OSSubscriptionModel(
            type: .email,
            address: "\(id)@example.com",
            subscriptionId: id,
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
    }

    // MARK: - Assertion helpers

    private func cachedRequestOwners<T: OSUserRequest>(_ key: String, of type: T.Type) -> [String?] {
        let requests = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: key, defaultValue: []) as? [T] ?? []
        return requests.map { $0.ownerExternalId }
    }

    private func executedPaths() -> [String] {
        return client.executedRequests.map { $0.path }
    }

    private func userPath(_ suffix: String = "") -> String {
        return "apps/test-app-id/users/by/\(OS_EXTERNAL_ID)/\(userA_EUID)" + suffix
    }

    // MARK: - Properties

    func testThePropertyExecutorSendsOnlyTheIdentifiedUsersUpdate() {
        let executor = OSPropertyOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(propertiesDelta(for: anonymous))
        executor.enqueueDelta(propertiesDelta(for: owned))

        executor.removeOperationsWithoutExternalId()
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("The identified user's Update Properties was not sent") {
            self.client.hasExecutedRequestOfType(OSRequestUpdateProperties.self, expectedCount: 1)
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestUpdateProperties.self, expectedCount: 1))
        XCTAssertEqual(executedPaths(), [userPath()])
    }

    func testThePropertyExecutorDropsTheAnonymousUpdateRequest() {
        holdIds()
        let executor = OSPropertyOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(propertiesDelta(for: anonymous))
        executor.enqueueDelta(propertiesDelta(for: owned))
        executor.processDeltaQueue(inBackground: false)
        allowAsyncWorkToRun()
        XCTAssertEqual(client.executedRequests.count, 0)

        executor.removeOperationsWithoutExternalId()
        OneSignalCoreMocks.waitUntil("The purge did not reach the cached Update Properties queue") {
            self.cachedRequestOwners(OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, of: OSRequestUpdateProperties.self) == [userA_EUID]
        }

        XCTAssertEqual(cachedRequestOwners(OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, of: OSRequestUpdateProperties.self), [userA_EUID])
    }

    /// The purge writes through to the cache, so a relaunch reads back the identified user's Request alone.
    func testAnAnonymousUpdateRequestIsNotRestoredAfterThePurge() {
        holdIds()
        let executor = OSPropertyOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(propertiesDelta(for: anonymous))
        executor.enqueueDelta(propertiesDelta(for: owned))
        executor.processDeltaQueue(inBackground: false)
        executor.removeOperationsWithoutExternalId()
        // The relaunch reads the cache, so the purge has to have been written before it is built.
        OneSignalCoreMocks.waitUntil("The purge did not reach the cached Update Properties queue") {
            self.cachedRequestOwners(OS_PROPERTIES_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, of: OSRequestUpdateProperties.self) == [userA_EUID]
        }

        // A records state with nothing held stands in for ids that have since propagated.
        newRecordsState = MockNewRecordsState()
        let relaunched = OSPropertyOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        relaunched.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("The restored Update Properties was not sent") {
            self.client.hasExecutedRequestOfType(OSRequestUpdateProperties.self, expectedCount: 1)
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestUpdateProperties.self, expectedCount: 1))
        XCTAssertEqual(executedPaths(), [userPath()])
    }

    private func propertiesDelta(for identityModel: OSIdentityModel) -> OSDelta {
        return delta(
            OS_UPDATE_PROPERTIES_DELTA,
            for: identityModel,
            model: OSModel(changeNotifier: OSEventProducer()),
            property: "language",
            value: "en"
        )
    }

    // MARK: - Custom events

    func testTheCustomEventsExecutorSendsOnlyTheIdentifiedUsersEvents() {
        let executor = OSCustomEventsExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(customEventDelta(for: anonymous))
        executor.enqueueDelta(customEventDelta(for: owned))

        executor.removeOperationsWithoutExternalId()
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("The identified user's Custom Events was not sent") {
            self.client.hasExecutedRequestOfType(OSRequestCustomEvents.self, expectedCount: 1)
        }

        // The path names the app rather than the user, so the events themselves say who survived.
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCustomEvents.self, expectedCount: 1))
        let events = client.executedRequests.first?.parameters?["events"] as? [[String: Any]]
        XCTAssertEqual(events?.count, 1)
        XCTAssertEqual(events?.first?["onesignal_id"] as? String, userA_OSID)
    }

    func testTheCustomEventsExecutorDropsTheAnonymousEventsRequest() {
        holdIds()
        let executor = OSCustomEventsExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(customEventDelta(for: anonymous))
        executor.enqueueDelta(customEventDelta(for: owned))
        executor.processDeltaQueue(inBackground: false)
        allowAsyncWorkToRun()
        XCTAssertEqual(client.executedRequests.count, 0)

        executor.removeOperationsWithoutExternalId()
        OneSignalCoreMocks.waitUntil("The purge did not reach the cached Custom Events queue") {
            self.cachedRequestOwners(OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, of: OSRequestCustomEvents.self) == [userA_EUID]
        }

        XCTAssertEqual(cachedRequestOwners(OS_CUSTOM_EVENTS_EXECUTOR_REQUEST_QUEUE_KEY, of: OSRequestCustomEvents.self), [userA_EUID])
    }

    private func customEventDelta(for identityModel: OSIdentityModel) -> OSDelta {
        return delta(
            OS_CUSTOM_EVENT_DELTA,
            for: identityModel,
            model: OSModel(changeNotifier: OSEventProducer()),
            property: "test_event",
            value: ["test_property": "test-value"]
        )
    }

    // MARK: - Identity

    func testTheIdentityExecutorSendsOnlyTheIdentifiedUsersAlias() {
        let executor = OSIdentityOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(addAliasDelta(for: anonymous))
        executor.enqueueDelta(addAliasDelta(for: owned))

        executor.removeOperationsWithoutExternalId()
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("The identified user's Add Aliases was not sent") {
            self.client.hasExecutedRequestOfType(OSRequestAddAliases.self, expectedCount: 1)
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestAddAliases.self, expectedCount: 1))
        XCTAssertEqual(executedPaths(), [userPath("/identity")])
    }

    func testTheIdentityExecutorDropsBothAnonymousAliasRequests() {
        holdIds()
        let executor = OSIdentityOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        for identity in [anonymous, owned] {
            executor.enqueueDelta(addAliasDelta(for: identity))
            executor.enqueueDelta(removeAliasDelta(for: identity))
        }
        executor.processDeltaQueue(inBackground: false)
        allowAsyncWorkToRun()
        XCTAssertEqual(client.executedRequests.count, 0)

        executor.removeOperationsWithoutExternalId()
        OneSignalCoreMocks.waitUntil("The purge did not reach both cached alias queues") {
            self.cachedRequestOwners(OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, of: OSRequestAddAliases.self) == [userA_EUID]
                && self.cachedRequestOwners(OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, of: OSRequestRemoveAlias.self) == [userA_EUID]
        }

        XCTAssertEqual(cachedRequestOwners(OS_IDENTITY_EXECUTOR_ADD_REQUEST_QUEUE_KEY, of: OSRequestAddAliases.self), [userA_EUID])
        XCTAssertEqual(cachedRequestOwners(OS_IDENTITY_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, of: OSRequestRemoveAlias.self), [userA_EUID])
    }

    private func addAliasDelta(for identityModel: OSIdentityModel) -> OSDelta {
        return delta(
            OS_ADD_ALIAS_DELTA,
            for: identityModel,
            model: identityModel,
            property: "aliases",
            value: ["test_alias_label": "test-alias-id"]
        )
    }

    private func removeAliasDelta(for identityModel: OSIdentityModel) -> OSDelta {
        return delta(
            OS_REMOVE_ALIAS_DELTA,
            for: identityModel,
            model: identityModel,
            property: "aliases",
            value: ["test_alias_label": ""]
        )
    }

    // MARK: - Subscriptions

    func testTheSubscriptionExecutorSendsOnlyTheIdentifiedUsersNewSubscription() {
        let executor = OSSubscriptionOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        executor.enqueueDelta(addSubscriptionDelta(for: anonymous, subscriptionId: anonymousSubscriptionId))
        executor.enqueueDelta(addSubscriptionDelta(for: owned, subscriptionId: ownedSubscriptionId))

        executor.removeOperationsWithoutExternalId()
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitUntil("The identified user's Create Subscription was not sent") {
            self.client.hasExecutedRequestOfType(OSRequestCreateSubscription.self, expectedCount: 1)
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCreateSubscription.self, expectedCount: 1))
        XCTAssertEqual(executedPaths(), [userPath("/subscriptions")])
    }

    func testTheSubscriptionExecutorDropsTheAnonymousAddAndDeleteRequests() {
        holdIds(anonymousSubscriptionId, ownedSubscriptionId)
        let executor = OSSubscriptionOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        enqueueSubscriptionWork(on: executor)
        allowAsyncWorkToRun()
        XCTAssertEqual(client.executedRequests.count, 0)

        executor.removeOperationsWithoutExternalId()
        OneSignalCoreMocks.waitUntil("The purge did not reach both cached subscription queues") {
            self.cachedRequestOwners(OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, of: OSRequestCreateSubscription.self) == [userA_EUID]
                && self.cachedRequestOwners(OS_SUBSCRIPTION_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, of: OSRequestDeleteSubscription.self) == [userA_EUID]
        }

        XCTAssertEqual(cachedRequestOwners(OS_SUBSCRIPTION_EXECUTOR_ADD_REQUEST_QUEUE_KEY, of: OSRequestCreateSubscription.self), [userA_EUID])
        XCTAssertEqual(cachedRequestOwners(OS_SUBSCRIPTION_EXECUTOR_REMOVE_REQUEST_QUEUE_KEY, of: OSRequestDeleteSubscription.self), [userA_EUID])
    }

    /// An Update Subscription is addressed by subscription ID and never signed, so it has no owner to be
    /// judged by and the purge has to leave that queue alone: `logout()`'s unsubscribe travels in it.
    func testTheSubscriptionExecutorKeepsEveryUpdateRequest() {
        holdIds(anonymousSubscriptionId, ownedSubscriptionId)
        let executor = OSSubscriptionOperationExecutor(newRecordsState: newRecordsState, auth: auth)
        enqueueSubscriptionWork(on: executor)
        OneSignalCoreMocks.waitUntil("Both Update Subscriptions were not cached") {
            self.cachedRequestOwners(OS_SUBSCRIPTION_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, of: OSRequestUpdateSubscription.self).count == 2
        }

        executor.removeOperationsWithoutExternalId()
        // Nothing to poll for: the assertion is that the purge left this queue as it found it.
        allowAsyncWorkToRun()

        let updateOwners = cachedRequestOwners(OS_SUBSCRIPTION_EXECUTOR_UPDATE_REQUEST_QUEUE_KEY, of: OSRequestUpdateSubscription.self)
        XCTAssertEqual(updateOwners.count, 2)
        XCTAssertTrue(updateOwners.allSatisfy { $0 == nil })
    }

    /// An add, a delete and an update for each user, turned into Requests that cannot be sent yet.
    private func enqueueSubscriptionWork(on executor: OSSubscriptionOperationExecutor) {
        for (identity, subscriptionId) in [(anonymous, anonymousSubscriptionId), (owned, ownedSubscriptionId)] {
            let model = subscription(id: subscriptionId)
            for name in [OS_ADD_SUBSCRIPTION_DELTA, OS_REMOVE_SUBSCRIPTION_DELTA, OS_UPDATE_SUBSCRIPTION_DELTA] {
                executor.enqueueDelta(subscriptionDelta(name, for: identity, subscription: model))
            }
        }
        executor.processDeltaQueue(inBackground: false)
    }

    private func addSubscriptionDelta(for identityModel: OSIdentityModel, subscriptionId: String) -> OSDelta {
        return subscriptionDelta(OS_ADD_SUBSCRIPTION_DELTA, for: identityModel, subscription: subscription(id: subscriptionId))
    }

    private func subscriptionDelta(_ name: String, for identityModel: OSIdentityModel, subscription: OSSubscriptionModel) -> OSDelta {
        return delta(name, for: identityModel, model: subscription, property: "optedIn", value: true)
    }
}
