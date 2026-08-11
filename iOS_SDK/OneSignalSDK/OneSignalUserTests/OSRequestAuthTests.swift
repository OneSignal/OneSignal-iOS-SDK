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

/// A stand-in for whichever concrete Request is being authorized; only ownership and the header matter here.
/// Named for the runtime because `OSUserRequest` requires `NSCoding` and a private class has no stable name.
@objc(OSStubUserRequest)
private class StubUserRequest: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let ownerExternalId: String?
    let sendsUnsigned: Bool

    init(ownerExternalId: String?, sendsUnsigned: Bool = false) {
        self.ownerExternalId = ownerExternalId
        self.sendsUnsigned = sendsUnsigned
        super.init()
    }

    func prepareForExecution(newRecordsState: OSNewRecordsState, auth: OSRequestAuthorizing) -> Bool {
        return true
    }

    func encode(with coder: NSCoder) {
        coder.encode(ownerExternalId, forKey: "ownerExternalId")
        coder.encode(sendsUnsigned, forKey: "sendsUnsigned")
    }

    required init?(coder: NSCoder) {
        self.ownerExternalId = coder.decodeObject(forKey: "ownerExternalId") as? String
        self.sendsUnsigned = coder.decodeBool(forKey: "sendsUnsigned")
        super.init()
    }

    var authorizationHeader: String? {
        return additionalHeaders?["Authorization"]
    }
}

private class StubJwtProvider: OSUserJwtProviding {
    var tokens: [String: String] = [:]
    private(set) var invalidatedCalls: [(externalId: String, rejectedToken: String)] = []
    private(set) var askedFor: [String] = []

    func validJwt(externalId: String) -> String? {
        return tokens[externalId]
    }

    @discardableResult
    func askForToken(externalId: String) -> Bool {
        askedFor.append(externalId)
        return true
    }

    @discardableResult
    func invalidateJwt(externalId: String, rejectedToken: String) -> Bool {
        invalidatedCalls.append((externalId, rejectedToken))
        tokens.removeValue(forKey: externalId)
        return true
    }
}

final class OSRequestAuthTests: XCTestCase {
    private var jwtConfig: OSUserJwtConfig!
    private var jwt: StubJwtProvider!

