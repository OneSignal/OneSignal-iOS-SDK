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
 What `login` and `logout` do differently under Identity Verification: no anonymous user is ever sent to
 the server, so login creates rather than promotes and logout has to silence the push subscription itself.
 */
final class UserJwtLifecycleTests: XCTestCase {
    /// Any opted-in value; the point is that it survives unchanged, or is replaced by -2.
    private let optedInNotificationTypes = 7

    private var client = MockOneSignalClient()
    private var observer = MockUserStateObserver()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userA_EUID)
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userA_EUID)
        OneSignalCoreImpl.setSharedClient(client)

        // Held strongly for the test's lifetime: OSObservable keeps observers weakly.
        observer = MockUserStateObserver()
        OneSignalUserManagerImpl.sharedInstance.addObserver(observer)
    }

    override func tearDownWithError() throws {
        OneSignalUserManagerImpl.sharedInstance.removeObserver(observer)
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = false
        OneSignalCoreMocks.clearUserDefaults()
        OSFeatureManager.shared.setEnabledFeatureKeys([])
    }

    /// The push subscription as the server would see it right now.
    private func pushSubscriptionPayload() -> [String: Any] {
        return OneSignalUserManagerImpl.sharedInstance.user.pushSubscriptionModel.jsonRepresentation()
    }

    /// Reports a token and notification types, so a silenced payload is distinguishable from the default.
    @discardableResult
    private func optInPushSubscription() -> OSSubscriptionModel {
        let model = OneSignalUserManagerImpl.sharedInstance.user.pushSubscriptionModel
        model.address = "push-token"
        model.notificationTypes = optedInNotificationTypes
        return model
    }

    private func queuedUserRequests() -> [OSUserRequest] {
        return OneSignalUserManagerImpl.sharedInstance.userExecutor?.userRequestQueue ?? []
    }

    /// The `external_id` of every queued Create User, so a test can tell the anonymous one apart.
    private func queuedCreateUserExternalIds() -> [String] {
        return queuedUserRequests().compactMap { ($0 as? OSRequestCreateUser)?.identityModel.externalId }
    }

    /// The header the Create User went out with, so a test can tell that it was signed.
    private func executedCreateUserAuthorization() -> String? {
        return client.executedRequests.first { $0 is OSRequestCreateUser }?.additionalHeaders?["Authorization"]
    }

    /// The Delta `logout()` produces by silencing the push subscription.
    private func silencingDelta() -> OSDelta? {
        return OneSignalUserManagerImpl.sharedInstance.operationRepo.deltaQueue.first {
            $0.name == OS_UPDATE_SUBSCRIPTION_DELTA && $0.property == "isDisabledInternally"
        }
    }

    /// `start()` re-reads the cached requirement, so the setup default has to be cleared too.
    private func makeRequirementUnknown() {
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_USE_IDENTITY_VERIFICATION)
        OSCoreMocks.resetSharedJwtConfig()
    }

    // MARK: - login

    func testLoginFromAnonymousPromotesTheUserWhileIdentityVerificationIsOff() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        _ = OneSignalUserManagerImpl.sharedInstance.user // anonymous user first

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
    }

    /// Identify User adds an `external_id` to an anonymous user, which Identity Verification does not allow.
    func testLoginFromAnonymousCreatesANewUserWhileIdentityVerificationIsRequired() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        _ = OneSignalUserManagerImpl.sharedInstance.user

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCreateUser.self))
    }

    /// Promoting before remote params answer is safe because nothing is sent while the requirement is
    /// unknown, so the queued promotion can still be reshaped into the Create User auth requires.
    func testLoginWhileTheRequirementIsUnknownBecomesACreateUserOnceAuthIsRequired() {
        OSFeatureManager.shared.setEnabledFeatureKeys([OSFeatureFlag.identityVerification.rawValue])
        makeRequirementUnknown()
        _ = OneSignalUserManagerImpl.sharedInstance.user

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertTrue(queuedUserRequests().contains { $0 is OSRequestIdentifyUser })
        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestCreateUser.self))

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        // The login reaches the server as the Create User it should have been, signed with its own token,
        // and the anonymous user it replaced is never created.
        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCreateUser.self, expectedCount: 1))
        XCTAssertEqual(executedCreateUserAuthorization(), "Bearer token-a")
    }

    /// The same promotion when remote params answer the other way is simply sent.
    func testLoginWhileTheRequirementIsUnknownIsSentOnceAuthIsKnownToBeOff() {
        OSFeatureManager.shared.setEnabledFeatureKeys([OSFeatureFlag.identityVerification.rawValue])
        makeRequirementUnknown()
        _ = OneSignalUserManagerImpl.sharedInstance.user

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
    }

    /// With the rollout flag off, an unknown requirement has to behave exactly as it did before Identity
    /// Verification existed.
    func testLoginFromAnonymousPromotesTheUserWhileTheRequirementIsUnknownAndTheFlagIsOff() {
        makeRequirementUnknown()
        _ = OneSignalUserManagerImpl.sharedInstance.user

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertTrue(queuedUserRequests().contains { $0 is OSRequestIdentifyUser })
        XCTAssertFalse(queuedCreateUserExternalIds().contains(userA_EUID))
    }

    /// Re-logging in is how an app hands over a replacement token.
    func testLoggingInAgainAsTheSameUserStoresTheNewToken() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-b")

        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.userJwtRepo.validJwt(externalId: userA_EUID), "token-b")
    }

    // MARK: - a rejected token on the first Create User

    /**
     A 401 on Create User is the likeliest one under Identity Verification, and the token that answers it
     arrives through `updateUserJwt`, which resumes work by flushing. A paused Repo drops that flush, so the
     app would supply a good token and see nothing happen until the next session.
     */
    func testARejectedCreateUserLeavesTheRepoAbleToFlushTheReplacementToken() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        client.setMockFailureResponseForRequest(
            request: "<OSRequestCreateUser with external_id: \(userA_EUID)>",
            error: OneSignalClientError(code: 401, message: "unauthorized", responseHeaders: nil, response: nil, underlyingError: nil)
        )

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertFalse(OneSignalUserManagerImpl.sharedInstance.operationRepo.paused)
        // Parked, not dropped, and the rejected token is gone so the retry cannot reuse it.
        XCTAssertTrue(queuedCreateUserExternalIds().contains(userA_EUID))
        XCTAssertNil(OneSignalUserManagerImpl.sharedInstance.userJwtRepo.validJwt(externalId: userA_EUID))
    }

    /// Nothing else will send the held Create User: it is not a Delta, so the Repo flush does not reach it,
    /// and the hold leaves no attempt in flight whose response would drive the queue on.
    func testUpdateUserJwtSendsTheCreateUserThatARejectedTokenHeld() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        client.setMockFailureResponseForRequest(
            request: "<OSRequestCreateUser with external_id: \(userA_EUID)>",
            error: OneSignalClientError(code: 401, message: "unauthorized", responseHeaders: nil, response: nil, underlyingError: nil)
        )

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCreateUser.self, expectedCount: 1))

        // The token the app mints in answer to the invalidated event, which the server accepts.
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userA_EUID)
        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: "token-b")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        // The same Request re-signed and accepted, so it carries the replacement token and leaves the queue.
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCreateUser.self, expectedCount: 2))
        XCTAssertEqual(executedCreateUserAuthorization(), "Bearer token-b")
        XCTAssertFalse(queuedCreateUserExternalIds().contains(userA_EUID))
    }

    /// A failure the token cannot fix still stops the queue, since the user will never exist this session.
    func testACreateUserThatFailsForAnotherReasonStillPausesTheRepo() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        client.setMockFailureResponseForRequest(
            request: "<OSRequestCreateUser with external_id: \(userA_EUID)>",
            error: OneSignalClientError(code: 400, message: "bad-request", responseHeaders: nil, response: nil, underlyingError: nil)
        )

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertTrue(OneSignalUserManagerImpl.sharedInstance.operationRepo.paused)
    }

    // MARK: - logout

    func testLogoutUnderIdentityVerificationSilencesThePushSubscriptionAndReportsNoUser() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        optInPushSubscription()
        observer.states.removeAll()

        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        let payload = pushSubscriptionPayload()
        XCTAssertEqual(payload["enabled"] as? Bool, false)
        XCTAssertEqual(payload["notification_types"] as? Int, -2)
        // The replacement anonymous user is never created on the server, so nothing else would report it.
        XCTAssertEqual(observer.states.count, 1)
        XCTAssertNil(observer.states.first?.onesignalId)
        XCTAssertNil(observer.states.first?.externalId)
    }

    /// The silencing has to be stamped with the user being logged out. An anonymous Update Subscription is
    /// dropped for having no `external_id`, and the server would never learn the device stopped listening.
    func testLogoutStampsTheSilencedPushSubscriptionWithTheOutgoingUser() throws {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        optInPushSubscription()
        // Deltas have to stay in the repo queue long enough to be inspected.
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true

        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertEqual(try XCTUnwrap(silencingDelta()).externalId, userA_EUID)
    }

    /// Only the reported payload changes, so a later `login` can restore what the app asked for.
    func testLogoutUnderIdentityVerificationLeavesTheAppsOptInAlone() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        let pushSubscription = optInPushSubscription()

        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertFalse(pushSubscription._isDisabled)
        XCTAssertEqual(pushSubscription.notificationTypes, optedInNotificationTypes)
        XCTAssertTrue(pushSubscription.optedIn)
    }

    func testLogoutWhileIdentityVerificationIsOffLeavesThePushSubscriptionReporting() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        optInPushSubscription()

        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertEqual(pushSubscriptionPayload()["notification_types"] as? Int, optedInNotificationTypes)
    }

    /// 404 recovery replaces a user the server no longer has; the device should keep reporting through it.
    func testInternalLogoutLeavesThePushSubscriptionReportingUnderIdentityVerification() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        optInPushSubscription()

        OneSignalUserManagerImpl.sharedInstance._logout()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertEqual(pushSubscriptionPayload()["notification_types"] as? Int, optedInNotificationTypes)
    }

    func testLoggingBackInRestoresThePushSubscription() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        optInPushSubscription()
        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertEqual(pushSubscriptionPayload()["notification_types"] as? Int, optedInNotificationTypes)
    }

    /// A device left logged out across a restart has to stay silenced, otherwise the next device-property
    /// change would re-enable the logged-out user's subscription.
    func testAnInternallyDisabledPushSubscriptionSurvivesArchiving() throws {
        let model = OSSubscriptionModel(type: .push, address: "push-token", subscriptionId: testPushSubId, reachable: true, isDisabled: false, changeNotifier: OSEventProducer())
        model.notificationTypes = optedInNotificationTypes
        model._isDisabledInternally = true

        let data = try NSKeyedArchiver.archivedData(withRootObject: model, requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        defer { unarchiver.finishDecoding() }
        let decoded = try XCTUnwrap(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? OSSubscriptionModel)

        XCTAssertTrue(decoded._isDisabledInternally)
        XCTAssertEqual(decoded.jsonRepresentation()["notification_types"] as? Int, -2)
    }

    /// `login` is otherwise the only thing that clears the internal disable, which would leave an app that
    /// turns Identity Verification off while logged out silenced until the next one.
    func testTurningIdentityVerificationOffRestoresAnInternallyDisabledPushSubscription() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)
        optInPushSubscription()
        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        XCTAssertEqual(pushSubscriptionPayload()["notification_types"] as? Int, optedInNotificationTypes)
    }
}
