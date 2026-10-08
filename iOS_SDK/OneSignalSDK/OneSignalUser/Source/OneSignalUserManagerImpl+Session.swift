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

extension OneSignalUserManagerImpl: OSSessionUserProvider {
    public var sessionCurrentUser: OSSessionUser {
        let user = _user
        return OSSessionUser(
            identityModelId: user?.identityModel.modelId,
            onesignalId: user?.identityModel.onesignalId,
            pushSubscriptionId: user?.pushSubscriptionModel.subscriptionId
        )
    }

    public func sessionOnesignalId(identityModelId: String) -> String? {
        identityModelRepo.get(modelId: identityModelId)?.onesignalId
    }

    /// Says no only when it knows: the requirement is `.on` and the user's model is loaded and
    /// anonymous. A model that is not loaded may still be restored.
    public func sessionUserCanBeCreated(identityModelId: String) -> Bool {
        guard identityVerificationService.requirement == .on,
              let identityModel = identityModelRepo.get(modelId: identityModelId)
        else {
            return true
        }
        return identityModel.externalId != nil
    }
}
