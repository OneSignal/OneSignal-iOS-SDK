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

        identityModelRepo.updateJwtToken(externalId: externalId, token: token)
    }

    /// Parks the user's token and asks the app to mint a replacement.
    @objc
    public func invalidateJwtForExternalId(externalId: String) {
        guard identityVerificationService.ivBehaviorActive else {
            return
        }
        if identityModelRepo.invalidateJwtToken(externalId: externalId) {
            userJwtInvalidatedObserver.notifyChange(OSUserJwtInvalidatedEvent(externalId: externalId))
        }
    }
}
