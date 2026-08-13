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
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalUser

/// This class has helpers that can be used in other tests and can be extracted out, as they are used
private class Mocks {
    let client = MockOneSignalClient()
    let newRecordsState = MockNewRecordsState()
    let userExecutor: OSUserExecutor

    /// Stub before building the executor so a seeded Request cache cannot race the init-time send.
    init(stubResponses: (MockOneSignalClient) -> Void = { _ in }) {
        OneSignalCoreImpl.setSharedClient(client)
        stubResponses(client)
        userExecutor = OSUserExecutor(newRecordsState: newRecordsState, identityVerificationService: OneSignalUserManagerImpl.sharedInstance.identityVerificationService, auth: OneSignalUserManagerImpl.sharedInstance.requestAuth)
    }

    func createUserInstance(externalId: String) -> OSUserInternal {
        let identityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: externalId], changeNotifier: OSEventProducer())
        let propertiesModel = OSPropertiesModel(changeNotifier: OSEventProducer())
        let pushModel = OSSubscriptionModel(type: .push, address: "", subscriptionId: nil, reachable: false, isDisabled: false, changeNotifier: OSEventProducer())
        return OSUserInternalImpl(identityModel: identityModel, propertiesModel: propertiesModel, pushSubscriptionModel: pushModel)
    }
}

