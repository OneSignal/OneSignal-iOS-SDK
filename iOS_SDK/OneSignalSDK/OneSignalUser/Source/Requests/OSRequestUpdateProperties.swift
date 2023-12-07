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

class OSRequestUpdateProperties: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    // TODO: does updating properties even have a response in which we need to hydrate from? Then we can get rid of modelToUpdate
    // Yes we may, if we cleared local state
    var modelToUpdate: OSPropertiesModel
    var identityModel: OSIdentityModel

    // TODO: Decide if addPushSubscriptionIdToAdditionalHeadersIfNeeded should block.
    // Note Android adds it to requests, if the push sub ID exists
    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId,
            let appId = OneSignalConfigManager.getAppId(),
           addPushSubscriptionIdToAdditionalHeadersIfNeeded() {
            self.addJWTHeader(identityModel: identityModel)
            self.path = "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    func addPushSubscriptionIdToAdditionalHeadersIfNeeded() -> Bool {
        guard let parameters = self.parameters else {
            return true
        }
        if parameters["deltas"] != nil { // , !parameters["deltas"].isEmpty
            if let pushSubscriptionId = OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId {
                var additionalHeaders = self.additionalHeaders ?? [String: String]()
                additionalHeaders["OneSignal-Subscription-Id"] = pushSubscriptionId
                self.additionalHeaders = additionalHeaders
                return true
            } else {
                return false
            }
        }
        return true
    }

    init(properties: [String: Any], deltas: [String: Any]?, refreshDeviceMetadata: Bool?, modelToUpdate: OSPropertiesModel, identityModel: OSIdentityModel) {
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        self.stringDescription = "OSRequestUpdateProperties with properties: \(properties) deltas: \(String(describing: deltas)) refreshDeviceMetadata: \(String(describing: refreshDeviceMetadata))"
        super.init()

        var propertiesObject = properties
        if let location = propertiesObject["location"] as? OSLocationPoint {
            propertiesObject["lat"] = location.lat
            propertiesObject["long"] = location.long
            propertiesObject.removeValue(forKey: "location")
        }
        var params: [String: Any] = [:]
        params["properties"] = propertiesObject
        params["refresh_device_metadata"] = refreshDeviceMetadata
        if let deltas = deltas {
            params["deltas"] = deltas
        }
        self.parameters = params
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(modelToUpdate, forKey: "modelToUpdate")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let modelToUpdate = coder.decodeObject(forKey: "modelToUpdate") as? OSPropertiesModel,
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        self.stringDescription = "OSRequestUpdateProperties with parameters: \(parameters)"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
        _ = prepareForExecution()
    }
}
