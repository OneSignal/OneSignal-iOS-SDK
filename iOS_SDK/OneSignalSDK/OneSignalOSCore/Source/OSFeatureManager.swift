/*
 Modified MIT License

 Copyright 2026 OneSignal

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

/// Backend-driven feature switches keyed by remote-config identifiers.
public enum OSFeatureFlag: String {
    case identityVerification = "sdk_identity_verification"
}

public protocol OSFeatureManagerProtocol: AnyObject {
    func isEnabled(_ feature: OSFeatureFlag) -> Bool
}

/**
 Resolves which features are enabled for this run.
 Flags take effect as soon as they are set so a kill switch does not need a cold start; the set is
 cached so a launch that has not yet fetched remote config keeps the last known values.
 */
public final class OSFeatureManager: OSFeatureManagerProtocol {
    /// Shared for the same reason as `OSUserJwtConfig.shared`, and under the same rule: only
    /// `OneSignalUserManagerImpl` references it today, and `OneSignal.m` will once remote params
    /// deliver flag keys. Everything below them is handed the feature manager when it is created.
    public static let shared = OSFeatureManager()

    /**
     Local-only test hook for forcing features ON without backend config.
     Add keys here while bug-bashing, e.g. `[OSFeatureFlag.identityVerification.rawValue]`, and revert
     before commit.
     */
    private static let localFeatureOverrides: Set<String> = []
    // private static let localFeatureOverrides: Set<String> = [
    //     OSFeatureFlag.identityVerification.rawValue
    // ]

    private let lock = NSLock()
    private var enabledKeys: Set<String>

    public init() {
        enabledKeys = OSFeatureManager.cachedKeys()
        OSFeatureManager.warnIfLocalOverrides()
    }

    /// Bypasses the cache so tests and local overrides can force flags on.
    public init(enabledKeys: Set<String>) {
        self.enabledKeys = Set(enabledKeys.map(OSFeatureManager.canonicalize))
        OSFeatureManager.warnIfLocalOverrides()
    }

    public func isEnabled(_ feature: OSFeatureFlag) -> Bool {
        return lock.withLock {
            enabledKeys.contains(feature.rawValue)
                || OSFeatureManager.localFeatureOverrides.contains(feature.rawValue)
        }
    }

    public func setEnabledFeatureKeys(_ keys: [String]) {
        let canonical = Set(keys.map(OSFeatureManager.canonicalize))
        lock.withLock {
            enabledKeys = canonical
            OneSignalUserDefaults.initShared().saveObject(forKey: OSUD_SDK_FEATURE_FLAGS, withValue: Array(canonical))
        }
    }

    /**
     Re-reads the cached keys while none are known, closing the same prewarm gap as
     `OSUserJwtConfig.refreshIfUnknown`. An app with every flag off reads the cache a second time, which
     is cheaper than keeping enough state to tell that case apart from a read that came back empty.
     */
    public func refreshIfEmpty() {
        lock.withLock {
            guard enabledKeys.isEmpty else {
                return
            }
            enabledKeys = OSFeatureManager.cachedKeys()
        }
    }

    // Fold case so a differently cased remote key still matches a flag.
    private static func canonicalize(_ key: String) -> String {
        return key.lowercased()
    }

    private static func cachedKeys() -> Set<String> {
        guard let cached = OneSignalUserDefaults.initShared().getSavedObject(forKey: OSUD_SDK_FEATURE_FLAGS, defaultValue: nil) as? [String] else {
            return []
        }
        return Set(cached.map(canonicalize))
    }

    private static func warnIfLocalOverrides() {
        let overrides = Set(localFeatureOverrides.map(canonicalize))
        guard !overrides.isEmpty else {
            return
        }
        OneSignalLog.onesignalLog(
            .LL_WARN,
            message: "OSFeatureManager: local feature override enabled for testing only: \(overrides)"
        )
    }
}
