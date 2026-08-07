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

/// Deltas and the requests built from them stay bound to the user whose change produced them.
final class DeltaOwnershipTests: XCTestCase {

    private let userA = "user-a"
    private let userB = "user-b"
    private let emailAddress = "person@example.com"

    private var manager: OneSignalUserManagerImpl {
        return OneSignalUserManagerImpl.sharedInstance
    }

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())
        // These tests drive the listeners and executors themselves, so keep start() from
        // rebuilding the user underneath them.
        manager.hasCalledStart = true
        // Deltas have to stay in the repo queue long enough to be inspected.
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true
    }

    override func tearDownWithError() throws {
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = false
        OneSignalCoreMocks.clearUserDefaults()
    }

    // MARK: - Model store listeners

    func testPropertiesUpdateDeltaCarriesTheOwningUsersExternalId() throws {
        let user = newUser(externalId: userA)

        let delta = try XCTUnwrap(manager.propertiesModelStoreListener.getUpdateModelDelta(
            OSModelChangedArgs(model: user.propertiesModel, property: "tags", newValue: ["tag": "value"])
        ))

        XCTAssertEqual(delta.externalId, userA)
        XCTAssertEqual(delta.identityModelId, user.identityModel.modelId)
    }

    /// Anonymous work must stay stamped nil; filling it in later would attribute it to the wrong user.
    func testPropertiesUpdateDeltaFromAnAnonymousUserHasNoExternalId() throws {
        let user = newUser(externalId: nil)

        let delta = try XCTUnwrap(manager.propertiesModelStoreListener.getUpdateModelDelta(
            OSModelChangedArgs(model: user.propertiesModel, property: "tags", newValue: ["tag": "value"])
        ))

        XCTAssertNil(delta.externalId)
        XCTAssertEqual(delta.identityModelId, user.identityModel.modelId)
    }

    func testAliasDeltaCarriesTheOwningUsersExternalId() throws {
        let user = newUser(externalId: userA)

        let delta = try XCTUnwrap(manager.identityModelStoreListener.getUpdateModelDelta(
            OSModelChangedArgs(model: user.identityModel, property: "aliases", newValue: ["my_alias": "my-alias-id"])
        ))

        XCTAssertEqual(delta.name, OS_ADD_ALIAS_DELTA)
        XCTAssertEqual(delta.externalId, userA)
        XCTAssertEqual(delta.identityModelId, user.identityModel.modelId)
    }

    /// Stamped from the changed Identity Model, so a post-switch alias change keeps its owner.
    func testAliasDeltaIsStampedFromTheChangedIdentityNotTheCurrentUser() throws {
        let first = newUser(externalId: userA)
        newUser(externalId: userB)

        let delta = try XCTUnwrap(manager.identityModelStoreListener.getUpdateModelDelta(
            OSModelChangedArgs(model: first.identityModel, property: "aliases", newValue: ["my_alias": "my-alias-id"])
        ))

        XCTAssertEqual(delta.externalId, userA)
        XCTAssertEqual(delta.identityModelId, first.identityModel.modelId)
    }

    func testSubscriptionAddDeltaCarriesTheOwningUsersExternalId() throws {
        let user = newUser(externalId: userA)

        let delta = try XCTUnwrap(manager.subscriptionModelStoreListener.getAddModelDelta(emailSubscriptionModel()))

        XCTAssertEqual(delta.externalId, userA)
        XCTAssertEqual(delta.identityModelId, user.identityModel.modelId)
    }

    func testSubscriptionRemoveDeltaCarriesTheOwningUsersExternalId() throws {
        let user = newUser(externalId: userA)

        let delta = try XCTUnwrap(manager.subscriptionModelStoreListener.getRemoveModelDelta(emailSubscriptionModel()))

        XCTAssertEqual(delta.externalId, userA)
        XCTAssertEqual(delta.identityModelId, user.identityModel.modelId)
    }

    func testSubscriptionUpdateDeltaCarriesTheOwningUsersExternalId() throws {
        let user = newUser(externalId: userA)

        let delta = try XCTUnwrap(manager.subscriptionModelStoreListener.getUpdateModelDelta(
            OSModelChangedArgs(model: emailSubscriptionModel(), property: "enabled", newValue: true)
        ))

        XCTAssertEqual(delta.externalId, userA)
        XCTAssertEqual(delta.identityModelId, user.identityModel.modelId)
    }

    // MARK: - Deltas the User Manager enqueues itself

    /// Session time and custom events skip the model stores, so they are stamped at enqueue.
    func testDeltasEnqueuedByTheUserManagerCarryTheOwningUsersExternalId() throws {
        let user = newUser(externalId: userA)

        manager.sendSessionTime(100)
        manager.trackEvent(name: "test_event", properties: nil)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        let sessionDelta = try XCTUnwrap(queuedDelta(
            named: OS_UPDATE_PROPERTIES_DELTA,
            property: OSPropertiesSupportedProperty.session_time.rawValue
        ))
        let eventDelta = try XCTUnwrap(queuedDelta(named: OS_CUSTOM_EVENT_DELTA, property: "test_event"))

        XCTAssertEqual(sessionDelta.externalId, userA)
        XCTAssertEqual(sessionDelta.identityModelId, user.identityModel.modelId)
        XCTAssertEqual(eventDelta.externalId, userA)
        XCTAssertEqual(eventDelta.identityModelId, user.identityModel.modelId)
    }

    /// A queued Delta is already owned; a user switch must not rewrite it.
    func testAQueuedDeltaKeepsItsOwnerAfterTheCurrentUserChanges() throws {
        let first = newUser(externalId: userA)

        manager.sendSessionTime(100)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        newUser(externalId: userB)

        let delta = try XCTUnwrap(queuedDelta(
            named: OS_UPDATE_PROPERTIES_DELTA,
            property: OSPropertiesSupportedProperty.session_time.rawValue
        ))

        XCTAssertEqual(delta.externalId, userA)
        XCTAssertEqual(delta.identityModelId, first.identityModel.modelId)
    }

    // MARK: - Requests built from a Delta

    func testUpdateSubscriptionRequestIsBoundToTheDeltasOwner() throws {
        let client = executingClient()
        let user = newUser(externalId: userA)
        let executor = OSSubscriptionOperationExecutor(newRecordsState: OSNewRecordsState())

        executor.enqueueDelta(subscriptionUpdateDelta(owner: user.identityModel))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        let request = try XCTUnwrap(client.executedRequests.compactMap { $0 as? OSRequestUpdateSubscription }.first)
        XCTAssertTrue(request.identityModel === user.identityModel)
    }

    /// Unknown owner still sends; only the RYW token is dropped, not misfiled under the current user.
    func testASubscriptionRequestStillSendsWhenTheOwningIdentityIsUnknown() throws {
        let client = executingClient()
        newUser(externalId: userB)
        let unknownOwner = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA], changeNotifier: OSEventProducer())
        let executor = OSSubscriptionOperationExecutor(newRecordsState: OSNewRecordsState())

        executor.enqueueDelta(subscriptionUpdateDelta(owner: unknownOwner))
        executor.processDeltaQueue(inBackground: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        let request = try XCTUnwrap(client.executedRequests.compactMap { $0 as? OSRequestUpdateSubscription }.first)
        XCTAssertNil(request.identityModel)
    }

    // MARK: - Helpers

    @discardableResult
    private func newUser(externalId: String?) -> OSUserInternal {
        return manager.setNewInternalUser(
            externalId: externalId,
            pushSubscriptionModel: OSSubscriptionModel(
                type: .push,
                address: "",
                subscriptionId: UUID().uuidString,
                reachable: false,
                isDisabled: false,
                changeNotifier: OSEventProducer()
            )
        )
    }

    private func executingClient() -> MockOneSignalClient {
        let client = MockOneSignalClient()
        client.fireSuccessForAllRequests = true
        OneSignalCoreImpl.setSharedClient(client)
        return client
    }

    private func emailSubscriptionModel() -> OSSubscriptionModel {
        return OSSubscriptionModel(
            type: .email,
            address: emailAddress,
            subscriptionId: "test-subscription-id",
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
    }

    private func subscriptionUpdateDelta(owner: OSIdentityModel) -> OSDelta {
        let model = emailSubscriptionModel()
        return OSDelta(
            name: OS_UPDATE_SUBSCRIPTION_DELTA,
            identityModelId: owner.modelId,
            externalId: owner.externalId,
            model: model,
            property: model.type.rawValue,
            value: model.address ?? ""
        )
    }

    private func queuedDelta(named name: String, property: String) -> OSDelta? {
        return OneSignalUserManagerImpl.sharedInstance.operationRepo.deltaQueue.first { $0.name == name && $0.property == property }
    }
}
