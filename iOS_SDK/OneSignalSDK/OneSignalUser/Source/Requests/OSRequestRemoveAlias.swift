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

class OSRequestRemoveAlias: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let labelToRemove: String
    var identityModel: OSIdentityModel

    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId, let appId = OneSignalConfigManager.getAppId() {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/identity/\(labelToRemove)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(labelToRemove: String, identityModel: OSIdentityModel) {
        self.labelToRemove = labelToRemove
        self.identityModel = identityModel
        self.stringDescription = "OSRequestRemoveAlias with aliasLabel: \(labelToRemove)"
        super.init()
        self.method = DELETE
        _ = prepareForExecution() // sets the path property
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
        _ = prepareForExecution()
    }
}
