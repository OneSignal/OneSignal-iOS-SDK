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
@_implementationOnly import OneSignalKMP

/// Wraps shared KMP `FeatureManager`. Persistence and store subscriptions stay here.
final class OSFeatureManagerImpl: OSFeatureFlagsStoreChangeHandler {
    private let store: OSFeatureFlagsStore
    private let latch = FeatureManager()

    init(store: OSFeatureFlagsStore) {
        self.store = store
        OneSignalLog.onesignalLog(
            .LL_DEBUG,
            message: "OneSignal: FeatureManager initializing from cached config features"
        )
        refreshFrom(applyAppStartupFlags: true)
        store.subscribe(self)
    }

    func isEnabled(featureKey: String) -> Bool {
        guard let feature = Self.feature(forKey: featureKey) else {
            return false
        }
        return latch.isEnabled(feature: feature)
    }

    func enabledFeatureKeys() -> [String] {
        Array(latch.enabledFeatureKeys())
    }

    func remoteFeatureFlagMetadata() -> [String: String]? {
        guard let parsed = FeatureFlagMetadata.companion.parse(raw: store.sdkRemoteFeatureFlagMetadata) else {
            return nil
        }
        var result: [String: String] = [:]
        for id in Array(parsed.ids()) {
            result[id] = parsed.jsonObjectForId(id: id) ?? ""
        }
        return result
    }

    func featureFlagsDidUpdate() {
        OneSignalLog.onesignalLog(
            .LL_DEBUG,
            message: "OneSignal: FeatureManager.featureFlagsDidUpdate"
        )
        refreshFrom(applyAppStartupFlags: false)
    }

    private func refreshFrom(applyAppStartupFlags: Bool) {
        if !OSFeatureManager.localFeatureOverrides.isEmpty {
            OneSignalLog.onesignalLog(
                .LL_WARN,
                message: "OneSignal: Local feature override enabled for testing only: \(OSFeatureManager.localFeatureOverrides)"
            )
        }
        let deferred = latch.refresh(
            remoteKeys: store.sdkRemoteFeatureFlags,
            applyAppStartupFlags: applyAppStartupFlags,
            localOverrides: OSFeatureManager.localFeatureOverrides
        )
        for change in deferred {
            OneSignalLog.onesignalLog(
                .LL_INFO,
                message: "OneSignal: Feature \(change.key) changed remotely to \(change.desiredEnabled) "
                    + "but is NEXT_RUN, keeping current run value=\(change.latchedEnabled)"
            )
        }
    }

    private static func feature(forKey key: String) -> FeatureFlag? {
        let canonical = key.lowercased()
        return FeatureFlag.entries.first { $0.key == canonical }
    }
}
