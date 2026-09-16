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
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalOSCore
@testable import OneSignalUser

private class MockUserStateObserver: NSObject, OSUserStateObserver {
    private let lock = NSLock()
    private var reported: [OSUserState] = []

    /// Read on the test thread while the SDK reports from its response threads.
    var states: [OSUserState] {
        return lock.withLock { reported }
    }

    func onUserStateDidChange(state: OSUserChangedState) {
        lock.withLock { reported.append(state.current) }
    }
}

/**
 What the app's `OSUserStateObserver` hears, and what the persisted snapshot names, once a Request can
 complete for a user who is no longer current. One case per executor site that hydrates an identity
 model: Create User, Identify User, and Fetch Identity By Subscription.
 */
final class UserStateReportingTests: XCTestCase {
    private var client = MockOneSignalClient()
    private var observer = MockUserStateObserver()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userA_EUID)
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userB_EUID)
        OneSignalCoreImpl.setSharedClient(client)

        // Held strongly for the test's lifetime: OSObservable keeps observers weakly.
        observer = MockUserStateObserver()
        OneSignalUserManagerImpl.sharedInstance.addObserver(observer)
    }

    override func tearDownWithError() throws {
        // A Request still in flight would land mid-next-test and hydrate the shared models under it.
        OneSignalCoreMocks.waitUntil("A Request was still in flight at teardown") { self.client.isIdle }
        OneSignalUserManagerImpl.sharedInstance.removeObserver(observer)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = false
        OneSignalCoreMocks.clearUserDefaults()
    }

    /**
     Stepping over a parked Create User lets a later login proceed, so the parked one can complete after
     another user is current. Its model still hydrates, since Requests queued behind it need the
     `onesignal_id`, but the app has to keep hearing the current user, and the persisted pair has to keep
     naming the current user, or the app is told the wrong user is signed in.
     */
    func testAParkedCreateUserThatCompletesAfterAUserSwitchDoesNotReportThatUser() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)

        // Parks for want of a token, which asks the app.
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        allowAsyncWorkToRun()
        // Steps over the parked Create User and becomes the current, reported user.
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: "token-b")
        waitForTheLoginToSettle()
        XCTAssertEqual(observer.states.last?.externalId, userB_EUID)
        let reportsBeforeA = observer.states.count

        // Answers the ask, so A's Create User goes out while B is current.
        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitUntil("A's parked Create User was not sent") {
            self.client.executedRequests.contains { ($0 as? OSRequestCreateUser)?.identityModel.externalId == userA_EUID }
        }
        // Settled once idle: the report decision is made inside the response block, and the mock records
        // a request as completed only after that block returns. The pause just lets the executor queue
        // drain what the response dispatched before teardown.
        OneSignalCoreMocks.waitUntil("A's Create User was still in flight") { self.client.isIdle }
        allowAsyncWorkToRun(seconds: 0.1)

        // Hydrated, so anything queued for A has its onesignal_id.
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.identityModelRepo.get(externalId: userA_EUID)?.onesignalId, userA_OSID)
        // Not reported: the app hears nothing new, and the persisted pair still names B.
        XCTAssertEqual(observer.states.count, reportsBeforeA, "the app must not hear about A: \(observer.states)")
        XCTAssertEqual(observer.states.last?.externalId, userB_EUID)
        assertPersistedSnapshotNames(externalId: userB_EUID, onesignalId: userB_OSID)
    }

    /**
     Needs no Identity Verification. A `login` while anonymous identifies that user, and a second `login`
     before the response lands makes another user current. The Identify User still hydrates the first
     user's model, since Requests queued behind it read the `onesignal_id`, but the app must not hear a
     user it has already switched away from.
     */
    func testAnIdentifyUserThatCompletesAfterAUserSwitchDoesNotReportThatUser() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userA_EUID)
        // The anonymous user needs its onesignal_id first, or the Identify User cannot address it.
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitUntil("The anonymous user was not created") {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.onesignalId == anonUserOSID && self.client.isIdle
        }

        client.holdResponses = true
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitUntil("The Identify User was not started") {
            self.client.startedRequestCount(ofType: OSRequestIdentifyUser.self) == 1
        }
        // Makes B current while A's Identify User is still in flight; B's Create User queues behind it.
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)
        client.releaseHeldResponses()
        waitForTheLoginToSettle()

        // Hydrated, so anything queued for A has its onesignal_id.
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.identityModelRepo.get(externalId: userA_EUID)?.onesignalId, anonUserOSID)
        XCTAssertFalse(observer.states.contains { $0.externalId == userA_EUID }, "the app must not hear about A: \(observer.states)")
        XCTAssertEqual(observer.states.last?.externalId, userB_EUID)
        assertPersistedSnapshotNames(externalId: userB_EUID, onesignalId: userB_OSID)
    }

    /**
     The 3.x upgrade path, again with no Identity Verification. The fetch identifies an anonymous user,
     and a `login` that lands before its response makes an identified user current. The fetch still
     hydrates the anonymous model, which the Identify User queued behind it needs, but the app must not
     hear an anonymous user it has already logged in over.
     */
    func testAFetchIdentityBySubscriptionThatCompletesAfterALoginDoesNotReportTheAnonymousUser() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        let legacyPlayerId = "legacy_player_id"
        let legacyOnesignalId = "legacy_player_onesignal_id"
        OneSignalUserDefaults.initShared().saveString(forKey: OSUD_LEGACY_PLAYER_ID, withValue: legacyPlayerId)
        client.setMockResponseForRequest(
            request: "OSRequestFetchIdentityBySubscription with subscriptionId: \(legacyPlayerId)",
            response: MockUserRequests.testIdentityPayload(onesignalId: legacyOnesignalId, externalId: nil)
        )
        client.setMockResponseForRequest(
            request: "<OSRequestIdentifyUser with external_id: \(userA_EUID)>",
            response: MockUserRequests.testIdentityPayload(onesignalId: legacyOnesignalId, externalId: userA_EUID)
        )
        client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with onesignal_id: \(legacyOnesignalId)>",
            response: MockUserRequests.testIdentityPayload(onesignalId: legacyOnesignalId, externalId: userA_EUID)
        )
        client.holdResponses = true

        // Migrates the legacy player into an anonymous user whose identity the held fetch supplies.
        OneSignalUserManagerImpl.sharedInstance.start()
        let anonymousModel = OneSignalUserManagerImpl.sharedInstance.user.identityModel
        XCTAssertNil(anonymousModel.onesignalId)
        OneSignalCoreMocks.waitUntil("The Fetch Identity By Subscription was not started") {
            self.client.startedRequestCount(ofType: OSRequestFetchIdentityBySubscription.self) == 1
        }
        // Makes A current while the anonymous user's fetch is still in flight; A's Identify User queues behind it.
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        client.releaseHeldResponses()
        waitForTheLoginToSettle()

        // Hydrated, so the Identify User behind the fetch could address the anonymous user.
        XCTAssertEqual(anonymousModel.onesignalId, legacyOnesignalId)
        XCTAssertFalse(observer.states.contains { $0.externalId == nil }, "the app must not hear the anonymous user: \(observer.states)")
        XCTAssertEqual(observer.states.last?.externalId, userA_EUID)
        assertPersistedSnapshotNames(externalId: userA_EUID, onesignalId: legacyOnesignalId)
    }

    // MARK: - Helpers

    private func assertPersistedSnapshotNames(
        externalId: String, onesignalId: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let defaults = OneSignalUserDefaults.initShared()
        XCTAssertEqual(defaults.getSavedString(forKey: OS_SNAPSHOT_EXTERNAL_ID, defaultValue: nil), externalId, file: file, line: line)
        XCTAssertEqual(defaults.getSavedString(forKey: OS_SNAPSHOT_ONESIGNAL_ID, defaultValue: nil), onesignalId, file: file, line: line)
    }

    /**
     Outlasts every effect of an identified login, including the Fetch User its Create User or Identify
     User starts. A fetch landing later would re-report the current user and hide a wrong report made in
     between.
     */
    private func waitForTheLoginToSettle() {
        OneSignalCoreMocks.waitUntil("The login did not reach a reported user") {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.onesignalId != nil
                && self.observer.states.contains { $0.onesignalId != nil }
                && self.client.hasCompletedRequestOfType(OSRequestFetchUser.self)
                && self.client.isIdle
        }
        allowAsyncWorkToRun(seconds: 0.1)
        OneSignalCoreMocks.waitUntil("The login left a Request in flight") { self.client.isIdle }
    }
}
