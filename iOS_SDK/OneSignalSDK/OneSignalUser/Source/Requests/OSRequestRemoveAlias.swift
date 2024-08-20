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

    /// Needs `onesignal_id` without JWT on or `external_id` with valid JWT to send this request
    func prepareForExecution(newRecordsState: OSNewRecordsState) -> Bool {
        let alias = getAlias(identityModel: identityModel)
        guard
            let onesignalId = identityModel.onesignalId,
            newRecordsState.canAccess(onesignalId),
            let aliasIdToUse = alias.id,
            let appId = OneSignalConfigManager.getAppId(),
            addJWTHeaderIsValid(identityModel: identityModel)
        else {
            return false
        }

        self.path = "apps/\(appId)/users/by/\(alias.label)/\(aliasIdToUse)/identity/\(labelToRemove)"
        return true
    }

    init(labelToRemove: String, identityModel: OSIdentityModel) {
        self.labelToRemove = labelToRemove
        self.identityModel = identityModel
        self.stringDescription = "OSRequestRemoveAlias with aliasLabel: \(labelToRemove)"
        super.init()
        self.method = DELETE
    }

    func encode(with coder: NSCoder) {
        coder.encode(labelToRemove, forKey: "labelToRemove")
        coder.encode(identityModel, forKey: "identityModel")
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
        self.stringDescription = "OSRequestRemoveAlias with aliasLabel: \(labelToRemove)"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
    }
}
