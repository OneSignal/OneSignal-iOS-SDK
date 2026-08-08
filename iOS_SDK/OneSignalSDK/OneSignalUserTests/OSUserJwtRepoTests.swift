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
@testable import OneSignalUser

/// Covers when the app is asked for a replacement token. Parking of the models themselves is
/// `OSIdentityModelRepoTests`.
final class OSUserJwtRepoTests: XCTestCase {
    private var identityModelRepo: OSIdentityModelRepo!
    private var repo: OSUserJwtRepo!
    private var asked: [String] = []

    override func setUp() {
        super.setUp()
        identityModelRepo = OSIdentityModelRepo()
        asked = []
        repo = OSUserJwtRepo(identityModelRepo: identityModelRepo) { [weak self] externalId in
            self?.asked.append(externalId)
        }
    }

    @discardableResult
    private func addModel(externalId: String, token: String?) -> OSIdentityModel {
        let model = OSIdentityModel(aliases: [OS_EXTERNAL_ID: externalId], changeNotifier: OSEventProducer())
        model.jwtBearerToken = token
        identityModelRepo.add(model: model)
        return model
    }

    // MARK: - validJwt

    func testValidJwtReadsThroughToTheIdentityModel() {
        addModel(externalId: "user-a", token: "token-a")

        XCTAssertEqual(repo.validJwt(externalId: "user-a"), "token-a")
        XCTAssertNil(repo.validJwt(externalId: "user-b"))
    }

    // MARK: - askForToken

    /// A Request that parks for want of a token has nothing to reject, so it asks directly.
    func testAskingForATokenAsksOncePerExternalId() {
        XCTAssertTrue(repo.askForToken(externalId: "user-a"))
        XCTAssertFalse(repo.askForToken(externalId: "user-a"))
        XCTAssertTrue(repo.askForToken(externalId: "user-b"))

        XCTAssertEqual(asked, ["user-a", "user-b"])
    }

    /// Whichever path asks first, the other stays quiet for the rest of the session.
    func testAParkedRequestAndARejectedTokenShareTheOneAsk() {
        addModel(externalId: "user-a", token: "token-a")

        XCTAssertTrue(repo.askForToken(externalId: "user-a"))
        XCTAssertFalse(repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a"))

        XCTAssertEqual(asked, ["user-a"])
    }

    // MARK: - invalidateJwt

    func testInvalidatingParksTheTokenAndAsksTheApp() {
        let model = addModel(externalId: "user-a", token: "token-a")

        XCTAssertTrue(repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a"))
        XCTAssertNil(model.getValidJwt())
        XCTAssertEqual(asked, ["user-a"])
    }

    /// Several Requests can be rejected before the app answers; asking once is enough.
    func testInvalidatingTwiceAsksOnce() {
        addModel(externalId: "user-a", token: "token-a")

        XCTAssertTrue(repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a"))
        XCTAssertFalse(repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a"))
        XCTAssertEqual(asked, ["user-a"])
    }

    /// The replacement arrived while the rejected Request was in flight, so the retry can use it.
    func testInvalidatingAStaleTokenLeavesTheReplacementAndDoesNotAsk() {
        let model = addModel(externalId: "user-a", token: "token-b")

        XCTAssertFalse(repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a"))
        XCTAssertEqual(model.getValidJwt(), "token-b")
        XCTAssertTrue(asked.isEmpty)
    }

    func testInvalidatingAnUnknownExternalIdAsksNobody() {
        addModel(externalId: "user-a", token: "token-a")

        XCTAssertFalse(repo.invalidateJwt(externalId: "user-b", rejectedToken: "token-a"))
        XCTAssertTrue(asked.isEmpty)
    }

    /// A model restored from cache already holds the sentinel, so there is no transition left to make.
    /// The app still has to be told once this session that it owes a token.
    func testInvalidatingAnAlreadyParkedTokenStillAsksOnceThisSession() {
        addModel(externalId: "user-a", token: OS_JWT_TOKEN_INVALID)

        XCTAssertTrue(repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a"))
        XCTAssertEqual(asked, ["user-a"])
    }

    // MARK: - updateJwt

    func testANewTokenRearmsTheRequestForAnother() {
        addModel(externalId: "user-a", token: "token-a")
        _ = repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a")

        repo.updateJwt(externalId: "user-a", token: "token-b")
        XCTAssertEqual(repo.validJwt(externalId: "user-a"), "token-b")

        XCTAssertTrue(repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-b"))
        XCTAssertEqual(asked, ["user-a", "user-a"])
    }

    /// An app answering with nothing usable must not be able to trade asks and replies with the SDK.
    func testAnEmptyTokenDoesNotRearmTheRequestForAnother() {
        addModel(externalId: "user-a", token: "token-a")
        _ = repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a")

        repo.updateJwt(externalId: "user-a", token: "")

        XCTAssertFalse(repo.askForToken(externalId: "user-a"))
        XCTAssertEqual(asked, ["user-a"])
    }

    /// The sentinel is what a rejection writes, so storing it as an update would park a working token.
    func testTheInvalidSentinelIsIgnored() {
        let model = addModel(externalId: "user-a", token: "token-a")

        repo.updateJwt(externalId: "user-a", token: OS_JWT_TOKEN_INVALID)

        XCTAssertEqual(model.getValidJwt(), "token-a")
    }

    /// A usable replacement must reach a user whose token was already rejected.
    func testAReplacementTokenOverwritesTheParkedSentinel() {
        addModel(externalId: "user-a", token: "token-a")
        _ = repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a")

        repo.updateJwt(externalId: "user-a", token: "token-b")

        XCTAssertEqual(repo.validJwt(externalId: "user-a"), "token-b")
    }

    func testUsersAreAskedForIndependently() {
        addModel(externalId: "user-a", token: "token-a")
        addModel(externalId: "user-b", token: "token-b")

        _ = repo.invalidateJwt(externalId: "user-a", rejectedToken: "token-a")
        _ = repo.invalidateJwt(externalId: "user-b", rejectedToken: "token-b")

        XCTAssertEqual(asked, ["user-a", "user-b"])
    }
}
