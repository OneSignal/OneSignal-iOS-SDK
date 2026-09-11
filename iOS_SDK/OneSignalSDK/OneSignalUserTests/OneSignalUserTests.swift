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
@_spi(OneSignalInternal) @testable import OneSignalUser

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

    func testInternalOnesignalIdTracksCurrentUser() {
        let manager = OneSignalUserManagerImpl.sharedInstance
        OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        XCTAssertEqual(manager.internalOnesignalId, "osid-a")

        OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-b", onesignalId: "osid-b")
        XCTAssertEqual(manager.internalOnesignalId, "osid-b")
    }

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

        OSOperationRepo.sharedInstance.flushAndWait()

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

        OneSignalCoreMocks.waitUntil("Combined property update did not complete") {
            client.hasCompletedRequestOfType(OSRequestUpdateProperties.self)
        }

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

    /**
     Unit test for the tag-merge primitive.

     `mergeConfirmedTags` must overlay only the provided keys onto the local model: update existing
     values, remove keys whose value is `""`, add new keys, and leave all other (e.g. backend-managed)
     tags untouched. It must never wholesale-replace the tag dictionary.
     */
    func testMergeConfirmedTags_mergesAndRemovesWithoutTouchingOtherTags() throws {
        /* Setup */
        let model = OSPropertiesModel(changeNotifier: OSEventProducer())
        model.hydrate(["tags": ["keep": "1", "update": "old", "remove": "2"]])

        /* When */
        // "update" changes, "remove" is deleted (""), "add" is new; "keep" must be left untouched
        model.mergeConfirmedTags(["update": "new", "remove": "", "add": "3"])

        /* Then */
        XCTAssertEqual(model.tags, ["keep": "1", "update": "new", "add": "3"])
    }

    /**
     Regression test: `getTags()` returns `{}` after a concurrent, stale `FetchUser` overwrites the
     local tag model.

     A concurrent `FetchUser` whose response is missing a recently written tag clears the local tag
     cache (`clearUserData()`) and hydrates without it. The `OSRequestUpdateProperties` 202 response
     echoes the tags the server just confirmed, so merging those back into the local model must restore
     the tags that the stale fetch cleared.
     */
    func testUpdatePropertiesResponse_restoresTagsClearedByConcurrentFetch() throws {
        /* Setup */
        let client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        let tags = ["tag_a": "value_a", "tag_b": "value_b"]
        MockUserRequests.setAddTagsResponse(with: client, tags: tags)
        OneSignalCoreImpl.setSharedClient(client)

        OneSignalUserManagerImpl.sharedInstance.start()

        // Let the anonymous user be created so it has a OneSignal ID for the update request
        OneSignalCoreMocks.waitUntil("Anonymous user creation did not complete") {
            client.hasCompletedRequestOfType(OSRequestCreateUser.self)
        }

        /* When */
        // Tags are applied optimistically to the local model and queued as an update request
        OneSignalUserManagerImpl.sharedInstance.addTags(tags)

        // Simulate a concurrent, stale FetchUser clearing the local tag cache before the
        // UpdateProperties 202 response is processed
        OneSignalUserManagerImpl.sharedInstance.user.propertiesModel.clearData()
        XCTAssertTrue(OneSignalUserManagerImpl.sharedInstance.getTags().isEmpty)

        // Let the queued UpdateProperties request flush and its 202 echo be processed
        OneSignalCoreMocks.waitUntil("Confirmed tags were not restored") {
            OneSignalUserManagerImpl.sharedInstance.getTags() == tags
        }

        /* Then */
        // The confirmed tags from the 202 response are merged back into the local model
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.getTags(), tags)
    }

    // MARK: - Atomic current user access

    /**
     A callback that acts on the current user must keep acting on the user it checked, even if a
     `login()` makes a different user current right afterwards. Swapping the user between the check
     and the mutation reproduces that interleaving.
     */
    func testCurrentUser_matching_isTheUserMutated_whenTheUserChangesRightAfterTheCheck() throws {
        /* Setup */
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())
        let manager = OneSignalUserManagerImpl.sharedInstance
        let userA = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)

        /* When */
        let checkedUser = manager.currentUser(matching: userA.identityModel.modelId)
        // A concurrent login switches the current user before the response is applied
        let userB = OneSignalUserMocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: userB_OSID)
        let userBLanguage = userB.propertiesModel.language
        checkedUser?.propertiesModel.hydrate(["language": "language-for-user-a"])

        /* Then */
        // The response's data went to the user it was for, and the new current user is untouched
        XCTAssertEqual(userA.propertiesModel.language, "language-for-user-a")
        XCTAssertEqual(userB.propertiesModel.language, userBLanguage)
        XCTAssertEqual(manager._user?.identityModel.externalId, userB_EUID)
    }

    /// The common path: the request's user is still current, so it is returned to be mutated.
    func testCurrentUser_matching_returnsTheCurrentUser() throws {
        /* Setup */
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())
        let manager = OneSignalUserManagerImpl.sharedInstance
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)

        /* Then */
        XCTAssertEqual(manager.currentUser(matching: user.identityModel.modelId)?.identityModel.externalId, userA_EUID)
    }

    /// A response for a user that is no longer current must not be applied at all.
    func testCurrentUser_matching_isNilWhenTheUserIsNoLongerCurrent() throws {
        /* Setup */
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())
        let manager = OneSignalUserManagerImpl.sharedInstance
        let userA = OneSignalUserMocks.setUserManagerInternalUser(externalId: userA_EUID, onesignalId: userA_OSID)
        let userB = OneSignalUserMocks.setUserManagerInternalUser(externalId: userB_EUID, onesignalId: userB_OSID)

        /* Then */
        XCTAssertNil(manager.currentUser(matching: userA.identityModel.modelId))
        XCTAssertNotNil(manager.currentUser(matching: userB.identityModel.modelId))
    }

    /// With no current user, there is nothing for a late response to act on.
    func testCurrentUser_matching_isNilWhenThereIsNoUser() throws {
        /* Setup */
        let manager = OneSignalUserManagerImpl.sharedInstance
        let identityModel = OSIdentityModel(aliases: nil, changeNotifier: OSEventProducer())

        /* Then */
        XCTAssertNil(manager._user)
        XCTAssertNil(manager.currentUser(matching: identityModel.modelId))
    }

    // MARK: - Remotely disabled push subscriptions

    /// The notification_types codes the app owner sets remotely: -22 unsubscribes the subscription
    /// by hand from the dashboard, -31 disables it through the REST API. Both mean "the server
    /// turned this off" and are treated identically, but each is recorded as itself so outgoing
    /// payloads echo back the code the server actually sent.
    private static let remoteDisableCodes = [-22, -31]

    /// A push model hydrated with the server's remote disable state for `code`.
    private func pushModelWithRemoteDisable(_ code: Int = -31) -> OSSubscriptionModel {
        let model = OSSubscriptionModel(
            type: .push,
            address: "test-token",
            subscriptionId: "test-sub-id",
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
        model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": code])
        return model
    }

    func testRemoteDisable_recognizesOnlyTheTwoServerOwnedCodes() {
        for code in Self.remoteDisableCodes {
            XCTAssertTrue(
                OSRemoteDisable.matches(code),
                "\(code) is a code the app owner sets remotely and must suppress outgoing payloads"
            )
        }
        // Every other code describes device or delivery state the device recovers from by
        // re-asserting its own truth. Treating one as a remote disable would permanently suppress
        // a subscription the device could have re-enabled, so the boundary matters more than the
        // list: -21/-23/-24 sit inside the range reserved for other platforms, and -30/-32
        // bracket the REST API code.
        for code in [1, 0, -2, -3, -13, -21, -23, -24, -25, -30, -32] {
            XCTAssertFalse(
                OSRemoteDisable.matches(code),
                "\(code) is device-recoverable and must not be recorded as a remote disable"
            )
        }
        XCTAssertFalse(OSRemoteDisable.matches(nil))
    }

    func testRemoteDisable_overridesOutgoingSubscriptionPayloads() {
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)
            XCTAssertEqual(model.remoteDisabledReason, code)

            // The recorded code round-trips rather than collapsing to the other one.
            let json = model.jsonRepresentation()
            XCTAssertEqual(json["enabled"] as? Bool, false)
            XCTAssertEqual(json["notification_types"] as? Int, code)

            let updateRequest = OSRequestUpdateSubscription(subscriptionModel: model)
            let params = updateRequest.parameters?["subscription"] as? [String: Any]
            XCTAssertEqual(params?["enabled"] as? Bool, false)
            XCTAssertEqual(params?["notification_types"] as? Int, code)
        }
    }

    func testRemoteDisable_survivesDeviceStateRefresh() {
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)

            // Device-driven recomputes must not clear server-owned disable state
            model.updateNotificationTypes()
            model.update()

            XCTAssertEqual(model.remoteDisabledReason, code)
            XCTAssertEqual(model.jsonRepresentation()["enabled"] as? Bool, false)
        }
    }

    func testRemoteDisable_survivesArchiving() throws {
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)

            let data = try NSKeyedArchiver.archivedData(withRootObject: model, requiringSecureCoding: false)
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            let restored = try XCTUnwrap(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? OSSubscriptionModel)

            XCTAssertEqual(restored.remoteDisabledReason, code)
            XCTAssertEqual(restored.jsonRepresentation()["enabled"] as? Bool, false)
        }
    }

    func testRemoteDisable_clearedByOptIn() {
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)

            model.clearRemoteDisable()

            XCTAssertNil(model.remoteDisabledReason)
            let json = model.jsonRepresentation()
            XCTAssertEqual(json["enabled"] as? Bool, true)
            XCTAssertNotEqual(json["notification_types"] as? Int, code)
        }
    }

    func testRemoteDisable_mirrorsServerField() {
        // Only -22 and -31 are ever recorded; any other reported value is not, and clears an
        // existing disable. Each code is recorded as itself, including replacing the other one.
        let model = OSSubscriptionModel(
            type: .push,
            address: "test-token",
            subscriptionId: "test-sub-id",
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
        model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": -2])
        XCTAssertNil(model.remoteDisabledReason)

        for code in Self.remoteDisableCodes {
            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": code])
            XCTAssertEqual(model.remoteDisabledReason, code)

            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": -2])
            XCTAssertNil(model.remoteDisabledReason)
            XCTAssertEqual(model.jsonRepresentation()["enabled"] as? Bool, true)
        }
    }

    func testRemoteDisable_switchingBetweenTheTwoCodesRecordsTheLatest() {
        // The dashboard and the REST API can both act on the same subscription, so a second
        // disable arriving under the other code must replace the recorded one rather than be
        // ignored as "already disabled".
        let model = pushModelWithRemoteDisable(-22)
        XCTAssertEqual(model.remoteDisabledReason, -22)

        model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": -31])

        XCTAssertEqual(model.remoteDisabledReason, -31)
        XCTAssertEqual(model.jsonRepresentation()["notification_types"] as? Int, -31)
    }

    func testRemoteDisable_clearedWhenSubscriptionIdResets() {
        // The disable code describes a specific server record; it must die with the record.
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)

            model.subscriptionId = nil

            XCTAssertNil(model.remoteDisabledReason)
            XCTAssertEqual(model.jsonRepresentation()["enabled"] as? Bool, true)
        }
    }

    func testRemoteDisable_optInOutranksStaleHydration() {
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)

            // A stale fetch response landing after optIn() cleared the disable must not re-record it
            model.clearRemoteDisable()
            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": code])
            XCTAssertNil(model.remoteDisabledReason)

            // Once the server reports another state, recording re-arms for a later operator disable
            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": true, "notification_types": 1])
            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": code])
            XCTAssertEqual(model.remoteDisabledReason, code)
        }
    }

    func testRemoteDisable_optInFromOptedOutOutranksStaleHydration() {
        // The customer's first disable is the common shape of this race. The customer disables the
        // subscription, a fetch goes out that will report it, and an opted-out user opts in before
        // that response lands. Nothing is recorded locally yet, but the opt-in changed the device
        // state and a re-enable is on its way, so the stale response must not record over it.
        for code in Self.remoteDisableCodes {
            let model = OSSubscriptionModel(
                type: .push,
                address: "test-token",
                subscriptionId: "test-sub-id",
                reachable: true,
                isDisabled: true,
                changeNotifier: OSEventProducer()
            )

            model.clearRemoteDisable(userWasOptedOut: true)

            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": code])
            XCTAssertNil(model.remoteDisabledReason, "a fetch predating optIn() must not record \(code)")
        }
    }

    func testRemoteDisable_optInThatChangesNothingDoesNotOutrankALaterDisable() {
        // Many apps call optIn() on every launch. A call that finds the user already opted in with
        // nothing recorded sends nothing, so it has no intent to protect. Arming the guard for it
        // would make every fetch that reports a disable get ignored until the process died, and the
        // next routine update would re-enable the subscription, which is the bug this branch fixes.
        for code in Self.remoteDisableCodes {
            let model = OSSubscriptionModel(
                type: .push,
                address: "test-token",
                subscriptionId: "test-sub-id",
                reachable: true,
                isDisabled: false,
                changeNotifier: OSEventProducer()
            )

            model.clearRemoteDisable(userWasOptedOut: false)

            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": code])
            XCTAssertEqual(model.remoteDisabledReason, code, "a disable landing after a no-op optIn() must be recorded")
            XCTAssertEqual(model.jsonRepresentation()["enabled"] as? Bool, false)
        }
    }

    func testRemoteDisable_clearedWhenServerReportsEnabled() {
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)

            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": true, "notification_types": 1])

            XCTAssertNil(model.remoteDisabledReason)
        }
    }

    /**
     A push subscription the app owner turned off remotely must stay disabled across a login to a
     different external ID. The fetch hydrates the server's disable state onto the existing
     subscription, and the login's Create User payload echoes it back.

     Uses -22 (unsubscribed by hand from the dashboard) rather than -31 so this end-to-end path also
     proves the exact recorded code survives, instead of every remote disable reporting as -31.
     */
    func testLoginToDifferentUser_afterRemoteDisable_sendsDisabledPushSubscription() throws {
        /* Setup */
        let client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userA_EUID)
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userB_EUID)

        // Fetching user A reports the push subscription unsubscribed from the dashboard
        var disabledResponse = MockUserRequests.testDefaultFullCreateUserResponse(
            onesignalId: anonUserOSID,
            externalId: userA_EUID,
            subscriptionId: testPushSubId
        )
        let disabledSub = MockUserRequests.testDefaultPushSubPayload(id: testPushSubId)
            .merging(["enabled": false, "notification_types": -22]) { _, new in new }
        disabledResponse["subscriptions"] = [disabledSub]
        client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with onesignal_id: \(anonUserOSID)>",
            response: disabledResponse
        )
        OneSignalCoreImpl.setSharedClient(client)

        // 1. Start with an anonymous user and log in to user A; the post-identify fetch
        // hydrates the remote disable onto the existing push subscription
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)

        OneSignalCoreMocks.waitUntil("Fetch did not hydrate the remote disable") {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.externalId == userA_EUID &&
                OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.remoteDisabledReason == -22
        }

        /* When */

        // 2. Log in to user B, which sends a Create User carrying the push subscription
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)

        func createUserBRequest() -> OSRequestCreateUser? {
            return client.executedRequests.compactMap { $0 as? OSRequestCreateUser }.first {
                ($0.parameters?["identity"] as? [String: String])?[OS_EXTERNAL_ID] == userB_EUID
            }
        }
        OneSignalCoreMocks.waitUntil("Create User for user B was not sent") {
            createUserBRequest() != nil
        }

        /* Then */

        let subscriptions = try XCTUnwrap(createUserBRequest()?.parameters?["subscriptions"] as? [[String: Any]])
        XCTAssertEqual(subscriptions.first?["enabled"] as? Bool, false)
        XCTAssertEqual(subscriptions.first?["notification_types"] as? Int, -22)
    }
}


