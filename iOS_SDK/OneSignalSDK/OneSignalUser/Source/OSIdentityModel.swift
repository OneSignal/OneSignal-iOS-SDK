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
    var onesignalId: UUID?

    var externalId: String? {
        didSet  {
            guard self.hydrating else {
                print("🔥 didSet OSIdentityModel.externalId from \(oldValue) to \(externalId!).")
                self.set(property: "externalId", oldValue: oldValue, newValue: externalId)
                return
            }
        }
    }
    var aliases: [String : String] = [:]
    
    func setAlias(label: String, id: String) {
        guard self.hydrating else {
            print("🔥 OSIdentityModel.setAlias \(label) : \(id).")
            let oldValue: String? = aliases[label]
            aliases[label] = id
            self.set(property: label, oldValue: oldValue, newValue: id)
            return
        }
    }
    
    func removeAlias(_ label: String) {
        guard self.hydrating else {
            print("🔥 OSIdentityModel.removeAlias \(label).")
            if let oldValue = aliases.removeValue(forKey: label) {
                self.set(property: label, oldValue: oldValue, newValue: nil)
            }
            return
        }
    }
    
    public override func hydrate(_ response: [String : String]) {
        print("🔥 OSIdentityModel hydrate()")
        self.hydrating = true
        // TODO: Update Model properties with the response
        // Flesh out implementation and how to parse the response, deleted aliases...
        for property in response {
            if property.key != "external_id" && property.key != "onesignal_id" {
                aliases[property.key] = property.value
            }
        }
        self.hydrating = false
    }
}
