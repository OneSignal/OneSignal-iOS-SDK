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

private class Mocks: OneSignalExecutorMocks {
    var userExecutor: OSUserExecutor!

    override init() {
        super.init()
        userExecutor = OSUserExecutor(newRecordsState: newRecordsState, jwtConfig: jwtConfig)
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
        mocks.setAuthRequired(false)
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
        mocks.setAuthRequired(false)
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
        mocks.setAuthRequired(false)
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
        mocks.setAuthRequired(false)
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
        mocks.setAuthRequired(false)
        let user = mocks.setUserManagerInternalUser(externalId: userB_EUID)

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
        mocks.setAuthRequired(false)

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

    func testCreateUser_IdentityVerificationRequired_butNoToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        _ = mocks.setUserManagerInternalUser(externalId: "")
        let newIdentityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID)

        /* When */
        mocks.userExecutor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userA_EUID, identityModel: newIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should not execute this request since identity verification is required, but no token was set
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
        XCTAssertEqual(mocks.newRecordsState.records.count, 0)
    }

    func testCreateUser_IdentityVerificationRequired_withToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        _ = mocks.setUserManagerInternalUser(externalId: "")
        let newIdentityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        newIdentityModel.jwtBearerToken = userA_InvalidJwtToken
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID)

        /* When */
        mocks.userExecutor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userA_EUID, identityModel: newIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should execute this request since identity verification is required and the token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    func testCreateUser_IdentityVerificationRequired_withInvalidToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        _ = mocks.setUserManagerInternalUser(externalId: userA_EUID)
        let newIdentityModel = OSIdentityModel(aliases: [OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        newIdentityModel.jwtBearerToken = userA_InvalidJwtToken
        MockUserRequests.setUnauthorizedCreateUserFailureResponses(with: mocks.client, externalId: userA_EUID)

        let userJwtInvalidatedListener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(userJwtInvalidatedListener)

        /* When */
        mocks.userExecutor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userA_EUID, identityModel: newIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should execute this request since identity verification is required and the token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
        XCTAssertTrue(userJwtInvalidatedListener.invalidatedCallbackWasCalled)
    }

    func testFetchUser_IdentityVerificationRequired_butNoToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        _ = mocks.setUserManagerInternalUser(externalId: "")
        let newIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID], changeNotifier: OSEventProducer())
        MockUserRequests.setDefaultFetchUserResponseForHydration(with: mocks.client, externalId: userA_EUID)

        /* When */
        mocks.userExecutor.fetchUser(onesignalId: userA_OSID, identityModel: newIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should not execute this request since identity verification is required, but no token was set
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
    }

    func testFetchUser_IdentityVerificationRequired_withToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        _ = mocks.setUserManagerInternalUser(externalId: "")
        let newIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID, OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        newIdentityModel.jwtBearerToken = userA_InvalidJwtToken
        MockUserRequests.setDefaultFetchUserResponseForHydration(with: mocks.client, externalId: userA_EUID)

        /* When */
        mocks.userExecutor.fetchUser(onesignalId: userA_OSID, identityModel: newIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should not execute this request since identity verification is required, but no token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
    }

    func testFetchUser_IdentityVerificationRequired_withInvalidToken() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        _ = mocks.setUserManagerInternalUser(externalId: userA_EUID)
        let newIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID, OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        newIdentityModel.jwtBearerToken = userA_InvalidJwtToken
        MockUserRequests.setUnauthorizedFetchUserFailureResponses(with: mocks.client, onesignalId: userA_OSID)

        let userJwtInvalidatedListener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(userJwtInvalidatedListener)

        /* When */
        mocks.userExecutor.fetchUser(onesignalId: userA_OSID, identityModel: newIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should execute this request since identity verification is required and the token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        XCTAssertTrue(userJwtInvalidatedListener.invalidatedCallbackWasCalled)
    }

    func testUserRequests_Retry_OnTokenUpdate() {
        /* Setup */
        let mocks = Mocks()

        mocks.setAuthRequired(true)

        _ = mocks.setUserManagerInternalUser(externalId: userA_EUID)
        // We need to use the user manager's executor because the onJWTUpdated callback won't fire on the mock executor.
        // start() initializes sharedInstance.userExecutor and subscribes it as a JWT listener.
        OneSignalUserManagerImpl.sharedInstance.start()
        let executor = OneSignalUserManagerImpl.sharedInstance.userExecutor!

        let userAIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID, OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        userAIdentityModel.jwtBearerToken = userA_InvalidJwtToken

        MockUserRequests.setUnauthorizedFetchUserFailureResponses(with: mocks.client, onesignalId: userA_OSID)

        let userJwtInvalidatedListener = MockUserJwtInvalidatedListener()
        userJwtInvalidatedListener.setCallback {
            MockUserRequests.setDefaultFetchUserResponseForHydration(with: mocks.client, externalId: userA_EUID)
            OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: userA_ValidJwtToken)
        }
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(userJwtInvalidatedListener)

        /* When */
        executor.fetchUser(onesignalId: userA_OSID, identityModel: userAIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 1)

        /* Then */
        // The executor should execute this request since identity verification is required and the token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        XCTAssertTrue(userJwtInvalidatedListener.invalidatedCallbackWasCalled)
        // >= because start() may fire incidental requests (e.g. language update from _user?.update())
        XCTAssertGreaterThanOrEqual(mocks.client.networkRequestCount, 2)
    }

    func testUserRequests_RetryAllRequests_OnTokenUpdate() {
        /* Setup */
        let mocks = Mocks()

        mocks.setAuthRequired(true)

        let userA = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        // We need to use the user manager's executor because the onJWTUpdated callback won't fire on the mock executor.
        // start() initializes sharedInstance.userExecutor and subscribes it as a JWT listener.
        OneSignalUserManagerImpl.sharedInstance.start()
        let executor = OneSignalUserManagerImpl.sharedInstance.userExecutor!

        userA.identityModel.jwtBearerToken = userA_InvalidJwtToken

        MockUserRequests.setUnauthorizedFetchUserFailureResponses(with: mocks.client, onesignalId: userA_OSID)
        MockUserRequests.setUnauthorizedCreateUserFailureResponses(with: mocks.client, externalId: userA_EUID)

        let userJwtInvalidatedListener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(userJwtInvalidatedListener)

        /* When */
        executor.fetchUser(onesignalId: userA_OSID, identityModel: userA.identityModel)
        executor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userA_EUID, identityModel: userA.identityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        MockUserRequests.setDefaultFetchUserResponseForHydration(with: mocks.client, externalId: userA_EUID)
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userA_EUID)

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: userA_ValidJwtToken)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should execute this request since identity verification is required and the token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestCreateUser.self))
        XCTAssertTrue(userJwtInvalidatedListener.invalidatedCallbackWasCalled)
        /*
         Create and Fetch requests that fail
         Create and Fetch requests that pass
         Follow up Fetch made after the success of the Create request
         */
        // >= because start() may fire incidental requests (e.g. language update from _user?.update())
        XCTAssertGreaterThanOrEqual(mocks.client.networkRequestCount, 5)
    }

    /**
     This test executes a Fetch on userA, and a Create on userB, encountering an unauthorized response for both requests.
     The test next updates the JWT token for userA only.
     It expects only the Fetch userA request to be sent next.
     */
    func testUserRequests_RetryRequests_OnTokenUpdate_ForOnlyUpdatedUser() {
        /* Setup */
        let mocks = Mocks()

        mocks.setAuthRequired(true)

        let userA = mocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        // We need to use the user manager's executor because the onJWTUpdated callback won't fire on the mock executor.
        // start() initializes sharedInstance.userExecutor and subscribes it as a JWT listener.
        OneSignalUserManagerImpl.sharedInstance.start()
        let executor = OneSignalUserManagerImpl.sharedInstance.userExecutor!

        userA.identityModel.jwtBearerToken = userA_InvalidJwtToken

        let userBIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userB_OSID, OS_EXTERNAL_ID: userB_EUID], changeNotifier: OSEventProducer())
        userBIdentityModel.jwtBearerToken = userA_InvalidJwtToken
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(userBIdentityModel)

        MockUserRequests.setUnauthorizedFetchUserFailureResponses(with: mocks.client, onesignalId: userA_OSID)
        MockUserRequests.setUnauthorizedCreateUserFailureResponses(with: mocks.client, externalId: userB_EUID)

        let userJwtInvalidatedListener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(userJwtInvalidatedListener)

        /* When */
        executor.fetchUser(onesignalId: userA_OSID, identityModel: userA.identityModel)
        executor.createUser(aliasLabel: OS_EXTERNAL_ID, aliasId: userB_EUID, identityModel: userBIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        MockUserRequests.setDefaultFetchUserResponseForHydration(with: mocks.client, externalId: userA_EUID)
        MockUserRequests.setDefaultCreateUserResponses(with: mocks.client, externalId: userB_EUID)

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: userA_ValidJwtToken)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */
        // The executor should execute this request since identity verification is required and the token was set
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        XCTAssertTrue(userJwtInvalidatedListener.invalidatedCallbackWasCalled)
        // >= because start() may fire incidental requests (e.g. language update from _user?.update())
        XCTAssertGreaterThanOrEqual(mocks.client.networkRequestCount, 3)
    }

    /// When Identity Verification is turned off, requests parked awaiting a JWT must be released
    /// and sent without a token (no JWT will ever arrive once auth is off).
    func testReleasePendingRequests_OnIdentityVerificationTurnedOff() {
        /* Setup */
        let mocks = Mocks()
        mocks.setAuthRequired(true)

        _ = mocks.setUserManagerInternalUser(externalId: userA_EUID)
        // start() initializes sharedInstance.userExecutor and subscribes it as a JWT listener.
        OneSignalUserManagerImpl.sharedInstance.start()
        let executor = OneSignalUserManagerImpl.sharedInstance.userExecutor!

        // No JWT token, so the Fetch User request is parked awaiting a JWT while IV is on.
        let newIdentityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: userA_OSID, OS_EXTERNAL_ID: userA_EUID], changeNotifier: OSEventProducer())
        MockUserRequests.setDefaultFetchUserResponseForHydration(with: mocks.client, externalId: userA_EUID)

        let userJwtInvalidatedListener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(userJwtInvalidatedListener)

        /* When: the request is parked because no token is present */
        executor.fetchUser(onesignalId: userA_OSID, identityModel: newIdentityModel)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        XCTAssertFalse(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))

        /* When: Identity Verification is turned off */
        mocks.setAuthRequired(false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then: the parked request is released and sent, with no JWT invalidation */
        XCTAssertTrue(mocks.client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        XCTAssertFalse(userJwtInvalidatedListener.invalidatedCallbackWasCalled)
    }

    // MARK: - Identity Verification config: a missing remote-params field always means off

    /// The regression: a previously-ON app must turn OFF when remote params omit jwt_required.
    func testRemoteParamsMissingJwtRequired_TurnsOff_WhenPreviouslyOn() {
        /* Setup */
        OneSignalUserManagerImpl.sharedInstance.setRequiresUserAuth(true)
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.jwtConfig.isRequired, true)

        let listener = MockJwtConfigListener()
        OneSignalUserManagerImpl.sharedInstance.subscribeToJwtConfig(listener, key: "test_iv_off_previously_on")

        /* When: remote params come back without the jwt_required field */
        OneSignalUserManagerImpl.sharedInstance.remoteParamsReturnedUnknownRequiresUserAuth()

        /* Then: it flips to off and fires the transition exactly once */
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.jwtConfig.isRequired, false)
        XCTAssertEqual(listener.changes.count, 1)
        XCTAssertEqual(listener.changes.first?.from, OSRequiresUserAuth.on)
        XCTAssertEqual(listener.changes.first?.to, OSRequiresUserAuth.off)
    }

    /// An unknown (never-set) status resolves to off when remote params omit jwt_required.
    func testRemoteParamsMissingJwtRequired_TurnsOff_WhenPreviouslyUnknown() {
        /* Setup */
        OneSignalUserManagerImpl.sharedInstance.jwtConfig.isRequired = nil // force unknown
        XCTAssertNil(OneSignalUserManagerImpl.sharedInstance.jwtConfig.isRequired)

        let listener = MockJwtConfigListener()
        OneSignalUserManagerImpl.sharedInstance.subscribeToJwtConfig(listener, key: "test_iv_off_previously_unknown")

        /* When */
        OneSignalUserManagerImpl.sharedInstance.remoteParamsReturnedUnknownRequiresUserAuth()

        /* Then */
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.jwtConfig.isRequired, false)
        XCTAssertEqual(listener.changes.count, 1)
        XCTAssertEqual(listener.changes.first?.from, OSRequiresUserAuth.unknown)
        XCTAssertEqual(listener.changes.first?.to, OSRequiresUserAuth.off)
    }

    /// Re-confirming an already-off status must not re-fire listeners (didSet equality guard).
    func testRemoteParamsMissingJwtRequired_DoesNotRefire_WhenAlreadyOff() {
        /* Setup */
        OneSignalUserManagerImpl.sharedInstance.setRequiresUserAuth(false)
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.jwtConfig.isRequired, false)

        let listener = MockJwtConfigListener()
        OneSignalUserManagerImpl.sharedInstance.subscribeToJwtConfig(listener, key: "test_iv_off_already_off")

        /* When */
        OneSignalUserManagerImpl.sharedInstance.remoteParamsReturnedUnknownRequiresUserAuth()

        /* Then: value unchanged, no transition fired */
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.jwtConfig.isRequired, false)
        XCTAssertEqual(listener.changes.count, 0)
    }
}

private class MockJwtConfigListener: NSObject, OSUserJwtConfigListener {
    var changes: [(from: OSRequiresUserAuth, to: OSRequiresUserAuth)] = []
    var jwtUpdateCount = 0

    func onRequiresUserAuthChanged(from: OSRequiresUserAuth, to: OSRequiresUserAuth) {
        changes.append((from: from, to: to))
    }

    func onJwtUpdated(externalId: String, token: String?) {
        jwtUpdateCount += 1
    }
}
