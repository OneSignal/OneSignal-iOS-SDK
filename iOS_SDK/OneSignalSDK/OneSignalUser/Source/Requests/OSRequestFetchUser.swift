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
import OneSignalOSCore

/**
 Fetch the user by the provided alias. This is expected to be `onesignal_id` in most cases.
 The `identityModel` is used to reference the user that is updated with the response.
 */
class OSRequestFetchUser: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let identityModel: OSIdentityModel
    let onNewSession: Bool

    /// This should always be `OS_ONESIGNAL_ID` even with JWT on, as a way to know if the user has been created on the server and for the post-create cool off period
    let onesignalId: String

    // TODO: JWT 🔐 Is external ID already handled by this time? Or do we need to check the alias here?
    /// Needs `onesignal_id` without JWT on or `external_id` with valid JWT to send this request
    func prepareForExecution(newRecordsState: OSNewRecordsState) -> Bool {
        let alias = getAlias(identityModel: identityModel)
        guard
            let aliasIdToUse = alias.id,
            let appId = OneSignalConfigManager.getAppId(),
            newRecordsState.canAccess(onesignalId),
            addJWTHeaderIsValid( identityModel: identityModel)
        else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the fetch user request for \(alias) yet.")
            return false
        }
        self.path = "apps/\(appId)/users/by/\(alias.label)/\(aliasIdToUse)"
        return true
    }

    init(identityModel: OSIdentityModel, onesignalId: String, onNewSession: Bool) {
        self.identityModel = identityModel
        self.onesignalId = onesignalId
        self.onNewSession = onNewSession
        self.stringDescription = "<OSRequestFetchUser with \(OS_ONESIGNAL_ID): \(onesignalId)>"
        super.init()
        self.method = GET
    }

    func encode(with coder: NSCoder) {
        coder.encode(onesignalId, forKey: "onesignalId")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(onNewSession, forKey: "onNewSession")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let onesignalId = coder.decodeObject(forKey: "onesignalId") as? String,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.onesignalId = onesignalId
        self.onNewSession = coder.decodeBool(forKey: "onNewSession")
        self.stringDescription = "<OSRequestFetchUser with \(OS_ONESIGNAL_ID): \(onesignalId)>"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
    }
}
