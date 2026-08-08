/*
 Modified MIT License

 Copyright 2022 OneSignal

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

protocol OSUserRequest: OneSignalRequest, NSCoding {
    var sentToClient: Bool { get set }

    /// The user this Request belongs to; also selects its token. See the ownership convention below.
    var ownerExternalId: String? { get }

    /// Builds the path and resolves authorization. `false` leaves the Request queued, whether it is
    /// waiting on a record it cannot address yet or on a token it cannot sign with yet. A caller deciding
    /// whether to *discard* a cached Request must not read `false` as permanent: an owned Request becomes
    /// sendable once `updateUserJwt` supplies its token.
    func prepareForExecution(newRecordsState: OSNewRecordsState, auth: OSRequestAuthorizing) -> Bool
}

/*
 Ownership convention: a Request that Identity Verification can purge stores `ownerExternalId`, the
 owner's `external_id` as of when the Request was built, and both the purge and the token lookup
 judge it by that rather than by its `identityModel`.

 The live model cannot answer the question. `clearUserData` empties an Identity Model's aliases before
 a fetch response hydrates them, so for that window an identified user reads as anonymous and a purge
 running alongside it would delete signed work. The stamp also matches how `OSDelta` carries
 `externalId`, which keeps a Delta and the Request built from it judged the same way.

 nil means anonymous, including for caches written before ownership was stamped.

 Create User and Fetch User are not built from a Delta and the purge does not consider them, so they
 read the owner off their Identity Model. Nothing is in flight when a purge runs, and the User
 executor sends nothing while the requirement is unknown, so the live read is sound there.

 Three Requests are nil by construction and so are never signed: Identify User and Fetch Identity By
 Subscription both address a user that has no `external_id` yet, and Update Subscription is the
 device's own push subscription. Each says why at its declaration.
 */

internal extension OneSignalRequest {
    /** Returns if the `OneSignal-Subscription-Id` header was added successfully. */
    func addPushSubscriptionIdToAdditionalHeaders() -> Bool {
        if let pushSubscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId {
            var additionalHeaders = self.additionalHeaders ?? [String: String]()
            additionalHeaders["OneSignal-Subscription-Id"] = pushSubscriptionId
            self.additionalHeaders = additionalHeaders
            return true
        } else {
            return false
        }
    }
}
