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
import UIKit
@_implementationOnly import OneSignalKMP

/// Fetches remote SDK feature flags when the app is in the foreground, immediately on
/// focus and then every `refreshInterval` while the session stays in the foreground.
/// Updates `OSFeatureFlagsStore` so `OSFeatureManager` stays in sync.
///
/// Polling is keyed on the active appId: once a poll loop is running for a given
/// appId, redundant triggers are a no-op so we don't double-fire the Turbine GET
/// at startup. Genuine appId changes still cancel and restart.
@objc(OSFeatureFlagsRefreshService)
public final class OSFeatureFlagsRefreshService: NSObject {
    private static let defaultRefreshInterval: TimeInterval = 480

    private static let lock = NSLock()
    private static var _shared: OSFeatureFlagsRefreshService?

    @objc public static var shared: OSFeatureFlagsRefreshService {
        lock.withLock {
            if let existing = _shared {
                return existing
            }
            let created = OSFeatureFlagsRefreshService()
            _shared = created
            return created
        }
    }

    private let backend: OSFeatureFlagsBackendService
    private let store: OSFeatureFlagsStore
    private let ioQueue: OSDispatchQueue
    private let notificationCenter: NotificationCenter
    private let appIdProvider: () -> String?
    /// Test-only override. Production tracks foreground state from lifecycle
    /// notifications, seeded by `start(isInForeground:)`, because this framework is
    /// extension-safe and so cannot read `UIApplication.shared` to ask directly.
    private let isInForegroundOverride: (() -> Bool)?

    var refreshInterval: TimeInterval

    private let stateLock = NSLock()
    private var pollGeneration = 0
    private var pollingAppId: String?
    private var started = false
    private var notificationTokens: [NSObjectProtocol] = []
    /// Defaults to false so a background launch (silent push, background fetch, prewarm)
    /// does not start polling before a focus event says otherwise.
    private var isForeground = false
    /// Set by `stopPolling` and never cleared. Work already queued on `ioQueue` when a
    /// reset lands would otherwise re-register observers and restart the poll loop on an
    /// instance that `shared` has already dropped, leaving a second poller and a set of
    /// observers that nothing can reach to remove.
    private var invalidated = false

    init(
        backend: OSFeatureFlagsBackendService = OSFeatureFlagsBackendService(),
        store: OSFeatureFlagsStore = .shared,
        ioQueue: OSDispatchQueue = DispatchQueue(label: "com.onesignal.feature-flags.refresh"),
        notificationCenter: NotificationCenter = .default,
        appIdProvider: @escaping () -> String? = {
            OneSignalIdentifiers.currentAppId ?? OneSignalIdentifiers.storedAppId
        },
        isInForegroundProvider: (() -> Bool)? = nil,
        refreshInterval: TimeInterval = OSFeatureFlagsRefreshService.defaultRefreshInterval
    ) {
        self.backend = backend
        self.store = store
        self.ioQueue = ioQueue
        self.notificationCenter = notificationCenter
        self.appIdProvider = appIdProvider
        self.isInForegroundOverride = isInForegroundProvider
        self.refreshInterval = refreshInterval
        super.init()
    }

    /// Idempotent: safe to call again once the host learns its real foreground state.
    ///
    /// - Parameter isInForeground: the host's current foreground state. Passing `false`
    ///   registers the lifecycle observers but leaves polling idle until a focus event.
    @objc public class func start(isInForeground: Bool) {
        let service = shared
        service.setForeground(isInForeground)
        _ = OSFeatureManager.shared
        service.startPolling()
    }

    @objc public class func reset() {
        lock.withLock {
            _shared?.stopPolling()
            _shared = nil
        }
    }

    func startPolling() {
        ioQueue.async { [weak self] in
            guard let self, !self.isInvalidated() else {
                return
            }
            self.registerLifecycleObserversIfNeeded()
            if self.inForeground() {
                self.restartForegroundPolling()
            }
        }
    }

    private func isInvalidated() -> Bool {
        stateLock.withLock { invalidated }
    }

    /// Seeds the tracked state. Lifecycle notifications keep it current from here on.
    func setForeground(_ value: Bool) {
        stateLock.withLock {
            isForeground = value
        }
    }

    private func inForeground() -> Bool {
        if let isInForegroundOverride {
            return isInForegroundOverride()
        }
        return stateLock.withLock { isForeground }
    }

    func onFocus() {
        ioQueue.async { [weak self] in
            guard let self, !self.isInvalidated() else {
                return
            }
            self.stateLock.withLock {
                self.isForeground = true
            }
            self.restartForegroundPolling()
        }
    }

