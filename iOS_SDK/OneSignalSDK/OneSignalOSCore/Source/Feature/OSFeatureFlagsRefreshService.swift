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
    private let usesScenes: () -> Bool
    private let appIdProvider: () -> String?
    private let isInForegroundProvider: () -> Bool

    var refreshInterval: TimeInterval

    private let stateLock = NSLock()
    private var pollGeneration = 0
    private var pollingAppId: String?
    private var started = false
    private var notificationTokens: [NSObjectProtocol] = []

    init(
        backend: OSFeatureFlagsBackendService = OSFeatureFlagsBackendService(),
        store: OSFeatureFlagsStore = .shared,
        ioQueue: OSDispatchQueue = DispatchQueue(label: "com.onesignal.feature-flags.refresh"),
        notificationCenter: NotificationCenter = .default,
        usesScenes: @escaping () -> Bool = { OSBundleUtils.isAppUsingUIScene() },
        appIdProvider: @escaping () -> String? = {
            OneSignalIdentifiers.currentAppId ?? OneSignalIdentifiers.storedAppId
        },
        isInForegroundProvider: @escaping () -> Bool = { true },
        refreshInterval: TimeInterval = OSFeatureFlagsRefreshService.defaultRefreshInterval
    ) {
        self.backend = backend
        self.store = store
        self.ioQueue = ioQueue
        self.notificationCenter = notificationCenter
        self.usesScenes = usesScenes
        self.appIdProvider = appIdProvider
        self.isInForegroundProvider = isInForegroundProvider
        self.refreshInterval = refreshInterval
        super.init()
    }

    @objc public class func start() {
        _ = OSFeatureManager.shared
        shared.startPolling()
    }

    @objc public class func reset() {
        lock.withLock {
            _shared?.stopPolling()
            _shared = nil
        }
    }

    func startPolling() {
        ioQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.registerLifecycleObserversIfNeeded()
            if self.isInForegroundProvider() {
                self.restartForegroundPolling()
            }
        }
    }

    func onFocus() {
        ioQueue.async { [weak self] in
            self?.restartForegroundPolling()
        }
    }

    func onUnfocused() {
        ioQueue.async { [weak self] in
            self?.stateLock.withLock {
                self?.pollGeneration += 1
                self?.pollingAppId = nil
            }
        }
    }

    func notifyAppIdMayHaveChanged() {
        ioQueue.async { [weak self] in
            guard let self, self.isInForegroundProvider() else {
                return
            }
            self.restartForegroundPolling()
        }
    }

    private func stopPolling() {
        notificationTokens.forEach(notificationCenter.removeObserver)
        notificationTokens.removeAll()
        stateLock.withLock {
            pollGeneration += 1
            pollingAppId = nil
            started = false
        }
    }

    private func registerLifecycleObserversIfNeeded() {
        let alreadyStarted = stateLock.withLock { () -> Bool in
            if started {
                return true
            }
            started = true
            return false
        }
        guard !alreadyStarted else {
            return
        }

        if usesScenes() {
            observe(Notification.Name("UISceneDidActivateNotification"), onFocus: true)
            observe(Notification.Name("UISceneDidEnterBackgroundNotification"), onFocus: false)
        } else {
            observe(UIApplication.didBecomeActiveNotification, onFocus: true)
            observe(UIApplication.didEnterBackgroundNotification, onFocus: false)
        }
    }

    private func observe(_ name: Notification.Name, onFocus: Bool) {
        notificationTokens.append(
            notificationCenter.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                if onFocus {
                    self?.onFocus()
                } else {
                    self?.onUnfocused()
                }
            }
        )
    }

    private func restartForegroundPolling() {
        let appId = appIdProvider() ?? ""
        let generation: Int = stateLock.withLock {
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
        poll(appId: appId, generation: generation)
    }

    private func poll(appId: String, generation: Int) {
        guard isCurrentGeneration(generation), isInForegroundProvider() else {
            return
        }
        let current = appIdProvider() ?? ""
        guard !current.isEmpty else {
            return
        }
        backend.fetchRemoteFeatureFlags(appId: current) { [weak self] outcome in
            guard let self, self.isCurrentGeneration(generation) else {
                return
            }
            self.apply(outcome)
            self.ioQueue.asyncAfterTime(deadline: .now() + self.refreshInterval) { [weak self] in
                self?.poll(appId: current, generation: generation)
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