final class UserExecutorTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        // App ID is set because requests have guards against null App ID
        OneSignalIdentifiers.currentAppId = "test-app-id"
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }

    func testCreateUser_withPushSubscription_addsToNewRecords() {
        /* Setup */
        let mocks = Mocks()
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID, subscriptionId: "push-sub-id")
        let user = mocks.createUserInstance(externalId: userA_EUID)
        // Current so Create User keeps push; otherwise a prior-user create omits subscriptions.
        OneSignalUserManagerImpl.sharedInstance._user = user

        /* When */
        mocks.userExecutor.createUser(user)
        OneSignalCoreMocks.waitUntil("Create user response was not applied") {
            mocks.newRecordsState.contains(userA_OSID)
                && mocks.newRecordsState.contains("push-sub-id")
        }

        /* Then */
        XCTAssertTrue(mocks.newRecordsState.contains(userA_OSID))
        XCTAssertTrue(mocks.newRecordsState.contains("push-sub-id"))
    }

    /// A Create User for a prior login must not include the device push subscription, which the
    /// current user now owns — sending it would transfer that push on the server.
    func testCreateUser_forPriorIdentifiedUser_omitsPushSubscription() {
        /* Setup */
        let mocks = Mocks()
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID, subscriptionId: "push-sub-id")

        let sharedPush = OSSubscriptionModel(
            type: .push,
            address: "test-push-token",
            subscriptionId: "shared-push-id",
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
        let priorIdentity = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        let priorProperties = OSPropertiesModel(changeNotifier: OSEventProducer())
        let priorCreate = OSRequestCreateUser(
            identityModel: priorIdentity,
            propertiesModel: priorProperties,
            pushSubscriptionModel: sharedPush,
            originalPushToken: sharedPush.address
        )
        XCTAssertNotNil(priorCreate.parameters?["subscriptions"])

        // Device push now belongs to the current user (B); the parked create still holds the same model.
        let currentUser = mocks.createUserInstance(externalId: userB_EUID)
        currentUser.pushSubscriptionModel.subscriptionId = "shared-push-id"
        OneSignalUserManagerImpl.sharedInstance._user = currentUser
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModelStore.add(
            id: OS_PUSH_SUBSCRIPTION_MODEL_KEY,
            model: sharedPush,
            hydrating: false
        )

        /* When */
        mocks.userExecutor.executeCreateUserRequest(priorCreate)
        // The new-record cool-down is stamped while handling the response, so it lands after the send.
        OneSignalCoreMocks.waitUntil("Create User response was not handled") {
            mocks.newRecordsState.contains(userA_OSID)
        }

        /* Then */
        guard let sent = mocks.client.executedRequests.compactMap({ $0 as? OSRequestCreateUser }).first else {
            XCTFail("Expected Create User to be sent")
            return
        }
        XCTAssertNil(sent.parameters?["subscriptions"], "Must not transfer the current user's push to a prior Create User")
        // Built as a real create, so cool-down the onesignal_id even though push was omitted at send.
        XCTAssertTrue(mocks.newRecordsState.contains(userA_OSID))
        XCTAssertFalse(mocks.newRecordsState.contains("push-sub-id"))
        XCTAssertFalse(mocks.newRecordsState.contains("shared-push-id"))
    }

    /// Identify-409 recovery Create only hydrates an existing user, so its IDs are not new.
    func testCreateUser_withoutPushSubscription_doesNot_addToNewRecords() {
        /* Setup */
        let mocks = Mocks()
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID)

        /* When */
        let identityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        mocks.userExecutor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userA_EUID, identityModel: identityModel)

        OneSignalCoreMocks.waitUntil("Create user request did not complete") {
            mocks.client.hasCompletedRequestOfType(OSRequestCreateUser.self)
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
        XCTAssertTrue(mocks.newRecordsState.records.isEmpty)
    }

    /**
     When an external ID is successfully applied to an anonymous user, its Onesignal ID should be force re-added to
     the new records state with an updated timestamp. This is to prevent an immediate fetch where the external ID
     can be missing from the fetch response, as it has not finished being applied to the user on the backend.
     */
    func testIdentifyUser_successfully_forcesAddToNewRecords() {
        /* Setup */
        let mocks = Mocks()
        MockUserRequests.setDefaultIdentifyUserResponses(with: mocks.client, externalId: userA_EUID, conflicted: false)

        /* When */
        let anonIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        let newIdentityModel = OneSignalUserMocks
            .setUserManagerInternalUser(externalId: userA_EUID, onesignalId: nil)
            .identityModel
        mocks.userExecutor.identifyUser(externalId: userA_EUID, identityModelToIdentify: anonIdentityModel, identityModelToUpdate: newIdentityModel)

        OneSignalCoreMocks.waitUntil("Identify user response was not applied") {
            mocks.newRecordsState.wasOverwritten(userA_OSID)
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertTrue(mocks.newRecordsState.contains(userA_OSID))
        XCTAssertTrue(mocks.newRecordsState.wasOverwritten(userA_OSID))
    }

    /**
     When an external ID is successfully applied to an anonymous user, but the current user is no longer the same,
     nothing is added to the new records state.
     */
    func testIdentifyUserSuccessful_butUserHasChangedSince_doesNotAddToNewRecords() {
        /* Setup */
        let mocks = Mocks()
        MockUserRequests.setDefaultIdentifyUserResponses(with: mocks.client, externalId: userA_EUID, conflicted: false)

        /* When */
        let anonIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        let newIdentityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())

        mocks.userExecutor.identifyUser(externalId: userA_EUID, identityModelToIdentify: anonIdentityModel, identityModelToUpdate: newIdentityModel)
        OneSignalCoreMocks.waitUntil("Identify user request did not complete") {
            mocks.client.hasCompletedRequestOfType(OSRequestIdentifyUser.self)
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertTrue(mocks.newRecordsState.records.isEmpty)
    }

    /**
     When Identify User encounters a 409 conflict, a Create User call will be made.
     The response from that request will add its Onesignal ID to the new records state.
     */
    func testIdentifyUser_withConflict_addsToNewRecords() {
        /* Setup */
        let mocks = Mocks()
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: nil)

        let anonIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        let newIdentityModel = user.identityModel

        MockUserRequests.setDefaultIdentifyUserResponses(with: mocks.client, externalId: userB_EUID, conflicted: true)

        /* When */
        mocks.userExecutor.identifyUser(externalId: userB_EUID, identityModelToIdentify: anonIdentityModel, identityModelToUpdate: newIdentityModel)
        let userCreated = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in mocks.newRecordsState.contains(userB_OSID) },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [userCreated], timeout: 5), .completed)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
        XCTAssertEqual(mocks.newRecordsState.records.count, 1)
        XCTAssertTrue(mocks.newRecordsState.contains(userB_OSID))
    }

    func testIdentifyUserWithConflict_butUserHasChangedSince_doesNot_addToNewRecords() {
        /* Setup */
        let mocks = Mocks()

        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: "new-eid", onesignalId: nil)
        let anonIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        let newIdentityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userB_EUID], changeNotifier: OSEventProducer())

        MockUserRequests.setDefaultIdentifyUserResponses(with: mocks.client, externalId: userB_EUID, conflicted: true)

        /* When */
        mocks.userExecutor.identifyUser(externalId: userB_EUID, identityModelToIdentify: anonIdentityModel, identityModelToUpdate: newIdentityModel)

        OneSignalCoreMocks.waitUntil("Conflict create user request did not complete") {
            mocks.client.hasCompletedRequestOfType(OSRequestCreateUser.self)
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
        XCTAssertTrue(mocks.newRecordsState.records.isEmpty)
    }

    /**
     Regression test for a login race that landed identity (and subsequent user updates) data on the wrong user.

     When an on-new-session Fetch User request for a *previous* user (e.g. a cached anonymous user) is still
     pending and a `login()` switches the current user, the in-flight Fetch User must NOT clear the new current
     user's data.
     */
    func testFetchUser_forNonCurrentUser_doesNotClearCurrentUserData() {
        /* Setup */
        let mocks = Mocks()

        // The current user has just logged in with an external_id (userB).
        let currentUser = OneSignalUserMocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: userB_OSID)

        // A stale on-new-session Fetch User is in flight for a different, no-longer-current user (userA),
        // and its response only carries an onesignal_id (as an anonymous user's would).
        let staleIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        mocks.client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with onesignal_id: \(userA_OSID)>",
            response: MockUserRequests.testIdentityPayload(onesignalId: userA_OSID, externalId: nil)
        )

        /* When */
        mocks.userExecutor.fetchUser(aliasLabel: OS_ONESIGNAL_ID, aliasId: userA_OSID, identityModel: staleIdentityModel, onNewSession: true)
        OneSignalCoreMocks.waitUntil("Stale fetch user request did not complete") {
            mocks.client.hasCompletedRequestOfType(OSRequestFetchUser.self)
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        // The current user's external_id must be intact — the stale fetch must not have cleared it.
        XCTAssertEqual(currentUser.identityModel.externalId, userB_EUID)
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance._user?.identityModel.externalId, userB_EUID)
    }

    /**
     A Fetch User for the *current* user must still clear stale local data before hydrating from the
     response, so guarding against the race above does not regress the common path.
     */
    func testFetchUser_forCurrentUser_stillClearsStaleData() {
        /* Setup */
        let mocks = Mocks()
        let currentUser = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        // A stale local alias that is not present in the server response and should be cleared by the fetch.
        currentUser.identityModel.addAliases(["stale_label": "stale_value"])

        MockUserRequests.setDefaultFetchUserResponseForHydration(with: mocks.client, externalId: userA_EUID)

        /* When */
        mocks.userExecutor.fetchUser(aliasLabel: OS_ONESIGNAL_ID, aliasId: userA_OSID, identityModel: currentUser.identityModel, onNewSession: false)
        OneSignalCoreMocks.waitUntil("Current user fetch response was not applied") {
            currentUser.identityModel.aliases["stale_label"] == nil
                && currentUser.identityModel.externalId == userA_EUID
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        // clearUserData() ran for the current user: the stale alias is gone and server aliases are hydrated.
        XCTAssertNil(currentUser.identityModel.aliases["stale_label"])
        XCTAssertEqual(currentUser.identityModel.externalId, userA_EUID)
    }

    // MARK: - Identity Verification

    /// Cached Create User with no `external_id` must not go out once Identity Verification is required.
    func testAnonymousCachedCreateUserIsDroppedWhenIdentityVerificationIsRequired() {
        /* Setup */
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        cacheUserRequests([makeAnonymousCreateUserRequest()])

        /* When */
        let mocks = Mocks()
        allowAsyncWorkToRun()

        /* Then */
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    /// Same restored Create User goes out when Identity Verification is off.
    func testAnonymousCachedCreateUserIsSentWhenIdentityVerificationIsOff() {
        /* Setup */
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        cacheUserRequests([makeAnonymousCreateUserRequest()])

        /* When */
        let mocks = Mocks { MockUserRequests.setDefaultCreateAnonUserResponses(with: $0) }
        OneSignalCoreMocks.waitUntil("Create User was not sent") {
            mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self)
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    /// Nothing is sent while `requirement` is unknown; hydration releases the held Requests.
    func testRequestsAreHeldUntilTheRequirementIsKnown() {
        /* Setup */
        OSCoreMocks.resetSharedJwtConfig()
        let mocks = Mocks()
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID)

        /* When */
        mocks.userExecutor.createUser(mocks.createUserInstance(externalId: userA_EUID))
        allowAsyncWorkToRun()

        /* Then */
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))

        /* When the requirement arrives */
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalCoreMocks.waitUntil("Hydration did not release the held Create User") {
            mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self)
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    /// Identify User promotes an anonymous user, which Identity Verification does not allow. A restored one
    /// whose `identityModelToUpdate` is no longer current has no login left to carry over.
    func testRestoredIdentifyUserIsDroppedWhenIdentityVerificationIsRequired() {
        /* Setup */
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        cacheUserRequests([makeIdentifyUserRequest()])

        /* When */
        let mocks = Mocks { MockUserRequests.setDefaultIdentifyUserResponses(with: $0, externalId: userA_EUID, conflicted: false) }
        allowAsyncWorkToRun()

        /* Then */
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    /// Cold start: the anon `identityModelToIdentify` is gone from the repo, but ToUpdate is still the
    /// current user, so reshape must turn the restored Identify into a Create User.
    func testRestoredIdentifyUserBecomesACreateUserWhenItIsStillTheCurrentUser() {
        /* Setup */
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: nil)
        user.identityModel.jwtBearerToken = "token-a"
        cacheUserRequests([
            OSRequestIdentifyUser(
                aliasLabel: OS_EXTERNAL_ID,
                aliasId: userA_EUID,
                identityModelToIdentify: OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer()),
                identityModelToUpdate: user.identityModel
            )
        ])

        /* When */
        let mocks = Mocks { MockUserRequests.setDefaultCreateUserResponses(with: $0, externalId: userA_EUID) }
        OneSignalCoreMocks.waitUntil("Restored Identify was not reshaped into a Create User") {
            mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self)
        }

        /* Then */
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    /// Same restored Identify User goes out when Identity Verification is off.
    func testRestoredIdentifyUserIsSentWhenIdentityVerificationIsOff() {
        /* Setup */
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        cacheUserRequests([makeIdentifyUserRequest()])

        /* When */
        let mocks = Mocks { MockUserRequests.setDefaultIdentifyUserResponses(with: $0, externalId: userA_EUID, conflicted: false) }
        OneSignalCoreMocks.waitUntil("Restored Identify User was not sent") {
            mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self)
        }

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
    }

    /// `login` promotes while the requirement is still unknown, so turning out to require auth must not
    /// strand that login: it becomes the Create User it would have been.
    func testInSessionIdentifyUserBecomesACreateUserWhenIdentityVerificationIsRequired() {
        /* Setup */
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        let mocks = Mocks()
        MockUserRequests.setDefaultIdentifyUserResponses(with: mocks.client, externalId: userA_EUID, conflicted: false)
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID)

        let anonIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: nil)
        user.identityModel.jwtBearerToken = "token-a"

        /* When */
        mocks.userExecutor.identifyUser(externalId: userA_EUID, identityModelToIdentify: anonIdentityModel, identityModelToUpdate: user.identityModel)
        OneSignalCoreMocks.waitUntil("In-session Identify was not reshaped into a Create User") {
            mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self)
        }

        /* Then */
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    /// A promotion whose user a later `login` has already replaced has no login left to carry over.
    func testInSessionIdentifyUserForAReplacedUserIsDroppedWhenIdentityVerificationIsRequired() {
        /* Setup */
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        let mocks = Mocks()
        MockUserRequests.setDefaultIdentifyUserResponses(with: mocks.client, externalId: userA_EUID, conflicted: false)

        let anonIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        let replacedIdentityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: nil)

        /* When */
        mocks.userExecutor.identifyUser(externalId: userA_EUID, identityModelToIdentify: anonIdentityModel, identityModelToUpdate: replacedIdentityModel)
        allowAsyncWorkToRun()

        /* Then */
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    private func cacheUserRequests(_ requests: [OSUserRequest]) {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, withValue: requests)
    }

    private func makeIdentifyUserRequest() -> OSRequestIdentifyUser {
        return OSRequestIdentifyUser(
            aliasLabel: OS_EXTERNAL_ID,
            aliasId: userA_EUID,
            identityModelToIdentify: OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer()),
            identityModelToUpdate: OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        )
    }

    private func makeAnonymousCreateUserRequest() -> OSRequestCreateUser {
        let pushModel = OSSubscriptionModel(type: .push, address: nil, subscriptionId: nil, reachable: false, isDisabled: false, changeNotifier: OSEventProducer())
        return OSRequestCreateUser(
            identityModel: OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer()),
            propertiesModel: OSPropertiesModel(changeNotifier: OSEventProducer()),
            pushSubscriptionModel: pushModel,
            originalPushToken: nil
        )
    }
}
