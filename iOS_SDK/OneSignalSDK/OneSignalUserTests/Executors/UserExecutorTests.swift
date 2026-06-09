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

    init() {
        OneSignalCoreImpl.setSharedClient(client)
        userExecutor = OSUserExecutor(newRecordsState: newRecordsState)
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

        /* When */
        mocks.userExecutor.createUser(mocks.createUserInstance(externalId: userA_EUID))
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.newRecordsState.contains(userA_OSID))
        XCTAssertTrue(mocks.newRecordsState.contains("push-sub-id"))
    }

    func testCreateUser_withoutPushSubscription_doesNot_addToNewRecords() {
        /* Setup */
        let mocks = Mocks()
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID)

        /* When */
        let identityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        mocks.userExecutor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userA_EUID, identityModel: identityModel)

        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

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
        let newIdentityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())

        // The current user needs to be the same, set it in the user manager
        OneSignalUserManagerImpl.sharedInstance.identityModelStore.add(id: OS_IDENTITY_MODEL_KEY, model: newIdentityModel, hydrating: false)
        mocks.userExecutor.identifyUser(externalId: userA_EUID, identityModelToIdentify: anonIdentityModel, identityModelToUpdate: newIdentityModel)

        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

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
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

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
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

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

        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

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
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        // The current user's external_id must be intact — the stale fetch must not have cleared it.
        XCTAssertEqual(currentUser.identityModel.externalId, userB_EUID)
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance._user?.identityModel.externalId, userB_EUID)
    }

    /**
     The normal new-session Fetch User for the *current* user must still clear stale local data before hydrating
     from the response, so the `isCurrentUser` guard added for the race above does not regress the common path.
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
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        // clearUserData() ran for the current user: the stale alias is gone and server aliases are hydrated.
        XCTAssertNil(currentUser.identityModel.aliases["stale_label"])
        XCTAssertEqual(currentUser.identityModel.externalId, userA_EUID)
    }
}
