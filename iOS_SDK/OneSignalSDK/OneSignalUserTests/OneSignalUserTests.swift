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
import OneSignalCoreMocks
import OneSignalUserMocks
// Testable import OSCore to allow setting a different poll flush interval
@testable import OneSignalOSCore
@testable import OneSignalUser

final class OneSignalUserTests: XCTestCase {

    override func setUpWithError() throws {
        // TODO: Something like the existing [UnitTestCommonMethods beforeEachTest:self];
        // TODO: Need to clear all data between tests for client, user manager, models, etc.
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        // App ID is set because User Manager has guards against nil App ID
        OneSignalIdentifiers.currentAppId = "test-app-id"
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }

    // Comparable to Android test: "externalId is backed by the identity model"
    func testLoginSetsExternalId() throws {
        /* Setup */
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())

        /* When */
        OneSignalUserManagerImpl.sharedInstance.login(externalId: "my-external-id", token: nil)

        /* Then */
        let identityModelStoreExternalId = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(key: OS_IDENTITY_MODEL_KEY)?.externalId
        let userInstanceExternalId = OneSignalUserManagerImpl.sharedInstance.user.identityModel.externalId

        XCTAssertEqual(identityModelStoreExternalId, "my-external-id")
        XCTAssertEqual(userInstanceExternalId, "my-external-id")
    }

    /**
     Regression test for the iOS prewarm fix (SDK-4725).

     `start()` is gated by `OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent`, which now
     also defers while device-protected storage is unreadable (iOS app prewarm before first unlock).
     This verifies the contract the fix depends on: a `start()` that is gated out must be a no-op —
     `hasCalledStart` stays false and no user is half-initialized — and a later `start()`, once
     protected data is available, must proceed. The main app relies on that re-drive after it seeds
     the protected-data flag and on `UIApplicationProtectedDataDidBecomeAvailable`; if the re-drive
     ever stops taking effect (as it did when the flag was seeded asynchronously after the
     synchronous `start()` during init), the user module never starts on a normal launch.
     */
    func testStartDefersUntilProtectedDataAvailableThenProceeds() throws {
        /* Setup */
        let client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        OneSignalCoreImpl.setSharedClient(client)

        let manager = OneSignalUserManagerImpl.sharedInstance

        // Simulate protected data being unavailable (iOS prewarm before first unlock).
        var protectedDataAvailable = false
        OneSignalConfig.isProtectedDataAvailableProvider = { protectedDataAvailable }
        defer { OneSignalConfig.isProtectedDataAvailableProvider = nil }

        /* When protected data is unavailable, start() must be a no-op */
        manager.start()
        XCTAssertFalse(manager.hasCalledStart)
        XCTAssertNil(manager._user)

        /* When protected data becomes available, the re-driven start() must proceed */
        protectedDataAvailable = true
        manager.start()
        XCTAssertTrue(manager.hasCalledStart)
        XCTAssertNotNil(manager._user)
    }

    /**
     Tests multiple user updates should be combined and sent together.
     Multiple session times should be added.
     Adding and removing multiple tags should be combined correctly.
     Language uses the last language that is set.
     Location uses the last point that is set.
     */
    func testBasicCombiningUserUpdateDeltas_resultsInOneRequest() throws {
        /* Setup */

        OneSignalUserManagerImpl.sharedInstance.start()

        let client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        OneSignalCoreImpl.setSharedClient(client)

        // Increase flush interval to allow all the updates to batch
        OSOperationRepo.sharedInstance.pollIntervalMilliseconds = 300

        // Wait to let any pending flushes in the Operation Repo to run
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.1)

        /* When */

        OneSignalUserManagerImpl.sharedInstance.sendSessionTime(100)

        OneSignalUserManagerImpl.sharedInstance.updatePropertiesDeltas(property: .session_count, value: 1, flush: false)

        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_1")

        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_1", value: "value_1")

        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_2")

        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_2", value: "value_2")

        OneSignalUserManagerImpl.sharedInstance.sendSessionTime(50)

        OneSignalUserManagerImpl.sharedInstance.setLocation(latitude: 123.123, longitude: 145.145)

        OneSignalUserManagerImpl.sharedInstance.removeTag("tag_1")

        OneSignalUserManagerImpl.sharedInstance.addTags(["a": "a", "b": "b", "c": "c"])

        let purchases = [
            ["sku": "sku1", "amount": "1.25", "iso": "USD"],
            ["sku": "sku2", "amount": "3.99", "iso": "USD"]
        ]

        OneSignalUserManagerImpl.sharedInstance.sendPurchases(purchases as [[String: AnyObject]])

        OneSignalUserManagerImpl.sharedInstance.setLocation(latitude: 111.111, longitude: 222.222)

        // This adds a `session_count` property with value of 1
        // It also sets `refresh_device_metadata` to `true`
        OneSignalUserManagerImpl.sharedInstance.startNewSession()

        /* Then */

        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 1)

        let expectedPayload: [String: Any] = [
            "deltas": [
                "session_time": 150, // addition of 2 session times
                "session_count": 2, // addition of 2 session counts
                "purchases": purchases
            ],
            "properties": [
                "lat": 111.111,
                "long": 222.222,
                "language": "lang_2",
                "tags": [
                    "tag_1": "",
                    "tag_2": "value_2",
                    "a": "a",
                    "b": "b",
                    "c": "c"
                ]
            ],
            "refresh_device_metadata": true
        ]

        // Assert there is an update user request with the expected payload
        XCTAssertTrue(client.onlyOneRequest(
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)",
            contains: expectedPayload)
        )
    }

    // MARK: - Atomic current-user accessor (TOCTOU)

    /**
     The user executors guard a network-response callback with the current user and then separately
     dereference `_user`. A concurrent login/logout can swap `_user` between the two, applying one
     user's data or action to a different user. `withCurrentUser(matching:)` closes that window by
     reading `_user` once and passing that same captured instance to the closure.

     This is the safe path: when the current user still owns the model ID, the closure runs on the
     captured current user.
     */
    func testWithCurrentUser_runsClosureOnCapturedCurrentUser_whenModelIdMatches() throws {
        /* Setup */
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        let modelId = user.identityModel.modelId

        /* When */
        var runCount = 0
        var capturedIsCurrentUser = false
        OneSignalUserManagerImpl.sharedInstance.withCurrentUser(matching: modelId) { capturedUser in
            runCount += 1
            // The closure must receive the very instance that is currently `_user`.
            capturedIsCurrentUser = capturedUser.identityModel === OneSignalUserManagerImpl.sharedInstance._user?.identityModel
        }

        /* Then */
        XCTAssertEqual(runCount, 1)
        XCTAssertTrue(capturedIsCurrentUser)
    }

    /**
     Simulates the TOCTOU race: a concurrent login swaps `_user` to a different user before the
     callback runs. The accessor must NOT run its closure for the now-stale model ID, so the response
     can't be applied to the new current user (cross-user contamination).
     */
    func testWithCurrentUser_doesNotRunClosure_whenUserSwappedToDifferentModelId() throws {
        /* Setup */
        let previousUser = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        let staleModelId = previousUser.identityModel.modelId

        // A concurrent login swaps the current user out from under the in-flight request.
        let currentUser = OneSignalUserMocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: userB_OSID)
        XCTAssertNotEqual(staleModelId, currentUser.identityModel.modelId)

        /* When */
        var runCount = 0
        OneSignalUserManagerImpl.sharedInstance.withCurrentUser(matching: staleModelId) { _ in
            runCount += 1
        }

        /* Then */
        XCTAssertEqual(runCount, 0)
    }

    /**
     When there is no current user (e.g. `_user == nil` during the logout window), the accessor must
     not run its closure rather than dereferencing a nil or recreated user.
     */
    func testWithCurrentUser_doesNotRunClosure_whenNoCurrentUser() throws {
        /* Setup */
        // `OneSignalUserMocks.reset()` (called in setUp) leaves `_user == nil`.
        XCTAssertNil(OneSignalUserManagerImpl.sharedInstance._user)

        /* When */
        var runCount = 0
        OneSignalUserManagerImpl.sharedInstance.withCurrentUser(matching: UUID().uuidString) { _ in
            runCount += 1
        }

        /* Then */
        XCTAssertEqual(runCount, 0)
    }

    /**
     `currentUser(matching:)` is the non-closure variant used to gate `_logout()`. It must return the
     current user only when the model ID matches, and `nil` when there is no user or the user was
     swapped, so a stale failure callback can't log out a different user.
     */
    func testCurrentUserMatching_returnsUserOnlyWhenModelIdMatches() throws {
        /* No current user → nil */
        XCTAssertNil(OneSignalUserManagerImpl.sharedInstance.currentUser(matching: UUID().uuidString))

        /* Matching current user → the captured instance */
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        let staleModelId = user.identityModel.modelId
        let matched = OneSignalUserManagerImpl.sharedInstance.currentUser(matching: staleModelId)
        XCTAssertNotNil(matched)
        XCTAssertTrue(matched?.identityModel === user.identityModel)

        /* Concurrent swap → the previous model ID no longer matches → nil */
        _ = OneSignalUserMocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: userB_OSID)
        XCTAssertNil(OneSignalUserManagerImpl.sharedInstance.currentUser(matching: staleModelId))
    }
}
