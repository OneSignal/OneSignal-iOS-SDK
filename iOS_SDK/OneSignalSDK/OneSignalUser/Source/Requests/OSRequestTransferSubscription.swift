/*
 Modified MIT License

 Copyright 2023 OneSignal

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

/**
 Deprecated as of `5.2.3`. Use CreateUser instead. This class skeleton remains due to potentially cached requests.
 When this request is uncached, it will be translated to a CreateUser request, if appropriate.
 -------
 Transfers the Subscription specified by the subscriptionId to the User identified by the identity in the payload.
 Only one entry is allowed, `onesignal_id` or an Alias. We will use the alias specified.
 The anticipated usage of this request is only for push subscriptions.
 */
@available(*, deprecated, message: "Replaced by Create User")
class OSRequestTransferSubscription: OneSignalRequest, OSUserRequest {
    var sentToClient = false

    let aliasLabel: String
    let aliasId: String

    func prepareForExecution() -> Bool {
        return false
    }

    func encode(with coder: NSCoder) { }

    /// All cached instances should have External ID as the alias
    required init?(coder: NSCoder) {
        guard
            let aliasLabel = coder.decodeObject(forKey: "aliasLabel") as? String,
            let aliasId = coder.decodeObject(forKey: "aliasId") as? String
        else {
            // Log error
            return nil
        }
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
    }
}
