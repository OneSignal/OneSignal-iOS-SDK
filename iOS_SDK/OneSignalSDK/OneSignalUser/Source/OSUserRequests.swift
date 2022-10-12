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

protocol OSUserRequest: OneSignalRequest, NSCoding {
    func prepareForExecution() -> Bool
}

// Confirm the type of the things in the parameters field
// Don't hardcode strings?

// Let's touch this later...
class OSRequestCreateUser: OneSignalRequest, NSCoding {
    // We need to pass in all 3 model types (?) even if we don't send them all, for hydration
    init(identity: [String: String]?, properties: [String: Any]?, subscriptions: [[String: Any]]?) {
        super.init()

        var params: [String: Any] = [:]
        params["identity"] = identity
        params["properties"] = properties
        params["subscriptions"] = subscriptions

        self.parameters = params
        self.method = POST
        self.path = "user"
    }

    func encode(with coder: NSCoder) {
        //
    }

    required init?(coder: NSCoder) {
        //
    }
}

class OSRequestFetchUser: OneSignalRequest, OSUserRequest {
    let identityModel: OSIdentityModel

    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId {
            self.path = "user/by/\(OS_ONESIGNAL_ID)/\(onesignalId)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(identityModel: OSIdentityModel) {
        self.identityModel = identityModel
        super.init()
        self.method = GET
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32
        else {
            // TODO: Log error
            return nil
        }
        self.identityModel = identityModel
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        _ = prepareForExecution()
    }
}

class OSRequestAddAliases: OneSignalRequest, OSUserRequest {
    let modelToUpdate: OSIdentityModel

    func prepareForExecution() -> Bool {
        if let onesignalId = modelToUpdate.onesignalId {
            self.path = "user/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/identity"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(identity: [String: String], modelToUpdate: OSIdentityModel) {
        self.modelToUpdate = modelToUpdate
        super.init()
        self.parameters = ["identity": identity]
        self.method = POST
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(modelToUpdate, forKey: "modelToUpdate")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
    }

    required init?(coder: NSCoder) {
        guard
            let modelToUpdate = coder.decodeObject(forKey: "modelToUpdate") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: [String: String]]
        else {
            // TODO: Log error
            return nil
        }
        self.modelToUpdate = modelToUpdate
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        _ = prepareForExecution()
    }
}

class OSRequestRemoveAlias: OneSignalRequest, OSUserRequest {
    let labelToRemove: String
    let modelToUpdate: OSIdentityModel

    func prepareForExecution() -> Bool {
        if let onesignalId = modelToUpdate.onesignalId {
            self.path = "user/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/identity/\(labelToRemove)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(labelToRemove: String, modelToUpdate: OSIdentityModel) {
        self.labelToRemove = labelToRemove
        self.modelToUpdate = modelToUpdate
        super.init()
        self.method = DELETE
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(labelToRemove, forKey: "labelToRemove")
        coder.encode(modelToUpdate, forKey: "modelToUpdate")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
    }

    required init?(coder: NSCoder) {
        guard
            let labelToRemove = coder.decodeObject(forKey: "labelToRemove") as? String,
            let modelToUpdate = coder.decodeObject(forKey: "modelToUpdate") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32
        else {
            // TODO: Log error
            return nil
        }
        self.labelToRemove = labelToRemove
        self.modelToUpdate = modelToUpdate
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        _ = prepareForExecution()
    }
}

class OSRequestUpdateProperties: OneSignalRequest, OSUserRequest {
    let modelToUpdate: OSPropertiesModel
    let identityModel: OSIdentityModel

    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId {
            self.path = "user/by/\(OS_ONESIGNAL_ID)/\(onesignalId)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(properties: [String: Any], deltas: [String: Any]?, refreshDeviceMetadata: Bool?, modelToUpdate: OSPropertiesModel, identityModel: OSIdentityModel) {
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        super.init()

        var params: [String: Any] = [:]
        params["properties"] = properties
        params["deltas"] = deltas
        params["refresh_device_metadata"] = refreshDeviceMetadata

        self.parameters = params
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(modelToUpdate, forKey: "modelToUpdate")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
    }

