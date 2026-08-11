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

/// Covers the repo's external-ID lookups. The repo is constructible, so these build their own
/// instance rather than reaching through the User Manager's shared one.
final class OSIdentityModelRepoTests: XCTestCase {

    private var repo = OSIdentityModelRepo()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        repo = OSIdentityModelRepo()
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    @discardableResult
    private func addModel(externalId: String?) -> OSIdentityModel {
        let aliases = externalId.map { [OS_EXTERNAL_ID: $0] }
        let model = OSIdentityModel(aliases: aliases, changeNotifier: OSEventProducer())
        repo.add(model: model)
        return model
    }

    // MARK: - get(externalId:)

    func testGetByExternalIdFindsTheMatchingModel() {
        addModel(externalId: "user-a")
        let userB = addModel(externalId: "user-b")

        XCTAssertIdentical(repo.get(externalId: "user-b"), userB)
    }

    func testGetByExternalIdReturnsNilWhenNoModelMatches() {
        addModel(externalId: "user-a")

        XCTAssertNil(repo.get(externalId: "user-b"))
    }

    /// Anonymous users have no external ID, and must not be matched by one.
    func testGetByExternalIdSkipsAnonymousModels() {
        addModel(externalId: nil)

        XCTAssertNil(repo.get(externalId: "user-a"))
    }

    // MARK: - updateJwtToken

    func testUpdateJwtTokenWritesTheTokenOntoTheMatchingModel() {
        let userA = addModel(externalId: "user-a")

        repo.updateJwtToken(externalId: "user-a", token: "token-a")

        XCTAssertEqual(userA.jwtBearerToken, "token-a")
    }

    /// Repeated logins as the same user can leave more than one model carrying that external ID;
    /// a token that only reaches one of them would leave the others stuck on a rejected token.
    func testUpdateJwtTokenWritesToEveryModelWithThatExternalId() {
        let first = addModel(externalId: "user-a")
        let second = addModel(externalId: "user-a")

        repo.updateJwtToken(externalId: "user-a", token: "token-a")

        XCTAssertEqual(first.jwtBearerToken, "token-a")
        XCTAssertEqual(second.jwtBearerToken, "token-a")
    }

    func testUpdateJwtTokenLeavesOtherUsersAlone() {
        let userA = addModel(externalId: "user-a")
        let userB = addModel(externalId: "user-b")

        repo.updateJwtToken(externalId: "user-a", token: "token-a")

        XCTAssertEqual(userA.jwtBearerToken, "token-a")
        XCTAssertNil(userB.jwtBearerToken)
    }

    /// A token supplied for a user the SDK has never seen is dropped rather than applied to whoever
    /// happens to be current.
    func testUpdateJwtTokenForAnUnknownExternalIdChangesNothing() {
        let userA = addModel(externalId: "user-a")

        repo.updateJwtToken(externalId: "user-b", token: "token-b")

        XCTAssertNil(userA.jwtBearerToken)
    }

    func testUpdateJwtTokenReplacesTheInvalidSentinel() {
        let userA = addModel(externalId: "user-a")
        userA.invalidateJwtBearerToken(rejectedToken: "token-a")

        repo.updateJwtToken(externalId: "user-a", token: "fresh-token")

        XCTAssertEqual(userA.getValidJwt(), "fresh-token")
    }

    // MARK: - validJwt

    func testValidJwtReturnsTheStoredToken() {
        let userA = addModel(externalId: "user-a")
        userA.jwtBearerToken = "token-a"

        XCTAssertEqual(repo.validJwt(externalId: "user-a"), "token-a")
    }

    func testValidJwtIsNilForAnUnknownExternalIdAndForAParkedToken() {
        let userA = addModel(externalId: "user-a")
        userA.jwtBearerToken = "token-a"

        XCTAssertNil(repo.validJwt(externalId: "user-b"))

        repo.invalidateJwtToken(externalId: "user-a", rejectedToken: "token-a")
        XCTAssertNil(repo.validJwt(externalId: "user-a"))
    }

    // MARK: - invalidateJwtToken

    /// A model left unparked would keep signing requests with a token the server already rejected.
    func testInvalidateJwtTokenParksEveryModelWithThatExternalId() {
        let first = addModel(externalId: "user-a")
        let second = addModel(externalId: "user-a")
        first.jwtBearerToken = "token-a"
        second.jwtBearerToken = "token-a"

        repo.invalidateJwtToken(externalId: "user-a", rejectedToken: "token-a")

        XCTAssertNil(first.getValidJwt())
        XCTAssertNil(second.getValidJwt())
    }

    /// A login that landed while the rejected request was in flight leaves a newer token behind.
    func testInvalidateJwtTokenLeavesAModelHoldingADifferentToken() {
        let stale = addModel(externalId: "user-a")
        let fresh = addModel(externalId: "user-a")
        stale.jwtBearerToken = "token-a"
        fresh.jwtBearerToken = "token-b"

        repo.invalidateJwtToken(externalId: "user-a", rejectedToken: "token-a")

        XCTAssertNil(stale.getValidJwt())
        XCTAssertEqual(fresh.getValidJwt(), "token-b")
    }

    func testInvalidateJwtTokenLeavesOtherUsersAlone() {
        let userA = addModel(externalId: "user-a")
        let userB = addModel(externalId: "user-b")
        userA.jwtBearerToken = "token-a"
        userB.jwtBearerToken = "token-a"

        repo.invalidateJwtToken(externalId: "user-a", rejectedToken: "token-a")

        XCTAssertEqual(userB.getValidJwt(), "token-a")
    }

    func testInvalidateJwtTokenForAnUnknownExternalIdChangesNothing() {
        let userA = addModel(externalId: "user-a")
        userA.jwtBearerToken = "token-a"

        repo.invalidateJwtToken(externalId: "user-b", rejectedToken: "token-a")

        XCTAssertEqual(userA.getValidJwt(), "token-a")
    }
}
