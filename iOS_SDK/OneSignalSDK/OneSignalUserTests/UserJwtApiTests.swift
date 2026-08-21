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
 Goes through `sharedInstance` because the JWT config and IV service are shared.

 Asks are driven through `userJwtRepo` the way a rejected Request is: there is no public invalidate API.
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

    /// Parks the token and asks the app the way a 401 on a user Request does.
    @discardableResult
    private func invalidate(externalId: String, rejectedToken: String) -> Bool {
        return OneSignalUserManagerImpl.sharedInstance.userJwtRepo.invalidateJwt(
            externalId: externalId,
            rejectedToken: rejectedToken
        )
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

    // MARK: - Invalidated listener

    func testInvalidatingAJwtParksTheTokenAndNotifiesTheApp() {
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        invalidate(externalId: "user-a", rejectedToken: "token-a")
        drainMainQueue()

        XCTAssertNil(user.identityModel.getValidJwt())
        XCTAssertEqual(listener.invalidatedExternalIds, ["user-a"])
    }

    /// Several requests can be rejected before the app supplies a new token; asking it once is enough.
    func testInvalidatingAJwtTwiceNotifiesOnce() {
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        invalidate(externalId: "user-a", rejectedToken: "token-a")
        invalidate(externalId: "user-a", rejectedToken: "token-a")
        drainMainQueue()

        XCTAssertEqual(listener.invalidatedExternalIds, ["user-a"])
    }

    func testARemovedListenerIsNotNotified() {
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"
        OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(listener)

        invalidate(externalId: "user-a", rejectedToken: "token-a")
        drainMainQueue()

        XCTAssertTrue(listener.invalidatedExternalIds.isEmpty)
    }

    /// An ask that fires before the app registers still has to reach a late listener.
    func testAListenerAddedAfterAnAskStillHearsWhoOwesAToken() {
        OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(listener)
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        invalidate(externalId: "user-a", rejectedToken: "token-a")
        drainMainQueue()
        XCTAssertTrue(listener.invalidatedExternalIds.isEmpty)

        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(listener)
        drainMainQueue()

        XCTAssertEqual(listener.invalidatedExternalIds, ["user-a"])
    }

    /// A token that lands before the late listener is delivered must not be asked for again.
    func testALateListenerIsNotToldAboutAnAskThatWasAlreadyAnswered() {
        OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(listener)
        let user = OneSignalUserMocks.setUserManagerInternalUser(externalId: "user-a", onesignalId: "osid-a")
        user.identityModel.jwtBearerToken = "token-a"

        invalidate(externalId: "user-a", rejectedToken: "token-a")
        OneSignalUserManagerImpl.sharedInstance.updateUserJwt(externalId: "user-a", token: "token-b")

        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(listener)
        drainMainQueue()

        XCTAssertTrue(listener.invalidatedExternalIds.isEmpty)
    }
}
