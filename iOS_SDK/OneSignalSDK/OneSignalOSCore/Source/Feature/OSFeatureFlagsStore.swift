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

/// Notified when persisted remote feature flags change, matching Android's
/// `ConfigModelStore` subscribers for `sdkRemoteFeatureFlags`.
protocol OSFeatureFlagsStoreChangeHandler: AnyObject {
    func featureFlagsDidUpdate()
}

/// Persistence for Turbine feature-flag keys and metadata, the iOS analog of
/// Android `ConfigModel.sdkRemoteFeatureFlags` / `sdkRemoteFeatureFlagMetadata`.
final class OSFeatureFlagsStore {
    static let shared = OSFeatureFlagsStore()

    private let lock = NSLock()
    private let defaults: OneSignalUserDefaults
    private var handlers: [WeakHandler] = []
    private var _sdkRemoteFeatureFlags: [String]
    private var _sdkRemoteFeatureFlagMetadata: String?

    var sdkRemoteFeatureFlags: [String] {
        lock.withLock { _sdkRemoteFeatureFlags }
    }

    var sdkRemoteFeatureFlagMetadata: String? {
        lock.withLock { _sdkRemoteFeatureFlagMetadata }
    }

    init(defaults: OneSignalUserDefaults = .initShared()) {
        self.defaults = defaults
        _sdkRemoteFeatureFlags =
            defaults.getSavedObject(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS, defaultValue: []) as? [String]
            ?? []
        _sdkRemoteFeatureFlagMetadata = defaults.getSavedString(
            forKey: OSUD_SDK_REMOTE_FEATURE_FLAG_METADATA,
            defaultValue: nil
        )
    }

    func subscribe(_ handler: OSFeatureFlagsStoreChangeHandler) {
        lock.withLock {
            handlers.append(WeakHandler(handler))
        }
    }

    /// Writes keys + metadata in place. No-op when both values are unchanged so a
    /// successful empty poll does not wake `OSFeatureManager`.
    func applyRemoteFlags(_ keys: [String], metadata: String?) {
        let changed: Bool = lock.withLock {
            if keys == _sdkRemoteFeatureFlags && metadata == _sdkRemoteFeatureFlagMetadata {
                return false
            }
            _sdkRemoteFeatureFlags = keys
            _sdkRemoteFeatureFlagMetadata = metadata
            defaults.saveObject(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS, withValue: keys)
            defaults.saveString(forKey: OSUD_SDK_REMOTE_FEATURE_FLAG_METADATA, withValue: metadata)
            handlers.removeAll { $0.value == nil }
            return true
        }
        guard changed else {
            return
        }
        let snapshot: [OSFeatureFlagsStoreChangeHandler] = lock.withLock {
            handlers.compactMap(\.value)
        }
        snapshot.forEach { $0.featureFlagsDidUpdate() }
    }

    func clear() {
        applyRemoteFlags([], metadata: nil)
    }

    private final class WeakHandler {
        weak var value: OSFeatureFlagsStoreChangeHandler?

        init(_ value: OSFeatureFlagsStoreChangeHandler) {
            self.value = value
        }
    }
}