    required init?(coder: NSCoder) {
        guard
            let modelToUpdate = coder.decodeObject(forKey: "modelToUpdate") as? OSPropertiesModel,
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any]
        else {
            // TODO: Log error
            return nil
        }
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        _ = prepareForExecution()
    }
}

// TODO: Address push token
class OSRequestCreateSubscription: OneSignalRequest, OSUserRequest {
    let modelToUpdate: OSSubscriptionModel
    let identityModel: OSIdentityModel

    func prepareForExecution() -> Bool {
        if let onesignalId = identityModel.onesignalId {
            self.path = "user/by/\(OS_ONESIGNAL_ID)/\(onesignalId)/subscription"
            return true
        } else {
            self.path = "" // self.path is non-nil, so set to empty string
            return false
        }
    }

    init(type: OSSubscriptionType, address: String?, enabled: Bool, modelToUpdate: OSSubscriptionModel, identityModel: OSIdentityModel) {
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        super.init()

        var subscriptionParams: [String: Any] = [:]
        subscriptionParams["type"] = type.rawValue
        subscriptionParams["token"] = address
        subscriptionParams["enabled"] = enabled

        // TODO: Add more to `subscriptionParams`

        self.parameters = ["subscription": subscriptionParams]
        self.method = POST
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(modelToUpdate, forKey: "modelToUpdate")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
    }

    required init?(coder: NSCoder) {
        guard
            let modelToUpdate = coder.decodeObject(forKey: "modelToUpdate") as? OSSubscriptionModel,
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any]
        else {
            // TODO: Log error
            return nil
        }
        self.modelToUpdate = modelToUpdate
        self.identityModel = identityModel
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        _ = prepareForExecution()
    }
}

/**
 Currently, only the Push Subscription will make this Update Request.
 */
class OSRequestUpdateSubscription: OneSignalRequest, OSUserRequest {
    let modelToUpdate: OSSubscriptionModel

    func prepareForExecution() -> Bool {
        if let subscriptionId = modelToUpdate.subscriptionId {
            self.path = "subscriptions/\(subscriptionId)"
            return true
        } else {
            self.path = "" // self.path is non-nil, so set to empty string
            return false
        }
    }

    init(subscriptionObject: [String: String], modelToUpdate: OSSubscriptionModel) {
        self.modelToUpdate = modelToUpdate
        super.init()

        var subscriptionParams: [String: Any] = [:]
        subscriptionParams["token"] = subscriptionObject["address"]
        subscriptionParams["enabled"] = subscriptionObject["enabled"]

        self.parameters = ["subscription": subscriptionParams]
        self.method = PATCH
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(modelToUpdate, forKey: "modelToUpdate")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
    }

    required init?(coder: NSCoder) {
        guard
            let modelToUpdate = coder.decodeObject(forKey: "modelToUpdate") as? OSSubscriptionModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any]
        else {
            // TODO: Log error
            return nil
        }
        self.modelToUpdate = modelToUpdate
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        _ = prepareForExecution()
    }
}

// TODO: Keep the a modelToUpdate to respond to request's response?
// Note that the model has already been removed from the Model Store
// If no subID exist, we wil Fetch User
class OSRequestDeleteSubscription: OneSignalRequest, OSUserRequest {
    var subscriptionId: String?

    func prepareForExecution() -> Bool {
        if let subscriptionId {
            self.path = "subscriptions/\(subscriptionId)"
            return true
        } else {
            // self.path is non-nil, so set to empty string
            self.path = ""
            return false
        }
    }

    init(subscriptionId: String?) {
        super.init()
        self.subscriptionId = subscriptionId
        self.method = DELETE
        _ = prepareForExecution() // sets the path property
    }

    func encode(with coder: NSCoder) {
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
    }

    required init?(coder: NSCoder) {
        guard let rawMethod = coder.decodeObject(forKey: "method") as? UInt32
        else {
            // TODO: Log error
            return nil
        }
        super.init()
        self.method = HTTPMethod(rawValue: rawMethod)
        _ = prepareForExecution()
    }
}
