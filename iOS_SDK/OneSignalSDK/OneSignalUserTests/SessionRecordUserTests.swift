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

final class SessionRecordUserTests: XCTestCase {
    private var client = MockOneSignalClient()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OSSessionService.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userA_EUID)
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userB_EUID)
        OneSignalCoreImpl.setSharedClient(client)
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.waitUntil("A Request was still in flight at teardown") { self.client.isIdle }
        // A polled session executor re-caches its queue, which the next test's executor would uncache.
        let manager = OneSignalUserManagerImpl.sharedInstance
        manager.operationRepo.reset()
        _ = manager.sessionExecutor?.queuedRequests
        OSSessionService.reset()
        OneSignalCoreMocks.clearUserDefaults()
        OSFeatureFlagsStore.shared.clear()
        OSFeatureManager.reset()
    }

    func testSessionStartedBeforeUserIsCreatedPinsItsIdsOnceCreated() {
        OneSignalUserManagerImpl.sharedInstance.startNewSession()

        OneSignalCoreMocks.waitUntil("Session did not pin the created user's IDs") {
            let record = OSSessionService.shared.currentRecord
            return record?.onesignalId == anonUserOSID && record?.subscriptionId == testPushSubId
        }
    }

    func testPinnedIdsStayTheSameAfterLoginsWithinASession() {
        OneSignalUserManagerImpl.sharedInstance.startNewSession()
        OneSignalCoreMocks.waitUntil("Anonymous user was not created") {
            let record = OSSessionService.shared.currentRecord
            return record?.onesignalId == anonUserOSID && record?.subscriptionId == testPushSubId
        }
        let pinned = OSSessionService.shared.currentRecord

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)
        OneSignalCoreMocks.waitUntil("User B was not created") {
            OneSignalUserManagerImpl.sharedInstance.onesignalId == userB_OSID
        }

        let record = OSSessionService.shared.currentRecord
        XCTAssertEqual(record?.sessionId, pinned?.sessionId)
        XCTAssertEqual(record?.onesignalId, anonUserOSID)
        XCTAssertEqual(record?.subscriptionId, pinned?.subscriptionId)
    }

    /// Reading the record fills it, so this waits on the User module instead and reads only at the end.
    func testIdsAssignedBeforeALoginArePinnedWithoutTheRecordBeingRead() {
        OneSignalUserManagerImpl.sharedInstance.startNewSession()
        OneSignalCoreMocks.waitUntil("Anonymous user was not created") {
            OneSignalUserManagerImpl.sharedInstance.onesignalId == anonUserOSID
                && OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId == testPushSubId
        }

        // An existing external ID: Identify User conflicts, and a new user is created for it.
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userB_EUID, conflicted: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)
        OneSignalCoreMocks.waitUntil("User B was not created") {
            OneSignalUserManagerImpl.sharedInstance.onesignalId == userB_OSID
        }

        let record = OSSessionService.shared.currentRecord
        XCTAssertEqual(record?.onesignalId, anonUserOSID)
        XCTAssertEqual(record?.subscriptionId, testPushSubId)
    }

    /// A new install that logs in to an existing user before its anonymous user is created.
    func testLoginConflictBeforeTheAnonymousUserIsCreatedStillFillsTheSession() {
        client.holdResponses = true
        OneSignalUserManagerImpl.sharedInstance.startNewSession()
        OneSignalCoreMocks.waitUntil("Create User was not sent") {
            self.client.startedRequestCount(ofType: OSRequestCreateUser.self) == 1
        }

        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userB_EUID, conflicted: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)
        client.releaseHeldResponses()
        OneSignalCoreMocks.waitUntil("User B was not created") {
            OneSignalUserManagerImpl.sharedInstance.onesignalId == userB_OSID
        }

        let record = OSSessionService.shared.currentRecord
        XCTAssertEqual(record?.onesignalId, anonUserOSID)
        XCTAssertEqual(record?.subscriptionId, testPushSubId)
    }

    /// The last process started a session and was killed before its anonymous user was created.
    func testRecordFromThePreviousProcessIsFilledInOnceTheUserIsCreated() {
        let manager = OneSignalUserManagerImpl.sharedInstance
        manager.setNewInternalUser(externalId: nil, pushSubscriptionModel: nil)
        OSSessionService.shared.startNewSession(userProvider: manager)
        OSSessionService.reset()

        manager.start()

        OneSignalCoreMocks.waitUntil("Session record was not filled in") {
            let record = OSSessionService.shared.currentRecord
            return record?.onesignalId == anonUserOSID && record?.subscriptionId == testPushSubId
        }
    }

    func testNewSessionAfterLoginPinsTheNewUser() {
        OneSignalUserManagerImpl.sharedInstance.startNewSession()
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)
        OneSignalCoreMocks.waitUntil("User B was not created") {
            OneSignalUserManagerImpl.sharedInstance.onesignalId == userB_OSID
        }

        OneSignalUserManagerImpl.sharedInstance.startNewSession()

        XCTAssertEqual(OSSessionService.shared.currentRecord?.onesignalId, userB_OSID)
    }
}

