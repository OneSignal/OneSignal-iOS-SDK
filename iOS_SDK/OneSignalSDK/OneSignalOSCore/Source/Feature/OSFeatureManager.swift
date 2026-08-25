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

/// Resolves backend-driven feature flag state for the current device run.
/// Catalog and latching live in shared KMP `FeatureManager`; this host hydrates
/// from `OSFeatureFlagsStore` and applies activation-mode rules via `refresh`.
@objc(OSFeatureManager)
public final class OSFeatureManager: NSObject {
    private static let lock = NSLock()
    private static var _shared: OSFeatureManager?
    /// Bumped by `reset()`. Construction happens outside the lock, so this is what tells
    /// a builder that the state it read has since been invalidated.
    private static var generation = 0

    /// Constructing this reads persisted flags and builds the KMP latch, so the first
    /// access decides which `APP_STARTUP` flags are latched for the process. Only touch
    /// it once storage is readable; see `enabledFeatureKeysIfInitialized()`.
    @objc public static var shared: OSFeatureManager {
        while true {
            let (existing, startGeneration) = lock.withLock { (_shared, generation) }
            if let existing {
                return existing
            }
            // Built outside the lock on purpose: construction reads storage and logs, and
            // logging reaches back through the feature-flag provider. Holding the lock
            // across that would risk re-entering it on the same thread.
            let created = OSFeatureManager()
            didConstructForTesting?()
            let published: OSFeatureManager? = lock.withLock {
                if let existing = _shared {
                    return existing
                }
                // A reset landed while we were reading storage, so this instance latched
                // the previous app id's flags. Publishing it would restore exactly the
                // stale latch the reset existed to drop.
                guard generation == startGeneration else {
                    return nil
                }
                _shared = created
                return created
            }
            if let published {
                return published
            }
        }
    }

    /// Enabled keys *without* forcing construction, for callers that must not trigger
    /// first-touch initialization: a crash handler (initialization takes locks and reads
    /// UserDefaults, neither async-signal-safe) and any pre-unlock caller that would
    /// otherwise latch `APP_STARTUP` flags from unreadable storage.
    ///
    /// Returns empty when the manager has not been built yet. Reading keys from an
    /// already-built manager still takes the KMP latch's lock.
    @objc public static func enabledFeatureKeysIfInitialized() -> [String] {
        guard let existing = lock.withLock({ _shared }) else {
            return []
        }
        return existing.enabledFeatureKeys()
    }

    /// Drops the latch and cached state so the next access re-reads storage. Required on
    /// an app-id change: `APP_STARTUP` flags never unlatch within a process, so without
    /// this the previous app's flags would govern the new one.
    @objc public static func reset() {
        lock.withLock {
            _shared = nil
            generation += 1
        }
    }

    /// Drops the latch *and* discards the persisted keys. Flags are scoped to an app id
    /// but stored unscoped, so on an app-id change the cache has to go too — otherwise
    /// the new app runs on the old app's flags until its first successful fetch, and
    /// never for `APP_STARTUP` flags.
    @objc public static func resetAndClearCachedFlags() {
        OSFeatureFlagsStore.shared.clear()
        reset()
    }

    private let impl: OSFeatureManagerImpl

    init(store: OSFeatureFlagsStore = .shared) {
        impl = OSFeatureManagerImpl(store: store)
        super.init()
    }

    /// Whether the catalog flag with this Turbine key is enabled after latching.
    @objc(isEnabledForKey:)
    public func isEnabled(featureKey: String) -> Bool {
        impl.isEnabled(featureKey: featureKey)
    }

    /// Canonical keys enabled for this process after latching, in catalog order.
    @objc public func enabledFeatureKeys() -> [String] {
        impl.enabledFeatureKeys()
    }

    func remoteFeatureFlagMetadata() -> [String: String]? {
        impl.remoteFeatureFlagMetadata()
    }

    /// Local-only test hook for forcing features ON without backend config.
    static var localFeatureOverrides: [String] = []

    /// Test-only hook, fired after construction but before publication, so a reset can be
    /// landed inside that window deterministically.
    static var didConstructForTesting: (() -> Void)?
}
