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

// By matching the enum name to the raw value, it will always stringify correctly
enum OSDefaultAlias: String {
    // swiftlint:disable identifier_name
    case onesignal_id = "onesignal_id"
    case external_id = "external_id"
    // swiftlint:enable identifier_name
}

class OSIdentityModel: OSModel {
    /**
     Set either `onesignal_id` or `external_id`, representing the alias that will be used in requests.
     */
    var primaryAliasLabel: OSDefaultAlias = .onesignal_id
    var primaryAliasId: String? {
        return if primaryAliasLabel == .external_id { externalId } else { onesignalId }
    }

    var onesignalId: String? {
        return internalGetAlias(OS_ONESIGNAL_ID)
    }

    var externalId: String? {
        return internalGetAlias(OS_EXTERNAL_ID)
    }

    // All access to aliases should go through helper methods with locking
    var aliases: [String: String] = [:]
    private let aliasesLock = NSRecursiveLock()

    public var jwtToken: String? {
        didSet {
            guard jwtToken != oldValue else {
                return
            }
            self.set(property: "jwtToken", newValue: jwtToken, hydrating: true)
            guard let euid = externalId else { return }
            OneSignalUserManagerImpl.sharedInstance.jwtConfig.onJwtTokenChanged(externalId: euid, from: oldValue, to: jwtToken)
        }
    }
    
    func isJwtValid() -> Bool {
        return jwtToken != nil && jwtToken != "" && jwtToken != "invalid"
    }

    // MARK: - Initialization

    // Initialize with aliases, if any
    init(aliases: [String: String]?, changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        super.init(changeNotifier: changeNotifier)
        self.aliases = aliases ?? [:]
    }

    override func encode(with coder: NSCoder) {
        aliasesLock.withLock {
            super.encode(with: coder)
            coder.encode(aliases, forKey: "aliases")
            coder.encode(jwtToken, forKey: "jwtToken")
            coder.encode(primaryAliasLabel.rawValue, forKey: "primaryAliasLabel") // Encodes as String
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        guard let aliases = coder.decodeObject(forKey: "aliases") as? [String: String] else {
            // log error
            return nil
        }
        if let rawType = coder.decodeObject(forKey: "primaryAliasLabel") as? String,
           let label = OSDefaultAlias(rawValue: rawType) {
            self.primaryAliasLabel = label
        } else {
            self.primaryAliasLabel = .onesignal_id
        }
        self.jwtToken = coder.decodeObject(forKey: "jwtToken") as? String
        self.aliases = aliases
    }

    /** Threadsafe getter for an alias */
    private func internalGetAlias(_ label: String) -> String? {
        aliasesLock.withLock {
            return self.aliases[label]
        }
    }

    /** Threadsafe setter or removal for aliases */
    private func internalAddAliases(_ aliases: [String: String]) {
        aliasesLock.withLock {
            for (label, id) in aliases {
                // Remove the alias if the ID field is ""
                self.aliases[label] = id.isEmpty ? nil : id
            }
        }
        self.set(property: "aliases", newValue: aliases)
        
    }

    /**
     Called to clear the model's data in preparation for hydration via a fetch user call.
     */
    func clearData() {
        aliasesLock.withLock {
            self.aliases = [:]
        }
    }

    // MARK: - Alias Methods

    func addAliases(_ aliases: [String: String]) {
        internalAddAliases(aliases)
    }

    func removeAliases(_ labels: [String]) {
        let aliasesToRemoveAsDict = labels.reduce(into: [String: String]()) { result, label in
            result[label] = ""
        }
        internalAddAliases(aliasesToRemoveAsDict)
    }

    public override func hydrateModel(_ response: [String: Any]) {
        guard let remoteAliases = response as? [String: String] else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityModel.hydrateModel failed to parse response \(response) as Strings")
            return
        }

        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSIdentityModel hydrateModel with aliases: \(remoteAliases)")
        let newOnesignalId = remoteAliases[OS_ONESIGNAL_ID]
        let newExternalId = remoteAliases[OS_EXTERNAL_ID]

        internalAddAliases(remoteAliases)
        fireUserStateChanged(newOnesignalId: newOnesignalId, newExternalId: newExternalId)
    }

    /**
     Fires the user observer if `onesignal_id` OR `external_id` has changed from the previous snapshot (previous hydration).
     */
    private func fireUserStateChanged(newOnesignalId: String?, newExternalId: String?) {
        let prevOnesignalId  = OneSignalUserDefaults.initShared().getSavedString(forKey: OS_SNAPSHOT_ONESIGNAL_ID, defaultValue: nil)
        let prevExternalId = OneSignalUserDefaults.initShared().getSavedString(forKey: OS_SNAPSHOT_EXTERNAL_ID, defaultValue: nil)

        guard prevOnesignalId != newOnesignalId || prevExternalId != newExternalId else {
            return
        }

        OneSignalUserDefaults.initShared().saveString(forKey: OS_SNAPSHOT_ONESIGNAL_ID, withValue: newOnesignalId)
        OneSignalUserDefaults.initShared().saveString(forKey: OS_SNAPSHOT_EXTERNAL_ID, withValue: newExternalId)

        let curUserState = OSUserState(onesignalId: newOnesignalId, externalId: newExternalId)
        let changedState = OSUserChangedState(current: curUserState)

        OneSignalUserManagerImpl.sharedInstance.userStateChangesObserver.notifyChange(changedState)
    }
}
