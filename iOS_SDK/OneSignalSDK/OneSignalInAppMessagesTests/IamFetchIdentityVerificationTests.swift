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
import OneSignalOSCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
import OneSignalInAppMessagesMocks
@testable import OneSignalUser

/**
 How the in-app message fetch is addressed and signed. It does not travel through the Request queues, so
 it makes the Identity Verification decision itself and holds the fetch until the answer arrives.
 */
final class IamFetchIdentityVerificationTests: XCTestCase {
    private let appId = "test-app-id"

    private var client = MockOneSignalClient()
    private var jwtListener = MockUserJwtInvalidatedListener()

    private var legacyPath: String { "apps/\(appId)/subscriptions/\(testPushSubId)/iams" }
    private var anonymousUserPath: String { userPath(alias: OS_ONESIGNAL_ID, id: anonUserOSID) }
    private var identifiedUserPath: String { userPath(alias: OS_EXTERNAL_ID, id: userA_EUID) }

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        ConsistencyManagerTestHelpers.reset()
        OSMessagingController.removeInstance()
        OneSignalIdentifiers.currentAppId = appId

        client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userA_EUID)
        OneSignalCoreImpl.setSharedClient(client)
        for path in [legacyPath, anonymousUserPath, identifiedUserPath] {
            respondToFetch(from: path)
        }

        // Held strongly for the test's lifetime: the observable keeps listeners weakly.
        jwtListener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(jwtListener)

        OSMessagingController.start()
    }

    override func tearDownWithError() throws {
        OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(jwtListener)
        OSMessagingController.removeInstance()
        OSFeatureManager.shared.setEnabledFeatureKeys([])
        OneSignalCoreMocks.clearUserDefaults()
    }

    // MARK: - Setup helpers

    private func userPath(alias: String, id: String) -> String {
        return "apps/\(appId)/users/by/\(alias)/\(id)/subscriptions/\(testPushSubId)/iams"
    }

    private func respondToFetch(from path: String) {
        client.setMockResponseForRequest(
            request: "<OSRequestGetInAppMessages from \(path)>",
            response: IAMTestHelpers.testFetchMessagesResponse(messages: []))
    }

    private func rejectFetch(from path: String) {
        client.setMockFailureResponseForRequest(
            request: "<OSRequestGetInAppMessages from \(path)>",
            error: OneSignalClientError(code: 401, message: "unauthorized", responseHeaders: nil, response: nil, underlyingError: nil))
    }

    private func turnOnTheRolloutFlag() {
        OSFeatureManager.shared.setEnabledFeatureKeys([OSFeatureFlag.identityVerification.rawValue])
    }

    /**
     Nothing in flight. The mock records a Request as completed only once its response handler has
     returned, so this also means the hydration a response drives has already run.

     Tests baseline their fetch counts on whatever the setup below left behind, so the setup has to be
     finished sending before they start counting.
     */
    private var clientIsIdle: Bool {
        return client.completedRequests.count == client.startedRequests.count
    }

    /// An anonymous user with an `onesignal_id`, which the fetch needs before it does anything else.
    private func startAnonymousUser() {
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: anonUserOSID)
        OneSignalUserManagerImpl.sharedInstance.start()
        OneSignalCoreMocks.waitUntil("The anonymous user was not created") {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.onesignalId != nil && self.clientIsIdle
        }
    }

    private func login(token: String?) {
        ConsistencyManagerTestHelpers.setDefaultRywToken(id: userA_OSID)
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: token)
        OneSignalCoreMocks.waitUntil("The login did not reach a hydrated user") {
            OneSignalUserManagerImpl.sharedInstance.user.identityModel.onesignalId != nil && self.clientIsIdle
        }
    }

    /// The fetch reaching the server and its response being handled, which covers a rejected one too.
    private func fetch() {
        let answeredBefore = completedFetches().count
        OneSignalInAppMessages.getFromServer(testPushSubId)
        OneSignalCoreMocks.waitUntil("The fetch was not answered") {
            self.completedFetches().count > answeredBefore
        }
    }

    /// A fetch Identity Verification holds, which parks the subscription id instead of sending.
    private func fetchThatIsHeld() {
        OneSignalInAppMessages.getFromServer(testPushSubId)
        OneSignalCoreMocks.waitUntil("The fetch was not held") {
            self.deferredSubscriptionId() == testPushSubId
        }
    }

    // MARK: - Assertion helpers

    private func executedFetches() -> [OneSignalRequest] {
        return client.executedRequests.filter { $0 is OSRequestGetInAppMessages }
    }

    private func completedFetches() -> [OneSignalRequest] {
        return client.completedRequests.filter { $0 is OSRequestGetInAppMessages }
    }

    private func lastFetchPath() -> String? {
        return executedFetches().last?.path
    }

    private func lastFetchAuthorization() -> String? {
        return executedFetches().last?.additionalHeaders?["Authorization"]
    }

    private func deferredSubscriptionId() -> String? {
        return OSMessagingController.sharedInstance().deferredFetchSubscriptionId
    }

    // MARK: - How the fetch is addressed

    func testTheFetchAddressesTheSubscriptionAloneWhileTheNewCodePathsAreOff() {
        startAnonymousUser()

        fetch()

        XCTAssertEqual(lastFetchPath(), legacyPath)
        XCTAssertNil(lastFetchAuthorization())
    }

    func testTheFetchAddressesTheOnesignalIdWhileIdentityVerificationIsOff() {
        turnOnTheRolloutFlag()
        startAnonymousUser()

        fetch()

        XCTAssertEqual(lastFetchPath(), anonymousUserPath)
        XCTAssertNil(lastFetchAuthorization())
    }

    func testTheFetchAddressesTheExternalIdAndIsSignedUnderIdentityVerification() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        login(token: "token-a")

        fetch()

        XCTAssertEqual(lastFetchPath(), identifiedUserPath)
        XCTAssertEqual(lastFetchAuthorization(), "Bearer token-a")
    }

    // MARK: - Holding the fetch until Identity Verification answers

    /// An unsigned fetch on behalf of an app that turns out to require auth would be rejected, so a fetch
    /// that runs before remote params answer waits for them — including when the rollout flag is off.
    func testAFetchHeldForAnUnknownRequirementGoesOutOnHydration() {
        startAnonymousUser()
        let fetchesBefore = executedFetches().count
        OSCoreMocks.resetSharedJwtConfig()

        fetchThatIsHeld()

        XCTAssertEqual(executedFetches().count, fetchesBefore)
        XCTAssertEqual(deferredSubscriptionId(), testPushSubId)

        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        OneSignalCoreMocks.waitUntil("Hydration did not release the held fetch") {
            self.deferredSubscriptionId() == nil && self.executedFetches().count > fetchesBefore
        }

        XCTAssertEqual(lastFetchPath(), legacyPath)
        XCTAssertNil(deferredSubscriptionId())
    }

    /// A user whose token was rejected has none until the app supplies another, and the fetch has to wait
    /// rather than fall back to sending unsigned.
    func testAFetchIsHeldRatherThanSentUnsignedWhenTheUserHasNoToken() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        login(token: "token-a")
        OneSignalUserManagerImpl.sharedInstance.userJwtRepo.invalidateJwt(externalId: userA_EUID, rejectedToken: "token-a")
        let fetchesBefore = executedFetches().count

        fetchThatIsHeld()

        XCTAssertEqual(executedFetches().count, fetchesBefore)
        XCTAssertEqual(deferredSubscriptionId(), testPushSubId)

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: "token-b")
        OneSignalCoreMocks.waitUntil("The replacement token did not release the held fetch") {
            self.executedFetches().count > fetchesBefore
        }

        XCTAssertEqual(lastFetchPath(), identifiedUserPath)
        XCTAssertEqual(lastFetchAuthorization(), "Bearer token-b")
    }

    // MARK: - A rejected fetch

    /// The fetch is not a source of truth for whether a token is good, because the server can refuse it
    /// over a user and subscription it does not have paired. It parks, and the next token releases it.
    func testARejectedFetchParksWithoutReportingTheTokenItUsed() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        login(token: "token-a")
        rejectFetch(from: identifiedUserPath)
        let fetchesBefore = executedFetches().count

        fetch()

        XCTAssertEqual(executedFetches().count, fetchesBefore + 1)
        XCTAssertEqual(jwtListener.invalidatedExternalIds, [])
        XCTAssertEqual(deferredSubscriptionId(), testPushSubId)

        // A token the app supplies for its own reasons, since the fetch never asked for one.
        respondToFetch(from: identifiedUserPath)
        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: userA_EUID, token: "token-b")
        OneSignalCoreMocks.waitUntil("The replacement token did not release the parked fetch") {
            self.executedFetches().count == fetchesBefore + 2
        }

        XCTAssertEqual(executedFetches().count, fetchesBefore + 2)
        XCTAssertEqual(lastFetchAuthorization(), "Bearer token-b")
    }

    /// The token the fetch was signed with stays usable, so everything else keeps going out signed.
    func testARejectedFetchLeavesTheTokenInPlaceForTheRequests() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        login(token: "token-a")
        rejectFetch(from: identifiedUserPath)

        fetch()

        XCTAssertEqual(lastFetchAuthorization(), "Bearer token-a")
        XCTAssertEqual(OneSignalUserManagerImpl.sharedInstance.user.identityModel.jwtBearerToken, "token-a")
    }

    /// With the gate off a 401 stays as it was: logged and dropped, with no reattempt left pending.
    func testARejectedFetchIsLeftAloneWhileTheNewCodePathsAreOff() {
        startAnonymousUser()
        rejectFetch(from: legacyPath)
        let fetchesBefore = executedFetches().count

        fetch()

        XCTAssertEqual(executedFetches().count, fetchesBefore + 1)
        XCTAssertNil(deferredSubscriptionId())
    }

    /// Under Identity Verification the alias id is an app-chosen external_id, so it has to be encoded.
    func testTheFetchPathPercentEncodesTheAliasId() {
        OneSignalIdentifiers.currentAppId = appId
        let externalId = "us er/a?b#c%d"
        let request = OSRequestGetInAppMessages.withSubscriptionId(
            testPushSubId,
            withAlias: OSAliasPair(OS_EXTERNAL_ID, externalId),
            withUserHeaders: nil,
            withSessionDuration: 0,
            withRetryCount: 0,
            withRywToken: nil
        )

        XCTAssertEqual(
            request.path,
            "apps/\(appId)/users/by/\(OS_EXTERNAL_ID)/us%20er%2Fa%3Fb%23c%25d/subscriptions/\(testPushSubId)/iams"
        )
    }
}
