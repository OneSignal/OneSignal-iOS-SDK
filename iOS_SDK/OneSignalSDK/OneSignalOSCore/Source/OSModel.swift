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

@objc
open class OSModel: NSObject, NSCoding {
    public let modelId: String
    public var changeNotifier: OSEventProducer<OSModelChangedHandler>
    private var hydrating = false // TODO: Starts out false?

    public init(changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        self.modelId = UUID().uuidString
        self.changeNotifier = changeNotifier
    }

    open func encode(with coder: NSCoder) {
        coder.encode(modelId, forKey: "modelId")
    }

    public required init?(coder: NSCoder) {
        guard let modelId = coder.decodeObject(forKey: "modelId") as? String else {
            // log error
            return nil
        }
        self.changeNotifier = OSEventProducer()
        self.modelId = modelId
    }

    // We can add operation name to this... , such as enum of "updated", "deleted", "added"
    public func set<T>(property: String, newValue: T) {
        let changeArgs = OSModelChangedArgs(model: self, property: property, newValue: newValue)

        changeNotifier.fire { modelChangeHandler in
            modelChangeHandler.onModelUpdated(args: changeArgs, hydrating: self.hydrating)
        }
    }

    /**
     This function receives a server response and updates the model's properties.
     */
    public func hydrate(_ response: [String: Any]) {
        // TODO: Thread safety when processing server responses to hydrate models.
        self.hydrating = true
        hydrateModel(response) // Calls model-specific hydration logic
        self.hydrating = false
    }

    open func hydrateModel(_ response: [String: Any]) {
        fatalError("hydrateModel(response:) has not been implemented")
    }
}