// MARK: - Session create

extension SessionRecordUserTests {
    private func enableSessionsApi() {
        OSFeatureFlagsStore.shared.applyRemoteFlags(["sdk_sessions_v2_api_cutover"], metadata: nil)
    }

    /// With responses held the user is never created, so its session creates stay queued.
    private func queuedSessionCreates() -> [OSRequestCreateSession] {
        let manager = OneSignalUserManagerImpl.sharedInstance
        manager.operationRepo.flushAndWait()
        return manager.sessionExecutor?.queuedRequests.compactMap { $0 as? OSRequestCreateSession } ?? []
    }

    func testNewSessionQueuesACreateWithItsStartTime() {
        enableSessionsApi()
        client.holdResponses = true

        OneSignalUserManagerImpl.sharedInstance.startNewSession()

        let record = OSSessionService.shared.currentRecord
        let creates = queuedSessionCreates()
        XCTAssertEqual(creates.count, 1)
        XCTAssertEqual(creates.first?.localSessionId, record?.sessionId)
        XCTAssertEqual(creates.first?.startTime.timeIntervalSince1970, record?.startTime)
        client.releaseHeldResponses()
    }

    func testEachNewSessionQueuesItsOwnCreate() {
        enableSessionsApi()
        client.holdResponses = true

        OneSignalUserManagerImpl.sharedInstance.startNewSession()
        let first = OSSessionService.shared.currentRecord?.sessionId
        OneSignalUserManagerImpl.sharedInstance.startNewSession()
        let second = OSSessionService.shared.currentRecord?.sessionId

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(queuedSessionCreates().map(\.localSessionId), [first, second].compactMap { $0 })
        client.releaseHeldResponses()
    }

    private func queuedSessionUpdates() -> [OSRequestUpdateSession] {
        let queued = OneSignalUserManagerImpl.sharedInstance.sessionExecutor?.queuedRequests ?? []
        return queued.compactMap { $0 as? OSRequestUpdateSession }
    }

    func testNewSessionQueuesThePreviousSessionsEndBeforeItsCreate() {
        enableSessionsApi()
        client.holdResponses = true
        let manager = OneSignalUserManagerImpl.sharedInstance

        manager.startNewSession()
        let first = OSSessionService.shared.currentRecord
        manager.startNewSession()
        let second = OSSessionService.shared.currentRecord

        let creates = queuedSessionCreates()
        let queued = manager.sessionExecutor?.queuedRequests.map(\.localSessionId)
        XCTAssertEqual(queued, [first?.sessionId, first?.sessionId, second?.sessionId].compactMap { $0 })
        XCTAssertEqual(creates.count, 2)
        let end = queuedSessionUpdates().first
        XCTAssertEqual(end?.localSessionId, first?.sessionId)
        XCTAssertEqual(end?.endTime?.timeIntervalSince1970, first?.startTime)
        client.releaseHeldResponses()
    }

    func testLegacySessionQueuesNoEnd() {
        client.holdResponses = true
        let manager = OneSignalUserManagerImpl.sharedInstance

        manager.startNewSession()
        enableSessionsApi()
        manager.startNewSession()

        XCTAssertEqual(queuedSessionCreates().count, 1)
        XCTAssertTrue(queuedSessionUpdates().isEmpty)
        client.releaseHeldResponses()
    }

    /// The session's user was replaced by a login in an earlier process, so its model is not loaded.
    func testEndOfASessionWhoseUserIsNoLongerLoadedIsQueuedForItsPinnedUser() throws {
        let manager = OneSignalUserManagerImpl.sharedInstance
        let record = { (onesignalId: String?) in
            OSSessionRecord(
                sessionId: onesignalId ?? "never-created",
                startTime: 1_700_000_000,
                activeDuration: 12,
                usesSessionsApi: true,
                identityModelId: "unloaded-model",
                onesignalId: onesignalId,
                subscriptionId: nil
            )
        }

        manager.enqueueSessionUpdate(record("pinned-onesignal-id"), endTime: Date(timeIntervalSince1970: 1_700_000_100))
        manager.enqueueSessionUpdate(record(nil), endTime: Date(timeIntervalSince1970: 1_700_000_100))
        manager.operationRepo.dispatchQueue.sync {}

        let sessionDeltas = manager.operationRepo.deltaQueue.filter { $0.name == OS_UPDATE_SESSION_DELTA }
        XCTAssertEqual(sessionDeltas.map(\.property), ["pinned-onesignal-id"])
        let identityModel = try XCTUnwrap(manager.getIdentityModel(sessionDeltas[0].identityModelId))
        XCTAssertEqual(identityModel.onesignalId, "pinned-onesignal-id")
    }

    func testNewSessionQueuesNoCreateWhenTheFlagIsOff() {
        client.holdResponses = true

        OneSignalUserManagerImpl.sharedInstance.startNewSession()

        XCTAssertTrue(queuedSessionCreates().isEmpty)
        client.releaseHeldResponses()
    }
}
