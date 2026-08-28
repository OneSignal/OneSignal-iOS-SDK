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

     Returns nil when Identity Verification is in effect and the Request cannot be signed, leaving it in
     the queue it already sits in. An owner with no usable token is parked and the app is asked for one;
     `updateUserJwt` (via `storeJwt`) wakes the executor, or the requirement turning off resolves it and
     sends. A Request with no owner at all is refused, since only the purge can resolve it.
     */
    func authorizeUserScoped(_ request: OSUserRequest, legacyAlias: OSAliasPair) -> OSAliasPair?

    /// The same decision for endpoints that take a token but no alias, because their path names a
    /// subscription or the app. Returns `false` under the same conditions as `authorizeUserScoped`,
    /// except that a `sendsUnsigned` Request with no owner is allowed through.
    func authorize(_ request: OSUserRequest) -> Bool

    /**
     Returns `true` if the Request's owner has no token to sign with, which is why the two methods above
     parked it. Reads only: it does not ask the app for a token, so call it after one of them has.

     Lets a caller that stops at its first unsendable Request tell "nothing can send until the app hands
     over a token for this user" from "not addressable yet", which resolves on its own.
     */
    func awaitsToken(_ request: OSUserRequest) -> Bool

    /**
     Parks the token an unauthorized response rejected and clears `sentToClient` so the Request is
     re-signed on a later flush.

     Returns `true` when the caller must leave the Request queued, `false` to fall through to its
     existing non-retryable handling.
     */
    func handleUnauthorized(_ request: OSUserRequest) -> Bool

    /**
     The same alias and token decision for a user-scoped call that does not travel through the Request
     queues, currently the in-app message fetch. Pass the ids of the user the call is for.

     Returns nil when it cannot be sent yet, having asked the app for a token if that is what is missing.
     */
    func authorization(onesignalId: String?, externalId: String?) -> OSUserRequestAuthorization?
}

extension OSRequestAuthorizing {
    /// Returns `true` when `ivBehaviorActive` and the Request has an owner, so a token can still arrive for an uncached Request whose identity model is gone.
    func keepUncachedOwned(_ request: OSUserRequest) -> Bool {
        ivBehaviorActive && request.ownerExternalId != nil
    }
}

/**
 How another module should address and sign one user-scoped call.

 `alias` nil means address it the way it was addressed before Identity Verification: no user in the
 path and nothing to sign with.
 */
@objc(OSUserRequestAuthorization)
public final class OSUserRequestAuthorization: NSObject {
    @objc public let alias: OSAliasPair?
    /// Merge into the request's headers. Empty unless the call is signed.
    @objc public let headers: [String: String]
    /// The token `headers` signs with, nil when the call is unsigned.
    @objc public let token: String?

    fileprivate init(alias: OSAliasPair?, headers: [String: String] = [:], token: String? = nil) {
        self.alias = alias
        self.headers = headers
        self.token = token
    }
}

final class OSRequestAuth: OSRequestAuthorizing {
    private static let authorizationHeader = "Authorization"
    private static let bearerPrefix = "Bearer "
    private static let legacyAddressing = OSUserRequestAuthorization(alias: nil)

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
            // A user-scoped path with no owner has nobody to sign for, and addressing it by
            // `onesignal_id` would send it unsigned. The Operation Repo suppresses anonymous work long
            // before it becomes a Request, and the purge clears leftovers on hydration, so this holds.
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSRequestAuth: refusing \(request), it has no owner under Identity Verification")
            return nil
        }
        guard let token = jwt.validJwt(externalId: externalId) else {
            park(request, ownedBy: externalId)
            return nil
        }
        setBearer(token, on: request)
        return OSAliasPair(OS_EXTERNAL_ID, externalId)
    }

    func authorize(_ request: OSUserRequest) -> Bool {
        guard ivBehaviorActive else {
            return true
        }
        guard let externalId = request.ownerExternalId else {
            // Anything not exempt is a leftover the purge has yet to clear, and unsendable until it does.
            guard request.sendsUnsigned else {
                OneSignalLog.onesignalLog(.LL_ERROR, message: "OSRequestAuth: refusing \(request), it has no owner under Identity Verification")
                return false
            }
            return true
        }
        guard let token = jwt.validJwt(externalId: externalId) else {
            park(request, ownedBy: externalId)
            return false
        }
        setBearer(token, on: request)
        return true
    }

    func awaitsToken(_ request: OSUserRequest) -> Bool {
        guard ivBehaviorActive, let externalId = request.ownerExternalId else {
            return false
        }
        return jwt.validJwt(externalId: externalId) == nil
    }

    /**
     Nothing else prompts the app when a Request merely parks: the invalidated event fires on a rejected
     token, and a token the app never supplied — or supplied in a session that has since ended — leaves the
     SDK holding none with nothing to reject. The repo keeps this to one ask per external ID per session.
     */
    private func park(_ request: OSUserRequest, ownedBy externalId: String) {
        // Log only on the ask that reaches the app; later prepareForExecution retries stay quiet.
        if jwt.askForToken(externalId: externalId) {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSRequestAuth: holding \(request) until \(externalId) has a token")
        }
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

    func authorization(onesignalId: String?, externalId: String?) -> OSUserRequestAuthorization? {
        // Not decided yet: legacy vs onesignal_id vs external_id+JWT. Callers reattempt on hydration.
        guard identityVerificationService.requirement != .unknown else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSRequestAuth: holding a user-scoped call until the requirement is known")
            return nil
        }
        // Requirement is known. Flag-only rollout still uses the pre-IV subscription path.
        guard identityVerificationService.newCodePathsRun else {
            return Self.legacyAddressing
        }
        guard ivBehaviorActive else {
            // Nothing to address the call to until the server assigns an `onesignal_id`.
            guard let onesignalId = onesignalId else {
                return nil
            }
            return OSUserRequestAuthorization(alias: OSAliasPair(OS_ONESIGNAL_ID, onesignalId))
        }
        // Under Identity Verification there is nothing the server will serve for a device with no
        // identified user, so this waits for a login rather than falling back to `onesignal_id`.
        guard let externalId = externalId else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSRequestAuth: holding a user-scoped call until a user is identified")
            return nil
        }
        guard let token = jwt.validJwt(externalId: externalId) else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSRequestAuth: holding a user-scoped call until \(externalId) has a token")
            jwt.askForToken(externalId: externalId)
            return nil
        }
        return OSUserRequestAuthorization(alias: OSAliasPair(OS_EXTERNAL_ID, externalId),
                                          headers: [Self.authorizationHeader: Self.bearerPrefix + token],
                                          token: token)
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
