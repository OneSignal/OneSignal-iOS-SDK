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
 If an alias is passed in, it will be used to fetch the user. If not, then by default, use the `onesignal_id` in the `identityModel` to fetch the user.
 The `identityModel` is also used to reference the user that is updated with the response.
 */
class OSRequestFetchUser: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    let identityModel: OSIdentityModel
    let aliasLabel: String
    let aliasId: String
    let onNewSession: Bool

    func prepareForExecution() -> Bool {
        guard let appId = OneSignalConfigManager.getAppId() else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot generate the fetch user request due to null app ID.")
            return false
        }
        self.addJWTHeader(identityModel: identityModel)
        self.path = "apps/\(appId)/users/by/\(aliasLabel)/\(aliasId)"
        return true
    }

    init(identityModel: OSIdentityModel, aliasLabel: String, aliasId: String, onNewSession: Bool) {
        self.identityModel = identityModel
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.onNewSession = onNewSession
        self.stringDescription = "OSRequestFetchUser with aliasLabel: \(aliasLabel) aliasId: \(aliasId)"
        super.init()
        self.method = GET
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(aliasLabel, forKey: "aliasLabel")
        coder.encode(aliasId, forKey: "aliasId")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(onNewSession, forKey: "onNewSession")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let aliasLabel = coder.decodeObject(forKey: "aliasLabel") as? String,
            let aliasId = coder.decodeObject(forKey: "aliasId") as? String,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.aliasLabel = aliasLabel
        self.aliasId = aliasId
        self.onNewSession = coder.decodeBool(forKey: "onNewSession")
        self.stringDescription = "OSRequestFetchUser with aliasLabel: \(aliasLabel) aliasId: \(aliasId)"
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}
