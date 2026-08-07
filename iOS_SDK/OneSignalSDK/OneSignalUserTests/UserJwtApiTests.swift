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

/**
 Public JWT surface on the User Manager: store a token, and tell the app when it stopped being accepted.
 Goes through `sharedInstance` because the JWT config and IV service are shared; `OneSignalUserMocks.reset()`
 leaves the requirement at `off`, so IV tests hydrate it on.
 */
final class UserJwtApiTests: XCTestCase {

    private var listener = MockUserJwtInvalidatedListener()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"
        OneSignalCoreImpl.setSharedClient(MockOneSignalClient())

        // Held strongly for the test's lifetime: OSObservable keeps observers weakly.
        listener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(listener)
    }

    override func tearDownWithError() throws {
        OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(listener)
        OneSignalCoreMocks.clearUserDefaults()
    }

    /// `OSObservable` delivers on the main queue, so a block enqueued after the notification runs
    /// once the notification has — deterministic, rather than waiting out a timeout.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        waitForExpectations(timeout: 5)
    }

    // MARK: - updateUserJwt

    func testUpdateUserJwtStoresTheTokenOnThatUsersIdentityModel() {
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: "user-a", token: "token-a")

        XCTAssertEqual(user.identityModel.getValidJwt(), "token-a")
    }

    func testUpdateUserJwtForAnUnknownExternalIdLeavesTheCurrentUserAlone() {
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: "user-b", token: "token-b")

        XCTAssertNil(user.identityModel.jwtBearerToken)
    }

    /// An empty token reads as no token at all, so it would leave the user unable to sign a request
    /// and unable to be asked for another one.
    func testUpdateUserJwtWithAnEmptyTokenLeavesThePreviousTokenInPlace() {
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: "user-a", token: "")

        XCTAssertEqual(user.identityModel.getValidJwt(), "token-a")
    }

    /// Storing the sentinel would look like an already-invalidated token, so the app is never asked again.
    func testUpdateUserJwtWithTheInvalidSentinelIsRejected() {
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")

        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: "user-a", token: OS_JWT_TOKEN_INVALID)

        XCTAssertNil(user.identityModel.jwtBearerToken)
    }

    // MARK: - invalidateJwtForExternalId

    func testInvalidatingAJwtParksTheTokenAndNotifiesTheApp() {
        OSUserJwtConfig.shared.hydrate(requiresUserAuth: true)
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: "user-a")
        drainMainQueue()

        XCTAssertNil(user.identityModel.getValidJwt())
        XCTAssertEqual(listener.invalidatedExternalIds, ["user-a"])
    }

    /// Several requests can be rejected before the app supplies a new token; asking it once is enough.
    func testInvalidatingAJwtTwiceNotifiesOnce() {
        OSUserJwtConfig.shared.hydrate(requiresUserAuth: true)
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: "user-a")
        OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: "user-a")
        drainMainQueue()

        XCTAssertEqual(listener.invalidatedExternalIds, ["user-a"])
    }

    /// Repeated logins as the same user leave more than one Identity Model carrying that external ID.
    /// Every one has to be parked, but the app only needs to be asked for a replacement once.
    func testInvalidatingAJwtParksEveryModelForThatUserAndNotifiesOnce() {
        OSUserJwtConfig.shared.hydrate(requiresUserAuth: true)
        let first = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        let second = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        first.identityModel.jwtBearerToken = "token-a"
        second.identityModel.jwtBearerToken = "token-a"

        OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: "user-a")
        drainMainQueue()

        XCTAssertNil(first.identityModel.getValidJwt())
        XCTAssertNil(second.identityModel.getValidJwt())
        XCTAssertEqual(listener.invalidatedExternalIds, ["user-a"])
    }

    func testInvalidatingAJwtDoesNothingWhenIdentityVerificationIsOff() {
        OSUserJwtConfig.shared.hydrate(requiresUserAuth: false)
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: "user-a")
        drainMainQueue()

        XCTAssertEqual(user.identityModel.getValidJwt(), "token-a")
        XCTAssertTrue(listener.invalidatedExternalIds.isEmpty)
    }

    /// Nothing should be sent unsigned, or reported as rejected, before remote params answer.
    func testInvalidatingAJwtDoesNothingWhileTheRequirementIsUnknown() {
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: "user-a")
        drainMainQueue()

        XCTAssertEqual(user.identityModel.getValidJwt(), "token-a")
        XCTAssertTrue(listener.invalidatedExternalIds.isEmpty)
    }

    func testInvalidatingAJwtForAnUnknownExternalIdNotifiesNobody() {
        OSUserJwtConfig.shared.hydrate(requiresUserAuth: true)
        OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")

        OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: "user-b")
        drainMainQueue()

        XCTAssertTrue(listener.invalidatedExternalIds.isEmpty)
    }

    func testARemovedListenerIsNotNotified() {
        OSUserJwtConfig.shared.hydrate(requiresUserAuth: true)
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"
        OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(listener)

        OneSignalUserManagerImpl.sharedInstance.invalidateJwtForExternalId(externalId: "user-a")
        drainMainQueue()

        XCTAssertTrue(listener.invalidatedExternalIds.isEmpty)
    }
}