/**
 `optedIn` is the only signal the public API gives an app for "will push reach this device", so a
 subscription the app owner turned off remotely has to report false there. Kept in its own class
 because these build bare models and never touch the user manager singleton.
 */
final class RemoteDisableOptedInTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        // Firing a push subscription change reaches the user manager singleton and can enqueue a
        // delta, so reset it between tests the way the rest of this suite does.
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"
    }

    /// The notification_types codes the app owner sets remotely: -22 from the dashboard, -31 through
    /// the REST API. Treated identically, recorded separately.
    private static let remoteDisableCodes = [-22, -31]

    private func makePushModel() -> OSSubscriptionModel {
        return OSSubscriptionModel(
            type: .push,
            address: "test-token",
            subscriptionId: "test-sub-id",
            reachable: true,
            isDisabled: false,
            changeNotifier: OSEventProducer()
        )
    }

    private func pushModelWithRemoteDisable(_ code: Int) -> OSSubscriptionModel {
        let model = makePushModel()
        model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "enabled": false, "notification_types": code])
        return model
    }

    func testRemoteDisable_reportsOptedInFalse() {
        // A remote disable suppresses delivery, so the property clients read to decide whether push
        // works must say so. Before this, a preference center showed "subscribed" on a device the
        // app owner had turned off, and nothing in the public API revealed why.
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)

            XCTAssertFalse(model.optedIn, "a \(code) disable must report optedIn false")
            // currentPushSubscriptionState builds the observer payload, so it has to agree.
            XCTAssertFalse(model.currentPushSubscriptionState.optedIn)

            // The toggle a client drives off is not a dead end: opting in reports true again.
            model.clearRemoteDisable()
            XCTAssertTrue(model.optedIn)
            XCTAssertTrue(model.currentPushSubscriptionState.optedIn)
        }
    }

    func testRemoteDisable_optedInIgnoresDeviceRecoverableCodes() {
        // Only the two server-owned codes reach optedIn, and they arrive through
        // remoteDisabledReason rather than notificationTypes. A device-side delivery error is
        // recoverable by re-asserting local state, so it must not read as an opt-out to the app.
        let model = makePushModel()

        for code in [-2, -13, -25, -30, -32] {
            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "notification_types": code])
            XCTAssertTrue(model.optedIn, "\(code) is device-recoverable and must not clear optedIn")
        }
    }

    func testRemoteDisable_hydrationDoesNotEnqueueAnEnabledDelta() {
        // Hydrating the disable flips optedIn, which observers need to hear about, but the server
        // is where the state came from. Enqueueing an `enabled` delta for it would send a request
        // telling the server what it just told us, so the observer fires without one.
        for code in Self.remoteDisableCodes {
            let model = makePushModel()
            let spy = SpyModelChangedHandler()
            model.changeNotifier.subscribe(spy)

            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "notification_types": code])
            XCTAssertEqual(model.remoteDisabledReason, code)
            XCTAssertTrue(spy.serverUpdates.isEmpty, "hydrating \(code) must not enqueue a delta")
            // The reason was still written, so the assertion above is not passing vacuously.
            XCTAssertTrue(spy.hydratedUpdates.contains("remoteDisabledReason"))

            // Clearing it from the server side is the same story.
            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "notification_types": -2])
            XCTAssertNil(model.remoteDisabledReason)
            XCTAssertFalse(spy.serverUpdates.contains("enabled"))

            // An optIn() clear is the opposite case: the delta is how the server re-enables it.
            model.hydrateRemoteDisableState(from: ["id": "test-sub-id", "notification_types": code])
            spy.serverUpdates.removeAll()
            model.clearRemoteDisable()
            XCTAssertTrue(spy.serverUpdates.contains("enabled"), "optIn() must re-enable on the server")
        }
    }

    func testRemoteDisable_emailAndSmsHydrateWithoutRecordingOrNotifyingPush() {
        // The server writes the same codes on email and SMS rows the app owner disables, and those
        // models hydrate through the same path. The remote disable state and the push observer it
        // drives are push-only, so an email row must not record one or reach push observers with an
        // email address as the token.
        let observer = SpyPushSubscriptionObserver()
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.addObserver(observer)
        defer { OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.removeObserver(observer) }

        for (type, address) in [(OSSubscriptionType.email, "person@example.com"), (.sms, "+15555550100")] {
            for code in Self.remoteDisableCodes {
                let model = OSSubscriptionModel(
                    type: type,
                    address: address,
                    subscriptionId: "test-other-sub-id",
                    reachable: true,
                    isDisabled: false,
                    changeNotifier: OSEventProducer()
                )

                model.hydrate([
                    "id": "test-other-sub-id", "type": type.rawValue, "token": address, "enabled": false, "notification_types": code
                ])

                XCTAssertNil(model.remoteDisabledReason, "\(type.rawValue) must not record \(code)")
                XCTAssertEqual(model.notificationTypes, code)
                XCTAssertTrue(model._isDisabled, "\(type.rawValue) keeps the plain enabled mapping")
            }
        }

        // Observer callbacks hop to the main queue, so let anything queued arrive before asserting nothing did.
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        XCTAssertTrue(observer.changes.isEmpty, "email and SMS hydration must not reach push observers")
    }

    func testRemoteDisable_resetEventReportsThePreviousStateAsDisabled() throws {
        // Observers see the reset as one change: the disabled record with its ID, then no record and
        // no disable. Clearing the code before building the event made the previous state read as
        // opted in, so the app never saw the disable end.
        for code in Self.remoteDisableCodes {
            let model = pushModelWithRemoteDisable(code)
            let observer = SpyPushSubscriptionObserver()
            OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.addObserver(observer)
            defer { OneSignalUserManagerImpl.sharedInstance.pushSubscriptionImpl.removeObserver(observer) }
            let spy = SpyModelChangedHandler()
            model.changeNotifier.subscribe(spy)

            model.subscriptionId = nil

            OneSignalCoreMocks.waitUntil("the reset did not reach push observers") { !observer.changes.isEmpty }
            let change = try XCTUnwrap(observer.changes.last)
            XCTAssertEqual(change.previous.id, "test-sub-id")
            XCTAssertFalse(change.previous.optedIn, "the record was disabled by \(code) until it went away")
            XCTAssertNil(change.current.id)
            XCTAssertTrue(change.current.optedIn)
            // The new record's state travels with the create request, not as a delta against the dead ID.
            XCTAssertFalse(spy.serverUpdates.contains("enabled"))
        }
    }
}

/// Records the properties a model reported as changed, split by whether the change was meant to
/// reach the server. `hydrating` is true for writes that only mirror state the server already has.
private class SpyPushSubscriptionObserver: NSObject, OSPushSubscriptionObserver {
    var changes: [OSPushSubscriptionChangedState] = []

    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        changes.append(state)
    }
}

private class SpyModelChangedHandler: OSModelChangedHandler {
    var serverUpdates: [String] = []
    var hydratedUpdates: [String] = []

    func onModelUpdated(args: OSModelChangedArgs, hydrating: Bool) {
        if hydrating {
            hydratedUpdates.append(args.property)
        } else {
            serverUpdates.append(args.property)
        }
    }
}
