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

/// Detects the test-device gesture: `requiredCycles` background/foreground cycles within
/// `windowSeconds`, then copies the push subscription ID to the general pasteboard, prefixed
/// `os:` (see `clipText`), so the person can paste it into the dashboard.
///
/// A cycle is a `didEnterBackground`/`didBecomeActive` pair whose background phase lasts at
/// least `minBackgroundDwellSeconds`. Pairing keeps `willResignActive`-only blips (Control
/// Center, Face ID) from counting; the floor matches Android, where rotation emits a
/// synthetic sub-millisecond pair. The window is the only rate rule; six cycles inside it
/// takes sustained five-second round trips.
///
/// Adding `killSwitchKey` to the app's enabled feature keys disables the gesture. Absent
/// means enabled, so a device that has never fetched flags still has it. Reads the raw
/// `OSFeatureFlagsStore` list because `OSFeatureManager` only resolves keys the KMP catalog
/// registers.
///
/// Every recognised gesture also records `OSObservabilityEvent.deviceGesture`, with its outcome
/// and the copied ID, so the gesture's usage can be measured.
@objc(OSDeviceGestureDetector)
public final class OSDeviceGestureDetector: NSObject {
    static let requiredCycles = 6
    static let windowSeconds: TimeInterval = 30

    /// Shortest background phase a human can produce; anything faster is synthetic.
    static let minBackgroundDwellSeconds: TimeInterval = 0.25

    static let killSwitchKey = "sdk_device_gesture_disabled"

    /// Caps how long the gesture clobbers whatever the person had copied.
    static let pasteboardExpirySeconds: TimeInterval = 300

    private static let lock = NSLock()
    private static var _shared: OSDeviceGestureDetector?

    static var shared: OSDeviceGestureDetector {
        lock.withLock {
            if let existing = _shared {
                return existing
            }
            let created = OSDeviceGestureDetector()
            _shared = created
            return created
        }
    }

    private let notificationCenter: NotificationCenter
    private let mainQueue: OSDispatchQueue
    /// Monotonic clock, so wall-clock jumps from NTP or manual time changes cannot stretch
    /// or shrink the window.
    private let nowProvider: () -> TimeInterval
    private let enabledFlagsProvider: () -> [String]
    private let subscriptionIdProvider: () -> String?
    private let shouldAwaitProvider: () -> Bool
    private let pasteboardWriter: (String) -> Void
    private let eventRecorder: OSObservabilityEventRecorderProtocol

    private let stateLock = NSLock()
    private var started = false
    /// Set by `tearDown` and never cleared, so work already queued for an instance that
    /// `shared` has dropped cannot write to the pasteboard or re-register observers.
    private var invalidated = false
    private var notificationTokens: [NSObjectProtocol] = []
    private var lastBackgroundedAt: TimeInterval?
    private var cycleCompletions: [TimeInterval] = []

