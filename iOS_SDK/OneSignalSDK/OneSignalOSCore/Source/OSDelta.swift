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

import Foundation

// TODO: Known Issue: Since these don't carry the app_id, it may have changed by the time Deltas become Requests, if app_id changes.
// All requests requiring unique ID's will effectively be dropped.

open class OSDelta: NSObject, NSCoding {
    public let name: String
    public let deltaId: String
    public let timestamp: Date
    public var model: OSModel
    public let property: String
    public let value: Any

    override open var description: String {
        return "OSDelta \(name) with property: \(property) value: \(value)"
    }

    public init(name: String, model: OSModel, property: String, value: Any) {
        self.name = name
        self.deltaId = UUID().uuidString
        self.timestamp = Date()
        self.model = model
        self.property = property
        self.value = value
    }

    public func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(deltaId, forKey: "deltaId")
        coder.encode(timestamp, forKey: "timestamp")
        coder.encode(model, forKey: "model")
        coder.encode(property, forKey: "property")
        coder.encode(value, forKey: "value")
    }

    public required init?(coder: NSCoder) {
        guard let name = coder.decodeObject(forKey: "name") as? String,
              let deltaId = coder.decodeObject(forKey: "deltaId") as? String,
              let timestamp = coder.decodeObject(forKey: "timestamp") as? Date,
              let model = coder.decodeObject(forKey: "model") as? OSModel,
              let property = coder.decodeObject(forKey: "property") as? String,
              let value = coder.decodeObject(forKey: "value")
        else {
            // Log error
            return nil
        }

        self.name = name
        self.deltaId = deltaId
        self.timestamp = timestamp
        self.model = model
        self.property = property
        self.value = value
    }
}
