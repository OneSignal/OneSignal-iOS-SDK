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
        return internalGetAlias(OS_ONESIGNAL_ID)
    }

    var externalId: String? {
        return internalGetAlias(OS_EXTERNAL_ID)
    }

    // All access to aliases and the JWT bearer token must go through the lock
    var aliases: [String: String] = [:]
    private let lock = NSRecursiveLock()

    // MARK: - JWT

    private var jwtBearerTokenLocked: String?
    public var jwtBearerToken: String? {
        get {
            lock.withLock { jwtBearerTokenLocked }
        }
        set {
            // Notify outside the lock: the change notifier fires synchronously into listeners that
            // take locks of their own.
            let changed = lock.withLock {
                guard newValue != jwtBearerTokenLocked else { return false }
                jwtBearerTokenLocked = newValue
                return true
            }
            if changed {
                self.set(property: OS_JWT_BEARER_TOKEN, newValue: newValue, preventServerUpdate: true)
            }
        }
    }

    /// Returns the bearer token if it is valid, otherwise nil, snapshots once
    func getValidJwt() -> String? {
        let token = jwtBearerToken
        guard let token = token, !token.isEmpty, token != OS_JWT_TOKEN_INVALID else {
            return nil
        }
        return token
    }

    /// Returns `true` if the transition occurred, `false` if `rejectedToken` is no longer the stored
    /// token. Comparing against the rejected token rather than the sentinel is what keeps a failure
    /// response that was already in flight from parking the replacement supplied after it left.
    @discardableResult
    func invalidateJwtBearerToken(rejectedToken: String) -> Bool {
        let changed = lock.withLock {
            guard jwtBearerTokenLocked == rejectedToken else { return false }
            jwtBearerTokenLocked = OS_JWT_TOKEN_INVALID
            return true
        }
        if changed {
            self.set(property: OS_JWT_BEARER_TOKEN, newValue: OS_JWT_TOKEN_INVALID, preventServerUpdate: true)
        }
        return changed
    }

    // MARK: - Initialization

    // Initialize with aliases, if any
    init(aliases: [String: String]?, changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        super.init(changeNotifier: changeNotifier)
        self.aliases = aliases ?? [:]
    }

    override func encode(with coder: NSCoder) {
        lock.withLock {
            super.encode(with: coder)
            coder.encode(aliases, forKey: "aliases")
            coder.encode(jwtBearerTokenLocked, forKey: OS_JWT_BEARER_TOKEN)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        guard let aliases = coder.decodeObject(forKey: "aliases") as? [String: String] else {
            // log error
            return nil
        }
        self.jwtBearerTokenLocked = coder.decodeObject(forKey: OS_JWT_BEARER_TOKEN) as? String
        self.aliases = aliases
    }

    /** Threadsafe getter for an alias */
    private func internalGetAlias(_ label: String) -> String? {
        lock.withLock {
            return self.aliases[label]
        }
    }

    /** Threadsafe setter or removal for aliases */
    private func internalAddAliases(_ aliases: [String: String]) {
        lock.withLock {
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
        lock.withLock {
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
        // Reporting the user to the app is the executor's call, since only a current user may be reported.
        internalAddAliases(remoteAliases)
    }
}

/**
 Owns the last user state the app was told about, so the observer only hears real changes.

 The User executor reports a hydrated current user through `fireUserStateChangedIfCurrent`, and `logout`
 under Identity Verification also reports here: it creates no user on the server, so there is no
 hydration to carry the news that nobody is signed in.
 */
enum OSUserStateSnapshot {
    /**
     Reports the hydrated user to the app, but only while that user is still current. A Create User or
     Identify User for a user the app has since switched away from still hydrates its model, since the
     Requests queued behind it need the `onesignal_id`, but the app must not hear that user as signed in,
     and the persisted pair must keep naming the current user, or the current user's real state would
     later read as unchanged and go unreported.
     */
    static func fireUserStateChangedIfCurrent(_ identityModel: OSIdentityModel) {
        guard OneSignalUserManagerImpl.sharedInstance.currentUser(matching: identityModel.modelId) != nil else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSUserStateSnapshot not reporting a hydrated user who is no longer current")
            return
        }
        fireUserStateChanged(newOnesignalId: identityModel.onesignalId, newExternalId: identityModel.externalId)
    }

    /// Fires the user observer if `onesignal_id` OR `external_id` differs from the last reported pair.
    static func fireUserStateChanged(newOnesignalId: String?, newExternalId: String?) {
        let prevOnesignalId = OneSignalUserDefaults.initShared().getSavedString(forKey: OS_SNAPSHOT_ONESIGNAL_ID, defaultValue: nil)
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
