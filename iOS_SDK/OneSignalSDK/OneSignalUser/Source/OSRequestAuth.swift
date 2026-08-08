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

import Foundation
import OneSignalCore
import OneSignalOSCore

/**
 The one place a Request's addressing alias and `Authorization` header are decided.

 While Identity Verification is not in effect every method here resolves what the SDK sent before it
 existed: the `onesignal_id` alias and no header.
 */
protocol OSRequestAuthorizing: AnyObject {
    /// Whether Identity Verification behavior applies, for the few Requests whose body changes with it.
    var ivBehaviorActive: Bool { get }

    /**
     Resolves the alias a user-scoped path should address, attaching a Bearer header when Identity
     Verification is in effect. `legacyAlias` is what the Request addresses without it, which is
     `onesignal_id` for everything except a Fetch User that was built to read some other alias.

     Returns nil when Identity Verification is in effect but the owner has no usable token. That parks the
     Request in the queue it already sits in and asks the app for one; the next flush after `updateUserJwt`,
     or after the requirement turns off, resolves it and sends.
     */
    func authorizeUserScoped(_ request: OSUserRequest, legacyAlias: OSAliasPair) -> OSAliasPair?

    /// The same decision for endpoints that take a token but no alias, because their path names a
    /// subscription or the app. Returns `false` under the same park condition as `authorizeUserScoped`.
    func authorize(_ request: OSUserRequest) -> Bool

    /**
     Parks the token an unauthorized response rejected and clears `sentToClient` so the Request is
     re-signed on a later flush.

     Returns `true` when the caller must leave the Request queued, `false` to fall through to its
     existing non-retryable handling.
     */
    func handleUnauthorized(_ request: OSUserRequest) -> Bool
}

final class OSRequestAuth: OSRequestAuthorizing {
    private static let authorizationHeader = "Authorization"
    private static let bearerPrefix = "Bearer "

    private let identityVerificationService: OSIdentityVerificationService
    private let jwt: OSUserJwtProviding

    var ivBehaviorActive: Bool {
        return identityVerificationService.ivBehaviorActive
    }

    init(identityVerificationService: OSIdentityVerificationService, jwt: OSUserJwtProviding) {
        self.identityVerificationService = identityVerificationService
        self.jwt = jwt
    }

    func authorizeUserScoped(_ request: OSUserRequest, legacyAlias: OSAliasPair) -> OSAliasPair? {
        guard ivBehaviorActive else {
            return legacyAlias
        }
        guard let externalId = request.ownerExternalId else {
            // The Operation Repo suppresses anonymous work long before it becomes a Request, so this
            // is a leftover. Address it the legacy way rather than dropping it at send time.
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSRequestAuth: \(request) has no owner under Identity Verification, "
                                      + "addressing it by \(legacyAlias.label)")
            return legacyAlias
        }
        guard let token = jwt.validJwt(externalId: externalId) else {
            park(request, ownedBy: externalId)
            return nil
        }
        setBearer(token, on: request)
        return OSAliasPair(OS_EXTERNAL_ID, externalId)
    }

    func authorize(_ request: OSUserRequest) -> Bool {
        // No owner, nothing to sign with: the push subscription update never has one, and a Request
        // cached before ownership was stamped decodes without one. Both go out unsigned.
        guard ivBehaviorActive, let externalId = request.ownerExternalId else {
            return true
        }
        guard let token = jwt.validJwt(externalId: externalId) else {
            park(request, ownedBy: externalId)
            return false
        }
        setBearer(token, on: request)
        return true
    }

    /**
     Nothing else prompts the app when a Request merely parks: the invalidated event fires on a rejected
     token, and a token the app never supplied — or supplied in a session that has since ended — leaves the
     SDK holding none with nothing to reject. The repo keeps this to one ask per external ID per session.
     */
    private func park(_ request: OSUserRequest, ownedBy externalId: String) {
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSRequestAuth: holding \(request) until \(externalId) has a token")
        jwt.askForToken(externalId: externalId)
    }

    func handleUnauthorized(_ request: OSUserRequest) -> Bool {
        guard ivBehaviorActive,
              let externalId = request.ownerExternalId,
              let rejectedToken = signedToken(of: request)
        else {
            return false
        }
        jwt.invalidateJwt(externalId: externalId, rejectedToken: rejectedToken)
        removeBearer(from: request)
        request.sentToClient = false
        return true
    }

    private func setBearer(_ token: String, on request: OneSignalRequest) {
        var headers = request.additionalHeaders ?? [String: String]()
        headers[Self.authorizationHeader] = Self.bearerPrefix + token
        request.additionalHeaders = headers
    }

    private func removeBearer(from request: OneSignalRequest) {
        var headers = request.additionalHeaders
        headers?.removeValue(forKey: Self.authorizationHeader)
        request.additionalHeaders = headers
    }

    /// The token the Request carries, which is the one the server just rejected.
    private func signedToken(of request: OneSignalRequest) -> String? {
        guard let header = request.additionalHeaders?[Self.authorizationHeader],
              header.hasPrefix(Self.bearerPrefix)
        else {
            return nil
        }
        return String(header.dropFirst(Self.bearerPrefix.count))
    }
}
