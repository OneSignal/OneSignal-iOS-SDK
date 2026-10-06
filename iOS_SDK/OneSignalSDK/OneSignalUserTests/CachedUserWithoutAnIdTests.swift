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

/**
 A cached user with no `onesignal_id` was never created on the server. Only its Create User does that, and a
 launch can lose the Request: the queue it sat in was dropped as oversized or unreadable, or a 5.3.0-beta build
 parked it under a key `start()` removes. `start()` queues it again rather than leave the device unreachable.
 */
final class CachedUserWithoutAnIdTests: XCTestCase {
    private var client = MockOneSignalClient()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userA_EUID)
        OneSignalCoreImpl.setSharedClient(client)
    }

    override func tearDownWithError() throws {
        // The mock answers 50ms late, so a Request still in flight would otherwise land mid-next-test.
        OneSignalCoreMocks.waitUntil("A Request was still in flight at teardown") { self.client.isIdle }
        OneSignalCoreMocks.clearUserDefaults()
    }

    /// The models a launch leaves behind when it is killed before its Create User is sent, with the queue empty.
    @discardableResult
    private func cacheUser(externalId: String?) -> OSUserInternal {
        return OneSignalUserManagerImpl.sharedInstance.setNewInternalUser(externalId: externalId, pushSubscriptionModel: nil)
    }

    private func sentCreateUsers() -> [OSRequestCreateUser] {
        return client.executedRequests.compactMap { $0 as? OSRequestCreateUser }
    }

    private func externalId(of request: OSRequestCreateUser) -> String? {
        return (request.parameters?["identity"] as? [String: String])?[OS_EXTERNAL_ID]
    }

    func testStartCreatesACachedIdentifiedUserWithNoOneSignalId() {
        let user = cacheUser(externalId: userA_EUID)

        OneSignalUserManagerImpl.sharedInstance.start()

        OneSignalCoreMocks.waitUntil("The cached user was not created") {
            self.client.hasCompletedRequestOfType(OSRequestCreateUser.self)
        }
        XCTAssertEqual(sentCreateUsers().map(externalId(of:)), [userA_EUID])
        OneSignalCoreMocks.waitUntil("The response did not hydrate the cached user") { user.identityModel.onesignalId != nil }
    }

    func testStartCreatesACachedAnonymousUserWithNoOneSignalId() {
        cacheUser(externalId: nil)

        OneSignalUserManagerImpl.sharedInstance.start()

        OneSignalCoreMocks.waitUntil("The cached user was not created") {
            self.client.hasCompletedRequestOfType(OSRequestCreateUser.self)
        }
        XCTAssertEqual(sentCreateUsers().count, 1)
        XCTAssertNil(sentCreateUsers().first.flatMap(externalId(of:)))
    }

    func testStartSendsACachedCreateUserOnceWhenItIsStillQueued() {
        let user = cacheUser(externalId: userA_EUID)
        let queued = OSRequestCreateUser(
            identityModel: user.identityModel,
            propertiesModel: user.propertiesModel,
            pushSubscriptionModel: user.pushSubscriptionModel,
            originalPushToken: nil
        )
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: OS_USER_EXECUTOR_USER_REQUEST_QUEUE_KEY, withValue: [queued])

        OneSignalUserManagerImpl.sharedInstance.start()

        OneSignalCoreMocks.waitUntil("The cached Create User did not complete") {
            self.client.hasCompletedRequestOfType(OSRequestCreateUser.self)
        }
        // A second one would still be queued here: it goes out only after the post-create delay.
        OneSignalCoreMocks.waitUntil("A Create User is still queued") {
            OneSignalUserManagerImpl.sharedInstance.userExecutor?.userRequestQueue.contains { $0 is OSRequestCreateUser } == false
        }
        XCTAssertEqual(sentCreateUsers().count, 1)
    }

    func testStartAsksForATokenForACachedIdentifiedUserUnderIdentityVerification() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        // Held strongly for the test's lifetime: the observer keeps listeners weakly.
        let listener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(listener)
        defer { OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(listener) }
        cacheUser(externalId: userA_EUID)

        OneSignalUserManagerImpl.sharedInstance.start()

        OneSignalCoreMocks.waitUntil("The app was not asked for a token") { listener.invalidatedExternalIds == [userA_EUID] }
        XCTAssertTrue(sentCreateUsers().isEmpty)

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: "a-token")

        OneSignalCoreMocks.waitUntil("The Create User did not go out with the token") {
            self.client.hasCompletedRequestOfType(OSRequestCreateUser.self)
        }
        XCTAssertEqual(sentCreateUsers().map(externalId(of:)), [userA_EUID])
    }

    func testStartLeavesACachedAnonymousUserAloneUnderIdentityVerification() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        cacheUser(externalId: nil)

        OneSignalUserManagerImpl.sharedInstance.start()

        // Nothing positive to wait for: give the executor's queue a turn, then look.
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertTrue(sentCreateUsers().isEmpty)
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.userExecutor?.userRequestQueue.isEmpty, true)
    }
}
