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

import OneSignalCore
import OneSignalOSCore

/**
 The Identity Verification surface the app talks to: it hands the SDK a token for a user, and the SDK
 tells it when that token stopped being accepted.
 */
extension OneSignalUserManagerImpl {
    @objc
    public func addUserJwtInvalidatedListener(_ listener: OSUserJwtInvalidatedListener) {
        self.userJwtInvalidatedObserver.addObserver(listener)
    }

    @objc
    public func removeUserJwtInvalidatedListener(_ listener: OSUserJwtInvalidatedListener) {
        self.userJwtInvalidatedObserver.removeObserver(listener)
    }

    @objc
    public func updateUserJwt(externalId: String, token: String) {
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "updateUserJwt") else {
            return
        }
        guard !externalId.isEmpty, !token.isEmpty, token != OS_JWT_TOKEN_INVALID else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignal.updateUserJwt called with empty externalId or an unusable token. This is not allowed.")
            return
        }
        // TODO: omit the token from this log before shipping — keep for testing.
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.updateUserJwt called for externalId: \(externalId) with token: \(token)")

        storeJwt(externalId: externalId, token: token)
    }

    /**
     How another module should address and sign a user-scoped call for the current user, decided in one
     read so the alias and the token cannot come from different users.

     Returns nil when the call cannot be sent yet — the requirement is still unknown, nobody is logged in
     under Identity Verification, or the app owes a token, which this asks for. Callers reattempt when
     `OS_ON_JWT_CONFIG_HYDRATED` or `OS_ON_USER_JWT_UPDATED` is posted.
     */
    @objc
    public func authorizationForCurrentUser() -> OSUserRequestAuthorization? {
        // `_user` rather than `user`, which would create a guest user for a caller that only reads.
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil),
              let identityModel = _user?.identityModel
        else {
            return nil
        }
        return requestAuth.authorization(onesignalId: identityModel.onesignalId, externalId: identityModel.externalId)
    }

    /**
     Parks `rejectedToken` and asks the app to mint a replacement. Pass the token the failing request
     was signed with: a replacement supplied while that request was in flight is left alone.
     */
    @objc
    public func invalidateJwtForExternalId(externalId: String, rejectedToken: String) {
        guard identityVerificationService.ivBehaviorActive else {
            return
        }
        userJwtRepo.invalidateJwt(externalId: externalId, rejectedToken: rejectedToken)
    }
}
