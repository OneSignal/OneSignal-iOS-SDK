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
import OneSignalCore
import OneSignalOSCore

class OSIdentityModel: OSModel {
    var onesignalId: String? {
        return aliases[OS_ONESIGNAL_ID]
    }

    var externalId: String? {
        return aliases[OS_EXTERNAL_ID]
    }

    var aliases: [String: String] = [:]
    
    // TODO: We need to make this token secure
    public var jwtBearerToken: String?

    // MARK: - Initialization

    // Initialize with aliases, if any
    init(aliases: [String: String]?, changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        super.init(changeNotifier: changeNotifier)
        self.aliases = aliases ?? [:]
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(aliases, forKey: "aliases")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        guard let aliases = coder.decodeObject(forKey: "aliases") as? [String: String] else {
            // log error
            return nil
        }
        self.aliases = aliases
    }

    // MARK: - Alias Methods

    func addAliases(_ aliases: [String: String]) {
        print("🔥 OSIdentityModel.addAliases \(aliases).")
        for (label, id) in aliases {
            self.aliases[label] = id
        }
        self.set(property: "aliases", newValue: aliases)
    }

    func removeAliases(_ labels: [String]) {
        print("🔥 OSIdentityModel.removeAliases \(labels).")
        var aliasesToSend: [String: String] = [:]
        for label in labels {
            self.aliases.removeValue(forKey: label)
            aliasesToSend[label] = ""
        }
        self.set(property: "aliases", newValue: aliasesToSend)
    }

    public override func hydrateModel(_ response: [String: Any]) {
        print("🔥 OSIdentityModel hydrateModel()")
        // TODO: Update Model properties with the response
        for property in response {
            switch property.key {
            case "external_id":
                aliases[OS_EXTERNAL_ID] = property.value as? String
            case "onesignal_id":
                aliases[OS_ONESIGNAL_ID] = property.value as? String
            default:
                aliases[property.key] = property.value as? String
            }
        }
    }
}
