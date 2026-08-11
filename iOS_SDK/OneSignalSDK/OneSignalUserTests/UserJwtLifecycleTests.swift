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
        // The mock answers 50ms late, so a Request still in flight would otherwise land mid-next-test
        // and hydrate the shared models and JWT repo out from under it.
        OneSignalCoreMocks.waitUntil("A Request was still in flight at teardown") { self.clientIsIdle }
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

    // MARK: - Waits

    private var clientIsIdle: Bool {
        return client.completedRequests.count == client.startedRequests.count
    }

    /**
     Tests opt the push subscription in and count observer states after this returns, so it has to
     outlast every effect of the login. The mock records a Request as completed only once the response
     handler has returned, so nothing in flight means the hydration it drives has already run.

     A response can also start a follow-up Request, and the mock answers each one 50ms later, so an
     idle client is only meaningful once it has stayed idle longer than that.
     */
    private func waitForTheLoginToSettle() {
        OneSignalCoreMocks.waitUntil("The login did not reach a reported user") {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.onesignalId != nil
                && self.observer.states.contains { $0.onesignalId != nil }
                && self.clientIsIdle
        }
        allowAsyncWorkToRun(seconds: 0.1)
        OneSignalCoreMocks.waitUntil("The login left a Request in flight") { self.clientIsIdle }
    }

    private func waitForThePushSubscriptionToBeSilenced() {
        OneSignalCoreMocks.waitUntil("The push subscription was not silenced") {
            self.pushSubscriptionPayload()["notification_types"] as? Int == -2
        }
    }

    /// The logged-out state reaching the app, which is the last thing `logout()` does.
    private func waitForTheUserStateToBeReported() {
        OneSignalCoreMocks.waitUntil("The logged-out state was not reported") {
            self.observer.states.count == 1
        }
    }

    private func waitForThePushSubscriptionToReportAgain() {
        OneSignalCoreMocks.waitUntil("The push subscription did not report the app's opt-in again") {
            self.pushSubscriptionPayload()["notification_types"] as? Int == self.optedInNotificationTypes
        }
    }

    // MARK: - login

    func testLoginFromAnonymousPromotesTheUserWhileIdentityVerificationIsOff() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        _ = OneSignalUserManagerImpl.sharedInstance.user // anonymous user first

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitUntil("Identify User was not sent") {
            self.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self)
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
    }

    /// Identify User adds an `external_id` to an anonymous user, which Identity Verification does not allow.
    func testLoginFromAnonymousCreatesANewUserWhileIdentityVerificationIsRequired() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        _ = OneSignalUserManagerImpl.sharedInstance.user

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        OneSignalCoreMocks.waitUntil("Create User was not sent") {
            self.client.hasExecutedRequestOfType(OSRequestCreateUser.self)
        }

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
        OneSignalCoreMocks.waitUntil("The promotion was not queued") {
            self.queuedUserRequests().contains { $0 is OSRequestIdentifyUser }
        }

        XCTAssertTrue(queuedUserRequests().contains { $0 is OSRequestIdentifyUser })
        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestCreateUser.self))

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalCoreMocks.waitUntil("Hydration did not release the promotion as a Create User") {
            self.client.hasExecutedRequestOfType(OSRequestCreateUser.self, expectedCount: 1)
        }

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
        OneSignalCoreMocks.waitUntil("The promotion was not queued") {
            self.queuedUserRequests().contains { $0 is OSRequestIdentifyUser }
        }

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalCoreMocks.waitUntil("Hydration did not release the promotion") {
            self.client.hasExecutedRequestOfType(OSRequestIdentifyUser.self)
        }

        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestIdentifyUser.self))
    }

    /// With the rollout flag off, an unknown requirement has to behave exactly as it did before Identity
    /// Verification existed.
    func testLoginFromAnonymousPromotesTheUserWhileTheRequirementIsUnknownAndTheFlagIsOff() {
        makeRequirementUnknown()
        _ = OneSignalUserManagerImpl.sharedInstance.user

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitUntil("The promotion was not queued") {
            self.queuedUserRequests().contains { $0 is OSRequestIdentifyUser }
        }

        XCTAssertTrue(queuedUserRequests().contains { $0 is OSRequestIdentifyUser })
        XCTAssertFalse(queuedCreateUserExternalIds().contains(userA_EUID))
    }

    /// Re-logging in is how an app hands over a replacement token.
    func testLoggingInAgainAsTheSameUserStoresTheNewToken() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        waitForTheLoginToSettle()

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-b")

        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.userJwtRepo.validJwt(externalId: userA_EUID), "token-b")
    }

    /// A token supplied by `login` answers the ask the same way `updateUserJwt` does, so a later rejection
    /// can ask again. An ask left standing would silence the app for the rest of the session.
    func testLoggingInWithATokenAnswersAPendingAskForThatUser() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        let jwtRepo = OneSignalUserManagerImpl.sharedInstance.userJwtRepo

        // The Create User parks for want of a token, which asks the app once. Asking is what the
        // assertion reads, so it cannot be polled: the first poll would consume the pending ask.
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        allowAsyncWorkToRun()
        XCTAssertFalse(jwtRepo.askForToken(externalId: userA_EUID))

        // Log back in as the same user, which builds a new Identity Model rather than reusing the parked one.
        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        // Rejecting the token reads the Identity Model the login hydrates, so let the login finish
        // rather than stopping at the point the token is merely stored.
        waitForTheLoginToSettle()
        OneSignalCoreMocks.waitUntil("The replacement token was not stored") {
            jwtRepo.validJwt(externalId: userA_EUID) == "token-a"
        }

        XCTAssertEqual(jwtRepo.validJwt(externalId: userA_EUID), "token-a")
        // `true` means this rejection reached the app, which only happens once the earlier ask was answered.
        XCTAssertTrue(jwtRepo.invalidateJwt(externalId: userA_EUID, rejectedToken: "token-a"))
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
        // Handling the 401 parks the Request first and drops the rejected token after, so wait for both.
        OneSignalCoreMocks.waitUntil("The 401 was not fully handled") {
            self.queuedCreateUserExternalIds().contains(userA_EUID)
                && OneSignalUserManagerImpl.sharedInstance.userJwtRepo.validJwt(externalId: userA_EUID) == nil
        }

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
        OneSignalCoreMocks.waitUntil("The rejected Create User was not parked") {
            self.client.hasExecutedRequestOfType(OSRequestCreateUser.self, expectedCount: 1)
                && self.queuedCreateUserExternalIds().contains(userA_EUID)
        }
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestCreateUser.self, expectedCount: 1))

        // The token the app mints in answer to the invalidated event, which the server accepts.
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userA_EUID)
        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: "token-b")
        // Accepting the retry is what takes it out of the queue, which happens after the send.
        OneSignalCoreMocks.waitUntil("The held Create User was not re-sent and accepted") {
            self.client.hasExecutedRequestOfType(OSRequestCreateUser.self, expectedCount: 2)
                && !self.queuedCreateUserExternalIds().contains(userA_EUID)
        }

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
        OneSignalCoreMocks.waitUntil("The failure did not pause the Repo") {
            OneSignalUserManagerImpl.sharedInstance.operationRepo.paused
        }

        XCTAssertTrue(OneSignalUserManagerImpl.sharedInstance.operationRepo.paused)
    }

    // MARK: - logout

    func testLogoutUnderIdentityVerificationSilencesThePushSubscriptionAndReportsNoUser() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        waitForTheLoginToSettle()
        optInPushSubscription()
        observer.states.removeAll()

        OneSignalUserManagerImpl.sharedInstance.logout()
        // Observers are told after the subscription is silenced, so this is the later of the two.
        waitForTheUserStateToBeReported()

        let payload = pushSubscriptionPayload()
        XCTAssertEqual(payload["enabled"] as? Bool, false)
        XCTAssertEqual(payload["notification_types"] as? Int, -2)
        // The replacement anonymous user is never created on the server, so nothing else would report it.
        XCTAssertEqual(observer.states.count, 1)
        XCTAssertNil(observer.states.first?.onesignalId)
        XCTAssertNil(observer.states.first?.externalId)
    }

    /// The silencing has to be stamped with the user being logged out so the unsubscribe is attributed to
    /// them rather than the anonymous replacement.
    func testLogoutStampsTheSilencedPushSubscriptionWithTheOutgoingUser() throws {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        waitForTheLoginToSettle()
        optInPushSubscription()
        // Deltas have to stay in the repo queue long enough to be inspected.
        OneSignalUserManagerImpl.sharedInstance.operationRepo.paused = true

        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalCoreMocks.waitUntil("The silencing Delta was not queued") {
            self.silencingDelta() != nil
        }

        XCTAssertEqual(try XCTUnwrap(silencingDelta()).externalId, userA_EUID)
    }

    /// Only the reported payload changes, so a later `login` can restore what the app asked for.
    func testLogoutUnderIdentityVerificationLeavesTheAppsOptInAlone() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        waitForTheLoginToSettle()
        let pushSubscription = optInPushSubscription()

        OneSignalUserManagerImpl.sharedInstance.logout()
        // The reported payload is what logout changes, so it marks the point the model must not have.
        waitForThePushSubscriptionToBeSilenced()

        XCTAssertFalse(pushSubscription._isDisabled)
        XCTAssertEqual(pushSubscription.notificationTypes, optedInNotificationTypes)
        XCTAssertTrue(pushSubscription.optedIn)
    }

    func testLogoutWhileIdentityVerificationIsOffLeavesThePushSubscriptionReporting() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        waitForTheLoginToSettle()
        optInPushSubscription()

        OneSignalUserManagerImpl.sharedInstance.logout()
        // Nothing to poll for: the assertion is that logout left the reported payload alone.
        allowAsyncWorkToRun()

        XCTAssertEqual(pushSubscriptionPayload()["notification_types"] as? Int, optedInNotificationTypes)
    }

    /// While the requirement is unknown, silence: the false positive is undone by hydrate-to-off, and the
    /// other guess would keep delivering the logged-out user's pushes.
    func testLogoutWhileIdentityVerificationIsUnknownSilencesThePushSubscription() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        waitForTheLoginToSettle()
        optInPushSubscription()
        observer.states.removeAll()
        makeRequirementUnknown()

        OneSignalUserManagerImpl.sharedInstance.logout()
        waitForTheUserStateToBeReported()

        let payload = pushSubscriptionPayload()
        XCTAssertEqual(payload["enabled"] as? Bool, false)
        XCTAssertEqual(payload["notification_types"] as? Int, -2)
        XCTAssertEqual(observer.states.count, 1)
        XCTAssertNil(observer.states.first?.onesignalId)
        XCTAssertNil(observer.states.first?.externalId)
    }

    /// The unknown-logout guess over-silences if the app does not require Identity Verification; hydrate
    /// has to undo it the same way it undoes an on→off flip while logged out.
    func testLogoutWhileIdentityVerificationIsUnknownThenOffRestoresThePushSubscription() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        waitForTheLoginToSettle()
        optInPushSubscription()
        makeRequirementUnknown()
        OneSignalUserManagerImpl.sharedInstance.logout()
        waitForThePushSubscriptionToBeSilenced()

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        waitForThePushSubscriptionToReportAgain()

        XCTAssertEqual(pushSubscriptionPayload()["notification_types"] as? Int, optedInNotificationTypes)
    }

    /// 404 recovery replaces a user the server no longer has; the device should keep reporting through it.
    func testInternalLogoutLeavesThePushSubscriptionReportingUnderIdentityVerification() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        waitForTheLoginToSettle()
        optInPushSubscription()

        OneSignalUserManagerImpl.sharedInstance._logout()
        // Nothing to poll for: the assertion is that 404 recovery left the reported payload alone.
        allowAsyncWorkToRun()

        XCTAssertEqual(pushSubscriptionPayload()["notification_types"] as? Int, optedInNotificationTypes)
    }

    func testLoggingBackInRestoresThePushSubscription() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        waitForTheLoginToSettle()
        optInPushSubscription()
        OneSignalUserManagerImpl.sharedInstance.logout()
        waitForThePushSubscriptionToBeSilenced()

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        waitForThePushSubscriptionToReportAgain()

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
    /// turns Identity Verification off while logged out — or one whose logout guessed on while the
    /// requirement was still unknown — silenced until the next login.
    func testTurningIdentityVerificationOffRestoresAnInternallyDisabledPushSubscription() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "token-a")
        waitForTheLoginToSettle()
        optInPushSubscription()
        OneSignalUserManagerImpl.sharedInstance.logout()
        waitForThePushSubscriptionToBeSilenced()

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        waitForThePushSubscriptionToReportAgain()

        XCTAssertEqual(pushSubscriptionPayload()["notification_types"] as? Int, optedInNotificationTypes)
    }
}
