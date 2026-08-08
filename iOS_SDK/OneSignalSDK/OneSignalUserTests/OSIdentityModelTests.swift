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

/// Covers the JWT bearer token on `OSIdentityModel`: which tokens count as usable, the
/// compare-and-set on invalidation, and what survives an archive round trip.
final class OSIdentityModelTests: XCTestCase {

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    private func makeModel(token: String? = nil) -> OSIdentityModel {
        let model = OSIdentityModel(aliases: [:], changeNotifier: OSEventProducer())
        model.jwtBearerToken = token
        return model
    }

    private func archiveThenUnarchive(_ model: OSIdentityModel) throws -> OSIdentityModel {
        let data = try NSKeyedArchiver.archivedData(withRootObject: model, requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        defer { unarchiver.finishDecoding() }
        return try XCTUnwrap(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? OSIdentityModel)
    }

    // MARK: - getValidJwt()

    func testGetValidJwtReturnsNilWhenTokenIsNil() {
        XCTAssertNil(makeModel(token: nil).getValidJwt())
    }

    func testGetValidJwtReturnsNilWhenTokenIsEmptyString() {
        XCTAssertNil(makeModel(token: "").getValidJwt())
    }

    func testGetValidJwtReturnsNilWhenTokenIsInvalidSentinel() {
        XCTAssertNil(makeModel(token: OS_JWT_TOKEN_INVALID).getValidJwt())
    }

    func testGetValidJwtReturnsTokenWhenTokenIsValid() {
        let token = "eyJhbGciOiJFUzI1NiJ9.payload.sig"
        XCTAssertEqual(makeModel(token: token).getValidJwt(), token)
    }

    // MARK: - invalidateJwtBearerToken(rejectedToken:)

    func testInvalidateReturnsTrueOnFirstTransitionAndSetsInvalidSentinel() {
        let model = makeModel(token: "valid-token")

        XCTAssertTrue(model.invalidateJwtBearerToken(rejectedToken: "valid-token"))
        XCTAssertEqual(model.jwtBearerToken, OS_JWT_TOKEN_INVALID)
    }

    /// Two requests can be rejected at once; only one of them should tell the app to mint a token.
    func testInvalidateReturnsFalseWhenAlreadyInvalid() {
        let model = makeModel(token: "valid-token")
        _ = model.invalidateJwtBearerToken(rejectedToken: "valid-token")

        XCTAssertFalse(model.invalidateJwtBearerToken(rejectedToken: "valid-token"))
        XCTAssertEqual(model.jwtBearerToken, OS_JWT_TOKEN_INVALID)
    }

    /// The app can supply a replacement while the rejected request is still in flight.
    func testInvalidateLeavesAReplacementTokenAlone() {
        let model = makeModel(token: "replacement-token")

        XCTAssertFalse(model.invalidateJwtBearerToken(rejectedToken: "stale-token"))
        XCTAssertEqual(model.jwtBearerToken, "replacement-token")
    }

    func testInvalidateDoesNothingWhenThereIsNoToken() {
        let model = makeModel(token: nil)

        XCTAssertFalse(model.invalidateJwtBearerToken(rejectedToken: "stale-token"))
        XCTAssertNil(model.jwtBearerToken)
    }

    // MARK: - Persistence

    func testTokenSurvivesAnArchiveRoundTrip() throws {
        let model = makeModel(token: "cached-token")
        model.addAliases([OS_EXTERNAL_ID: "user-a"])

        let decoded = try archiveThenUnarchive(model)

        XCTAssertEqual(decoded.jwtBearerToken, "cached-token")
        XCTAssertEqual(decoded.externalId, "user-a")
    }

    /// A model archived by a build that never encoded a token has no value under the key.
    func testAModelArchivedWithoutATokenDecodesWithANilToken() throws {
        let model = makeModel(token: nil)
        model.addAliases([OS_ONESIGNAL_ID: "osid-a"])

        let decoded = try archiveThenUnarchive(model)

        XCTAssertNil(decoded.jwtBearerToken)
        XCTAssertEqual(decoded.onesignalId, "osid-a")
    }

    func testTheInvalidSentinelIsWhatPersists() throws {
        let model = makeModel(token: "valid-token")
        model.invalidateJwtBearerToken(rejectedToken: "valid-token")

        let decoded = try archiveThenUnarchive(model)

        XCTAssertEqual(decoded.jwtBearerToken, OS_JWT_TOKEN_INVALID)
        XCTAssertNil(decoded.getValidJwt())
    }
}