    override func setUp() {
        super.setUp()
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_USE_IDENTITY_VERIFICATION)
        jwtConfig = OSUserJwtConfig()
        jwt = StubJwtProvider()
    }

    override func tearDown() {
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_USE_IDENTITY_VERIFICATION)
        super.tearDown()
    }

    private func makeAuth(requiresUserAuth: Bool) -> OSRequestAuth {
        jwtConfig.hydrate(requiresUserAuth: requiresUserAuth)
        return makeAuth(enabledKeys: [])
    }

    /// For the cases that turn on the rollout flag, or leave the requirement unhydrated, or both.
    private func makeAuth(enabledKeys: Set<String>) -> OSRequestAuth {
        let service = OSIdentityVerificationService(featureManager: OSFeatureManager(enabledKeys: enabledKeys), jwtConfig: jwtConfig)
        return OSRequestAuth(identityVerificationService: service, jwt: jwt)
    }

    // MARK: - authorizeUserScoped

    func testUserScopedKeepsTheLegacyAliasAndSendsNoHeaderWhileIdentityVerificationIsOff() {
        let auth = makeAuth(requiresUserAuth: false)
        jwt.tokens["user-a"] = "token-a"
        let request = StubUserRequest(ownerExternalId: "user-a")

        let alias = auth.authorizeUserScoped(request, legacyAlias: OSAliasPair(OS_ONESIGNAL_ID, "osid-a"))

        XCTAssertEqual(alias?.label, OS_ONESIGNAL_ID)
        XCTAssertEqual(alias?.id, "osid-a")
        XCTAssertNil(request.authorizationHeader)
    }

    func testUserScopedSwapsToExternalIdAndSignsWhileIdentityVerificationIsOn() {
        let auth = makeAuth(requiresUserAuth: true)
        jwt.tokens["user-a"] = "token-a"
        let request = StubUserRequest(ownerExternalId: "user-a")

        let alias = auth.authorizeUserScoped(request, legacyAlias: OSAliasPair(OS_ONESIGNAL_ID, "osid-a"))

        XCTAssertEqual(alias?.label, OS_EXTERNAL_ID)
        XCTAssertEqual(alias?.id, "user-a")
        XCTAssertEqual(request.authorizationHeader, "Bearer token-a")
    }

    /// nil is the park signal: the caller leaves the Request queued rather than sending it unsigned.
    func testUserScopedReturnsNilWhenTheOwnerHasNoToken() {
        let auth = makeAuth(requiresUserAuth: true)
        let request = StubUserRequest(ownerExternalId: "user-a")

        XCTAssertNil(auth.authorizeUserScoped(request, legacyAlias: OSAliasPair(OS_ONESIGNAL_ID, "osid-a")))
        XCTAssertNil(request.authorizationHeader)
        // Nothing else prompts the app for a token the SDK never held, so parking has to.
        XCTAssertEqual(jwt.askedFor, ["user-a"])
    }

    /// Addressing it by `onesignal_id` would send a user-scoped path unsigned, so it waits for the purge.
    func testUserScopedRefusesAnUnownedRequest() {
        let auth = makeAuth(requiresUserAuth: true)
        let request = StubUserRequest(ownerExternalId: nil)

        XCTAssertNil(auth.authorizeUserScoped(request, legacyAlias: OSAliasPair(OS_ONESIGNAL_ID, "osid-a")))
        XCTAssertNil(request.authorizationHeader)
        // There is no owner to ask on behalf of, so the app must not be prompted.
        XCTAssertTrue(jwt.askedFor.isEmpty)
    }

    func testUserScopedKeepsAddressingAnUnownedRequestWhileIdentityVerificationIsOff() {
        let auth = makeAuth(requiresUserAuth: false)
        let request = StubUserRequest(ownerExternalId: nil)

        let alias = auth.authorizeUserScoped(request, legacyAlias: OSAliasPair(OS_ONESIGNAL_ID, "osid-a"))

        XCTAssertEqual(alias?.label, OS_ONESIGNAL_ID)
        XCTAssertEqual(alias?.id, "osid-a")
    }

    /// Fetch User can be built to read an alias other than `onesignal_id`, and that survives the gate being off.
    func testUserScopedPreservesACallerSuppliedLegacyAlias() {
        let auth = makeAuth(requiresUserAuth: false)
        let request = StubUserRequest(ownerExternalId: "user-a")

        let alias = auth.authorizeUserScoped(request, legacyAlias: OSAliasPair(OS_EXTERNAL_ID, "user-a"))

        XCTAssertEqual(alias?.label, OS_EXTERNAL_ID)
        XCTAssertEqual(alias?.id, "user-a")
    }

    // MARK: - authorize

    func testAuthorizeSendsNoHeaderWhileIdentityVerificationIsOff() {
        let auth = makeAuth(requiresUserAuth: false)
        jwt.tokens["user-a"] = "token-a"
        let request = StubUserRequest(ownerExternalId: "user-a")

        XCTAssertTrue(auth.authorize(request))
        XCTAssertNil(request.authorizationHeader)
    }

    func testAuthorizeSignsAnOwnedRequestWhileIdentityVerificationIsOn() {
        let auth = makeAuth(requiresUserAuth: true)
        jwt.tokens["user-a"] = "token-a"
        let request = StubUserRequest(ownerExternalId: "user-a")

        XCTAssertTrue(auth.authorize(request))
        XCTAssertEqual(request.authorizationHeader, "Bearer token-a")
    }

    func testAuthorizeParksAnOwnedRequestWithNoToken() {
        let auth = makeAuth(requiresUserAuth: true)
        let request = StubUserRequest(ownerExternalId: "user-a")

        XCTAssertFalse(auth.authorize(request))
        XCTAssertEqual(jwt.askedFor, ["user-a"])
    }

    /// A signed Request must not re-ask: the app has already answered for this user.
    func testAuthorizeDoesNotAskWhenTheOwnerHasAToken() {
        let auth = makeAuth(requiresUserAuth: true)
        jwt.tokens["user-a"] = "token-a"
        let request = StubUserRequest(ownerExternalId: "user-a")

        XCTAssertTrue(auth.authorize(request))
        XCTAssertTrue(jwt.askedFor.isEmpty)
    }

    /// The push subscription update has no owner and must keep flowing under Identity Verification.
    func testAuthorizeSendsAnUnownedRequestUnsignedWhenItIsExempt() {
        let auth = makeAuth(requiresUserAuth: true)
        let request = StubUserRequest(ownerExternalId: nil, sendsUnsigned: true)

        XCTAssertTrue(auth.authorize(request))
        XCTAssertNil(request.authorizationHeader)
    }

    /// Everything else with no owner is a leftover the purge has yet to clear, and must not go out unsigned.
    func testAuthorizeRefusesAnUnownedRequestThatIsNotExempt() {
        let auth = makeAuth(requiresUserAuth: true)
        let request = StubUserRequest(ownerExternalId: nil)

        XCTAssertFalse(auth.authorize(request))
        XCTAssertTrue(jwt.askedFor.isEmpty)
    }

    func testAuthorizeSendsAnUnownedRequestWhileIdentityVerificationIsOff() {
        let auth = makeAuth(requiresUserAuth: false)
        let request = StubUserRequest(ownerExternalId: nil)

        XCTAssertTrue(auth.authorize(request))
        XCTAssertNil(request.authorizationHeader)
    }

    // MARK: - handleUnauthorized

    func testHandleUnauthorizedInvalidatesTheSignedTokenAndRequeuesTheRequest() {
        let auth = makeAuth(requiresUserAuth: true)
        jwt.tokens["user-a"] = "token-a"
        let request = StubUserRequest(ownerExternalId: "user-a")
        _ = auth.authorize(request)
        request.sentToClient = true

        XCTAssertTrue(auth.handleUnauthorized(request))

        // The token that went out is the one invalidated, and the Request is left ready to re-sign.
        XCTAssertEqual(jwt.invalidatedCalls.count, 1)
        XCTAssertEqual(jwt.invalidatedCalls.first?.externalId, "user-a")
        XCTAssertEqual(jwt.invalidatedCalls.first?.rejectedToken, "token-a")
        XCTAssertNil(request.authorizationHeader)
        XCTAssertFalse(request.sentToClient)
    }

    /// The header carries the token, so a Request sent before the app supplied one has nothing to reject.
    func testHandleUnauthorizedDeclinesAnUnsignedRequest() {
        let auth = makeAuth(requiresUserAuth: true)
        let request = StubUserRequest(ownerExternalId: "user-a")
        request.sentToClient = true

        XCTAssertFalse(auth.handleUnauthorized(request))
        XCTAssertTrue(jwt.invalidatedCalls.isEmpty)
        XCTAssertTrue(request.sentToClient)
    }

    /// With the gate off a 401 stays on the executor's existing non-retryable path.
    func testHandleUnauthorizedDeclinesWhileIdentityVerificationIsOff() {
        let auth = makeAuth(requiresUserAuth: false)
        let request = StubUserRequest(ownerExternalId: "user-a")
        request.additionalHeaders = ["Authorization": "Bearer token-a"]
        request.sentToClient = true

        XCTAssertFalse(auth.handleUnauthorized(request))
        XCTAssertTrue(jwt.invalidatedCalls.isEmpty)
        XCTAssertTrue(request.sentToClient)
    }

    // MARK: - authorization, for callers outside the Request queues

    /// The in-app message fetch addressed the subscription on its own before Identity Verification.
    func testAuthorizationCarriesNoUserWhileTheNewCodePathsAreOff() {
        let auth = makeAuth(requiresUserAuth: false)
        jwt.tokens["user-a"] = "token-a"

        let authorization = auth.authorization(onesignalId: "osid-a", externalId: "user-a")

        XCTAssertNotNil(authorization)
        XCTAssertNil(authorization?.alias)
        XCTAssertEqual(authorization?.headers, [:])
        XCTAssertNil(authorization?.token)
    }

    func testAuthorizationAddressesTheOnesignalIdWhileIdentityVerificationIsOff() {
        jwtConfig.hydrate(requiresUserAuth: false)
        let auth = makeAuth(enabledKeys: [OSFeatureFlag.identityVerification.rawValue])
        jwt.tokens["user-a"] = "token-a"

        let authorization = auth.authorization(onesignalId: "osid-a", externalId: "user-a")

        XCTAssertEqual(authorization?.alias?.label, OS_ONESIGNAL_ID)
        XCTAssertEqual(authorization?.alias?.id, "osid-a")
        XCTAssertEqual(authorization?.headers, [:])
        XCTAssertNil(authorization?.token)
    }

    func testAuthorizationAddressesTheExternalIdAndSignsWhileIdentityVerificationIsOn() {
        let auth = makeAuth(requiresUserAuth: true)
        jwt.tokens["user-a"] = "token-a"

        let authorization = auth.authorization(onesignalId: "osid-a", externalId: "user-a")

        XCTAssertEqual(authorization?.alias?.label, OS_EXTERNAL_ID)
        XCTAssertEqual(authorization?.alias?.id, "user-a")
        XCTAssertEqual(authorization?.headers, ["Authorization": "Bearer token-a"])
        XCTAssertEqual(authorization?.token, "token-a")
    }

    /// nil is the defer signal: an unsigned call would be rejected if the app turns out to require auth.
    /// Holds even when the rollout flag is off — otherwise production would send legacy unsigned before
    /// the first params answer.
    func testAuthorizationDefersWhileTheRequirementIsUnknown() {
        let auth = makeAuth(enabledKeys: [])

        XCTAssertNil(auth.authorization(onesignalId: "osid-a", externalId: "user-a"))
        XCTAssertTrue(jwt.askedFor.isEmpty)
    }

    /// Under Identity Verification the server has nothing to serve a device with no identified user.
    func testAuthorizationDefersWhileNobodyIsLoggedIn() {
        let auth = makeAuth(requiresUserAuth: true)

        XCTAssertNil(auth.authorization(onesignalId: "osid-a", externalId: nil))
        XCTAssertTrue(jwt.askedFor.isEmpty)
    }

    func testAuthorizationDefersAndAsksWhenTheUserHasNoToken() {
        let auth = makeAuth(requiresUserAuth: true)

        XCTAssertNil(auth.authorization(onesignalId: "osid-a", externalId: "user-a"))
        XCTAssertEqual(jwt.askedFor, ["user-a"])
    }
}
