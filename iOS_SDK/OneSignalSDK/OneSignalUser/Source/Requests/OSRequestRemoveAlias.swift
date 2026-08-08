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

class OSRequestRemoveAlias: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let labelToRemove: String
    var identityModel: OSIdentityModel

    /// See the ownership convention in `OSUserRequest.swift`.
    let ownerExternalId: String?

    func prepareForExecution(newRecordsState: OSNewRecordsState, auth: OSRequestAuthorizing) -> Bool {
        if let onesignalId = identityModel.onesignalId,
           newRecordsState.canAccess(onesignalId),
           let appId = OneSignalIdentifiers.currentAppId,
           let alias = auth.authorizeUserScoped(self, legacyAlias: OSAliasPair(OS_ONESIGNAL_ID, onesignalId))
        {
            self.path = "apps/\(appId)/users/by/\(alias.label)/\(alias.id)/identity/\(labelToRemove)"
            return true
        } else {
            return false
        }
    }

    init(labelToRemove: String, identityModel: OSIdentityModel, ownerExternalId: String?) {
        self.labelToRemove = labelToRemove
        self.identityModel = identityModel
        self.ownerExternalId = ownerExternalId
        self.stringDescription = "OSRequestRemoveAlias with aliasLabel: \(labelToRemove)"
        super.init()
        self.method = DELETE
    }

    func encode(with coder: NSCoder) {
        coder.encode(labelToRemove, forKey: "labelToRemove")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(ownerExternalId, forKey: "ownerExternalId")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let labelToRemove = coder.decodeObject(forKey: "labelToRemove") as? String,
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.labelToRemove = labelToRemove
        self.identityModel = identityModel
        self.ownerExternalId = coder.decodeObject(forKey: "ownerExternalId") as? String
        self.stringDescription = "OSRequestRemoveAlias with aliasLabel: \(labelToRemove)"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
    }
}
