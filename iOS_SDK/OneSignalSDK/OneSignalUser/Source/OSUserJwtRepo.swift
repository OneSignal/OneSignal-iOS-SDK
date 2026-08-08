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

/**
 Identity Verification token access, keyed by `external_id`. Executors depend on this rather than on
 the User Manager so that no JWT lookup reaches for a singleton.
 */
protocol OSUserJwtProviding: AnyObject {
    /// The token this user can sign with, or nil if the SDK holds none.
    func validJwt(externalId: String) -> String?

    /**
     Asks the app for a token for `externalId`.

     Returns `true` if this call is the one that asked, which happens at most once per external ID
     per session so a burst of concurrent callers does not fire the event repeatedly.
     */
    @discardableResult
    func askForToken(externalId: String) -> Bool

    /// Parks the rejected token and asks the app for a replacement. Returns `true` if this call asked.
    @discardableResult
    func invalidateJwt(externalId: String, rejectedToken: String) -> Bool
}

final class OSUserJwtRepo: OSUserJwtProviding {
    private let identityModelRepo: OSIdentityModelRepo
    private let notifyInvalidated: (String) -> Void

    let lock = NSLock()
    /**
     External IDs the app has already been asked to re-sign.

     In memory only. A model decoded at launch can already hold the invalid sentinel, leaving nothing
     to transition, so a fresh session has to be able to ask again — otherwise an app that was asked
     in a previous run is never told it still owes a token.
     */
    var askedForToken: Set<String> = []

    init(identityModelRepo: OSIdentityModelRepo, notifyInvalidated: @escaping (String) -> Void) {
        self.identityModelRepo = identityModelRepo
        self.notifyInvalidated = notifyInvalidated
    }

    func validJwt(externalId: String) -> String? {
        return identityModelRepo.validJwt(externalId: externalId)
    }

    /**
     Stores a token supplied by the app, and lets this user be asked again if it is ever rejected.
     Returns `false` for a token that was not stored, so callers do not go looking for held work to release.

     An unusable token is ignored rather than stored: it would replace a good token with nothing to sign
     with, and clearing the ask for it would have the SDK and the app trade asks and replies on every flush.
     */
    @discardableResult
    func updateJwt(externalId: String, token: String) -> Bool {
        guard !token.isEmpty, token != OS_JWT_TOKEN_INVALID else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSUserJwtRepo.updateJwt ignored an unusable token for \(externalId)")
            return false
        }
        identityModelRepo.updateJwtToken(externalId: externalId, token: token)
        lock.withLock { _ = askedForToken.remove(externalId) }
        return true
    }

    @discardableResult
    func askForToken(externalId: String) -> Bool {
        guard lock.withLock({ askedForToken.insert(externalId).inserted }) else {
            return false
        }
        notifyInvalidated(externalId)
        return true
    }

    @discardableResult
    func invalidateJwt(externalId: String, rejectedToken: String) -> Bool {
        // No model for this user means the token could not have come from here. A Request stamped
        // with an owner whose model was cleared for hydration lands here, and it retries once the
        // aliases come back.
        guard identityModelRepo.invalidateJwtToken(externalId: externalId, rejectedToken: rejectedToken) else {
            return false
        }
        // A replacement that landed while the rejected Request was in flight leaves the token above
        // untouched, and the retry signs with it, so there is nothing to ask the app for.
        guard identityModelRepo.validJwt(externalId: externalId) == nil else {
            return false
        }
        return askForToken(externalId: externalId)
    }
}