    func onUnfocused() {
        ioQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.stateLock.withLock {
                self.isForeground = false
                self.pollGeneration += 1
                self.pollingAppId = nil
            }
        }
    }

    func stopPolling() {
        // `reset()` reaches here on the caller's thread while `observe` may be appending
        // on ioQueue, so the token list has to move under the same lock as the rest of
        // the mutable state. Deregistration itself happens outside the lock.
        let tokens: [NSObjectProtocol] = stateLock.withLock {
            invalidated = true
            let current = notificationTokens
            notificationTokens.removeAll()
            pollGeneration += 1
            pollingAppId = nil
            started = false
            return current
        }
        tokens.forEach(notificationCenter.removeObserver)
    }

    /// Deliberately app-level rather than per-scene, in both scene and non-scene apps.
    /// UIKit posts `didEnterBackgroundNotification` only once the *last* scene backgrounds
    /// and `didBecomeActiveNotification` when the app becomes active again, so the OS
    /// already aggregates exactly the "is any part of this app foreground" question that
    /// polling turns on. Tracking scenes ourselves cannot match it: we only see
    /// activations from registration onward, so scenes already active are invisible, and
    /// activations can repeat without an intervening background event.
    private func registerLifecycleObserversIfNeeded() {
        let shouldSkip = stateLock.withLock { () -> Bool in
            if started || invalidated {
                return true
            }
            started = true
            return false
        }
        guard !shouldSkip else {
            return
        }

        observe(UIApplication.didBecomeActiveNotification) { [weak self] in
            self?.onFocus()
        }
        observe(UIApplication.didEnterBackgroundNotification) { [weak self] in
            self?.onUnfocused()
        }
    }

    private func observe(_ name: Notification.Name, handler: @escaping () -> Void) {
        let token = notificationCenter.addObserver(forName: name, object: nil, queue: nil) { _ in
            handler()
        }
        // A reset can land between registering above and recording below. Nothing else
        // holds this token by then, so it has to be torn down here or it outlives the
        // service with no way to reach it.
        let recorded = stateLock.withLock { () -> Bool in
            guard !invalidated else {
                return false
            }
            notificationTokens.append(token)
            return true
        }
        if !recorded {
            notificationCenter.removeObserver(token)
        }
    }

    private func restartForegroundPolling() {
        let appId = appIdProvider() ?? ""
        let generation: Int = stateLock.withLock {
            // Single atomic gate for starting a loop, so a reset that lands mid-startup
            // cannot be overtaken by work that already passed an earlier check.
            if invalidated {
                return -1
            }
            if appId.isEmpty {
                pollGeneration += 1
                pollingAppId = nil
                return -1
            }
            if pollingAppId == appId {
                return -1
            }
            pollGeneration += 1
            pollingAppId = appId
            return pollGeneration
        }
        guard generation >= 0 else {
            return
        }
        poll(generation: generation)
    }

    private func poll(generation: Int) {
        guard isCurrentGeneration(generation) else {
            return
        }
        // Bailing out has to release the dedupe key as well, otherwise
        // `restartForegroundPolling` keeps matching `pollingAppId` and no later focus
        // event can ever restart the loop for this app id.
        guard inForeground() else {
            releasePollingKey(for: generation)
            return
        }
        let current = appIdProvider() ?? ""
        guard !current.isEmpty else {
            releasePollingKey(for: generation)
            return
        }
        backend.fetchRemoteFeatureFlags(appId: current) { [weak self] outcome in
            guard let self, self.isCurrentGeneration(generation) else {
                return
            }
            self.apply(outcome)
            self.ioQueue.asyncAfterTime(deadline: .now() + self.refreshInterval) { [weak self] in
                self?.poll(generation: generation)
            }
        }
    }

    private func apply(_ outcome: RemoteFeatureFlagsFetchOutcome) {
        guard outcome.isSuccess, let result = outcome.result else {
            return
        }
        let keys = Self.stringArray(result.enabledKeys)
        store.applyRemoteFlags(keys, metadata: result.metadataJson)
    }

    private func isCurrentGeneration(_ generation: Int) -> Bool {
        stateLock.withLock { pollGeneration == generation }
    }

    /// Clears the dedupe key only if this generation still owns it, so a newer loop
    /// started in the meantime keeps its claim.
    private func releasePollingKey(for generation: Int) {
        stateLock.withLock {
            if pollGeneration == generation {
                pollingAppId = nil
            }
        }
    }

    private static func stringArray(_ value: Any) -> [String] {
        if let strings = value as? [String] {
            return strings
        }
        if let array = value as? NSArray {
            return array.compactMap { $0 as? String }
        }
        return []
    }
}