    init(
        notificationCenter: NotificationCenter = .default,
        mainQueue: OSDispatchQueue = DispatchQueue.main,
        nowProvider: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        enabledFlagsProvider: @escaping () -> [String] = { OSFeatureFlagsStore.shared.sdkRemoteFeatureFlags },
        subscriptionIdProvider: @escaping () -> String? = { OneSignalIdentifiers.subscriptionId },
        shouldAwaitProvider: @escaping () -> Bool = {
            OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: nil)
        },
        pasteboardWriter: @escaping (String) -> Void = OSDeviceGestureDetector.writeToGeneralPasteboard,
        eventRecorder: OSObservabilityEventRecorderProtocol = OSObservabilityEventRecorder.shared
    ) {
        self.notificationCenter = notificationCenter
        self.mainQueue = mainQueue
        self.nowProvider = nowProvider
        self.enabledFlagsProvider = enabledFlagsProvider
        self.subscriptionIdProvider = subscriptionIdProvider
        self.shouldAwaitProvider = shouldAwaitProvider
        self.pasteboardWriter = pasteboardWriter
        self.eventRecorder = eventRecorder
        super.init()
    }

    /// Idempotent: registers the lifecycle observers once and keeps counting from there.
    @objc public static func start() {
        shared.registerLifecycleObserversIfNeeded()
    }

    @objc public static func reset() {
        lock.withLock {
            _shared?.tearDown()
            _shared = nil
        }
    }

    /// App-level rather than per-scene: UIKit posts `didEnterBackgroundNotification` only
    /// once the last scene backgrounds, exactly the whole-app signal a cycle counter needs.
    /// Per-scene events would over-count on multi-window iPad.
    func registerLifecycleObserversIfNeeded() {
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

        observe(UIApplication.didEnterBackgroundNotification) { [weak self] in
            self?.onUnfocused()
        }
        observe(UIApplication.didBecomeActiveNotification) { [weak self] in
            self?.onFocus()
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

    func tearDown() {
        let tokens: [NSObjectProtocol] = stateLock.withLock {
            invalidated = true
            let current = notificationTokens
            notificationTokens.removeAll()
            started = false
            lastBackgroundedAt = nil
            cycleCompletions.removeAll()
            return current
        }
        tokens.forEach(notificationCenter.removeObserver)
    }

    func onUnfocused() {
        let timestamp = nowProvider()
        stateLock.withLock {
            lastBackgroundedAt = timestamp
        }
    }

    func onFocus() {
        let timestamp = nowProvider()
        let completedGesture: Bool = stateLock.withLock {
            let backgroundedAt = lastBackgroundedAt
            lastBackgroundedAt = nil
            guard let backgroundedAt else {
                // Cold launch, or a repeated activation with no background in between.
                return false
            }
            let dwell = timestamp - backgroundedAt
            if dwell < Self.minBackgroundDwellSeconds {
                // Faster than any human app switch; Android rotation emits pairs like this.
                OneSignalLog.onesignalLog(
                    .LL_VERBOSE,
                    message: "OSDeviceGestureDetector: ignored a \(String(format: "%.3f", dwell))s background blip (rotation filter)"
                )
                return false
            }
            cycleCompletions.append(timestamp)
            cycleCompletions.removeAll { timestamp - $0 > Self.windowSeconds }
            OneSignalLog.onesignalLog(
                .LL_VERBOSE,
                message: "OSDeviceGestureDetector: cycle \(cycleCompletions.count)/\(Self.requiredCycles) within the window "
                    + "(background \(String(format: "%.2f", dwell))s)"
            )
            if cycleCompletions.count >= Self.requiredCycles {
                cycleCompletions.removeAll()
                return true
            }
            return false
        }
        if completedGesture {
            copySubscriptionIdToPasteboard()
        }
    }

    private func copySubscriptionIdToPasteboard() {
        mainQueue.async { [weak self] in
            guard let self, !self.stateLock.withLock({ self.invalidated }) else {
                return
            }
            // Not recorded either: without an app id or consent, nothing about the device may ship.
            guard !self.shouldAwaitProvider() else {
                OneSignalLog.onesignalLog(
                    .LL_DEBUG,
                    message: "OSDeviceGestureDetector: gesture detected but the SDK is not ready (appId, consent, or storage)"
                )
                return
            }
            let disabled = self.enabledFlagsProvider().contains {
                $0.caseInsensitiveCompare(Self.killSwitchKey) == .orderedSame
            }
            guard !disabled else {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSDeviceGestureDetector: gesture detected but disabled remotely")
                self.recordGesture(.disabled)
                return
            }
            guard let subscriptionId = self.subscriptionIdProvider(), !subscriptionId.isEmpty else {
                OneSignalLog.onesignalLog(
                    .LL_INFO,
                    message: "OSDeviceGestureDetector: gesture detected before the push subscription exists, nothing copied"
                )
                self.recordGesture(.noId)
                return
            }
            self.pasteboardWriter(Self.clipText(subscriptionId: subscriptionId))
            OneSignalLog.onesignalLog(.LL_INFO, message: "OSDeviceGestureDetector: push subscription ID copied to the pasteboard")
            self.recordGesture(.copied, copiedId: subscriptionId)
        }
    }

    /// Wire values of `gesture.result`, which backend queries match on.
    private enum GestureResult: String {
        case copied
        case noId = "no_id"
        case disabled
    }

    /// Recorded once the outcome is known, so `copied` means the pasteboard write went through.
    private func recordGesture(_ result: GestureResult, copiedId: String? = nil) {
        var attributes = ["gesture.result": result.rawValue]
        if let copiedId {
            attributes["gesture.push_subscription_id"] = copiedId
        }
        eventRecorder.record(event: .deviceGesture, attributes: attributes)
    }

    /// The `os:` prefix marks the value as a OneSignal ID, for the dashboard's paste target and for
    /// anyone who copied it by accident.
    static func clipText(subscriptionId: String) -> String {
        "os: \(subscriptionId)"
    }

    /// No `localOnly` option: Universal Clipboard carrying the ID to the Mac running the
    /// dashboard is the point, not a leak.
    private static func writeToGeneralPasteboard(_ value: String) {
        UIPasteboard.general.setItems(
            [["public.utf8-plain-text": value]],
            options: [.expirationDate: Date().addingTimeInterval(pasteboardExpirySeconds)]
        )
    }
}
