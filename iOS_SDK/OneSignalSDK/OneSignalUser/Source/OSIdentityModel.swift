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
import OneSignalOSCore

class OSIdentityModel: OSModel {
    var onesignalId: UUID? // let? optional?

    var externalId: String? { // let? optional?
        didSet {
            print("🔥 didSet OSIdentityModel.externalId from \(oldValue) to \(externalId!).")
            self.set(property: "externalId", oldValue: oldValue, newValue: externalId)
        }
    }

    var aliases: [String: String] = [:]

    // MARK: - Initialization

    // We seem to lose access to this init() in superclass after adding init?(coder: NSCoder)
    override init(changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        super.init(changeNotifier: changeNotifier)
    }
    
    init(externalId: String?, changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        self.externalId = externalId // TODO: check didSet is not called
        super.init(changeNotifier: changeNotifier)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(onesignalId, forKey: "onesignalId")
        coder.encode(externalId, forKey: "externalId")
        coder.encode(aliases, forKey: "aliases")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        onesignalId = coder.decodeObject(forKey: "onesignalId") as? UUID
        externalId = coder.decodeObject(forKey: "externalId") as? String
        guard let aliases = coder.decodeObject(forKey: "aliases") as? [String: String] else {
            // log error
            return
        }
        self.aliases = aliases
    }

    // MARK: - Alias Methods

    func addAlias(label: String, id: String) {
        // Don't let them use `onesignal_id` as an alias label
        // Don't let them use `external_id` either?
        print("🔥 OSIdentityModel.addAlias \(label) : \(id).")
        let oldValue: String? = aliases[label]
        aliases[label] = id
        self.set(property: "aliases", oldValue: ["label": label, "id": oldValue], newValue: ["label": label, "id": id])
    }

    func removeAlias(_ label: String) {
        print("🔥 OSIdentityModel.removeAlias \(label).")
        // TODO: create a delta even if this alias does not exist locally.
        if let oldValue = aliases.removeValue(forKey: label) {
            // Cannot encode a nil value
            self.set(property: label, oldValue: oldValue, newValue: "")
        }
    }

    public override func hydrateModel(_ response: [String: String]) {
        print("🔥 OSIdentityModel hydrateModel()")
        // TODO: Update Model properties with the response
        // Flesh out implementation and how to parse the response, deleted aliases...
        for property in response {
            if property.key != "external_id" && property.key != "onesignal_id" {
                aliases[property.key] = property.value
            }
        }
    }
}
