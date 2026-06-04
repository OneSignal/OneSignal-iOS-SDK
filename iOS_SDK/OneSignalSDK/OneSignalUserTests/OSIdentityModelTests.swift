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
@testable import OneSignalOSCore
@testable import OneSignalUser

/// Tests for the two new JWT APIs added to `OSIdentityModel`:
/// - `getValidJwt()` snapshots and returns the bearer token only when it is
///   non-nil, non-empty, and not the `OS_JWT_TOKEN_INVALID` sentinel.
/// - `invalidateJwtBearerToken()` performs an atomic compare-and-set to
///   `OS_JWT_TOKEN_INVALID`, returning `true` only on the transition.
final class OSIdentityModelTests: XCTestCase {

    private func makeModel(token: String? = nil) -> OSIdentityModel {
        let model = OSIdentityModel(aliases: [:], changeNotifier: OSEventProducer())
        model.jwtBearerToken = token
        return model
    }

    // MARK: - getValidJwt()

    func testGetValidJwt_returnsNil_whenTokenIsNil() {
        XCTAssertNil(makeModel(token: nil).getValidJwt())
    }

    func testGetValidJwt_returnsNil_whenTokenIsEmptyString() {
        XCTAssertNil(makeModel(token: "").getValidJwt())
    }

    func testGetValidJwt_returnsNil_whenTokenIsInvalidSentinel() {
        XCTAssertNil(makeModel(token: OS_JWT_TOKEN_INVALID).getValidJwt())
    }

    func testGetValidJwt_returnsToken_whenTokenIsValid() {
        let token = "eyJhbGciOiJFUzI1NiJ9.payload.sig"
        XCTAssertEqual(makeModel(token: token).getValidJwt(), token)
    }

    // MARK: - invalidateJwtBearerToken()

    func testInvalidate_returnsTrueOnFirstTransition_andSetsInvalidSentinel() {
        let model = makeModel(token: "valid-token")

        XCTAssertTrue(model.invalidateJwtBearerToken())
        XCTAssertEqual(model.jwtBearerToken, OS_JWT_TOKEN_INVALID)
    }

    func testInvalidate_returnsFalseWhenAlreadyInvalid() {
        let model = makeModel(token: "valid-token")
        _ = model.invalidateJwtBearerToken()

        XCTAssertFalse(model.invalidateJwtBearerToken())
        XCTAssertEqual(model.jwtBearerToken, OS_JWT_TOKEN_INVALID)
    }

    func testInvalidate_returnsTrueWhenStartingFromNil() {
        // Defensive: nil → INVALID is still a real transition, the model lands
        // on the sentinel and the caller can fire fireJwtExpired once.
        let model = makeModel(token: nil)

        XCTAssertTrue(model.invalidateJwtBearerToken())
        XCTAssertEqual(model.jwtBearerToken, OS_JWT_TOKEN_INVALID)
    }
}
