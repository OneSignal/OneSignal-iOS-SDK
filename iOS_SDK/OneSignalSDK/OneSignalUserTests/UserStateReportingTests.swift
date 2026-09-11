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
    var states: [OSUserState] = []

    func onUserStateDidChange(state: OSUserChangedState) {
        states.append(state.current)
    }
}

/**
 What the app's `OSUserStateObserver` hears, and what the persisted snapshot names, once a Request can
 complete for a user who is no longer current.
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
        OneSignalCoreMocks.waitUntil("A Request was still in flight at teardown") { self.clientIsIdle }
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
        OneSignalCoreMocks.waitUntil("A's Create User was still in flight") { self.clientIsIdle }
        allowAsyncWorkToRun(seconds: 0.1)

        // Hydrated, so anything queued for A has its onesignal_id.
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.identityModelRepo.get(externalId: userA_EUID)?.onesignalId, userA_OSID)
        // Not reported: the app hears nothing new, and the persisted pair still names B.
        XCTAssertEqual(observer.states.count, reportsBeforeA, "the app must not hear about A: \(observer.states)")
        XCTAssertEqual(observer.states.last?.externalId, userB_EUID)
        XCTAssertEqual(OneSignalUserDefaults.initShared().getSavedString(forKey: OS_SNAPSHOT_EXTERNAL_ID, defaultValue: nil), userB_EUID)
        XCTAssertEqual(OneSignalUserDefaults.initShared().getSavedString(forKey: OS_SNAPSHOT_ONESIGNAL_ID, defaultValue: nil), userB_OSID)
    }

    // MARK: - Waits

    private var clientIsIdle: Bool {
        return client.completedRequests.count == client.startedRequests.count
    }

    /**
     Outlasts every effect of an identified login, including the Fetch User its Create User starts. A
     fetch landing later would re-report the current user and hide a wrong report made in between.
     */
    private func waitForTheLoginToSettle() {
        OneSignalCoreMocks.waitUntil("The login did not reach a reported user") {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.onesignalId != nil
                && self.observer.states.contains { $0.onesignalId != nil }
                && self.client.hasCompletedRequestOfType(OSRequestFetchUser.self)
                && self.clientIsIdle
        }
        allowAsyncWorkToRun(seconds: 0.1)
        OneSignalCoreMocks.waitUntil("The login left a Request in flight") { self.clientIsIdle }
    }
}
