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
import OneSignalOSCore
import OneSignalUser
import UIKit

struct OSRemoteLoggingConfiguration {
    static let featureFlagName = "SDK_CUSTOM_LOGGING"
    private static let featureFlagKey = "sdk_custom_logging"

    let isFeatureEnabled: Bool
    let logLevel: String?

    var isRemoteLoggingEnabled: Bool {
        isFeatureEnabled && logLevel != nil && logLevel != "NONE"
    }

    static var current: OSRemoteLoggingConfiguration {
        let params = OSRemoteParamController.shared().remoteParams as? [String: Any] ?? [:]
        return OSRemoteLoggingConfiguration(remoteParams: params)
    }

    init(remoteParams: [String: Any]) {
        let loggingConfig = remoteParams["logging_config"] as? [String: Any]
        let featureFlags = remoteParams["feature_flags"] as? [String: Any]
        let enabledFlagNames =
            (remoteParams["sdk_remote_feature_flags"] as? [String])
            ?? (remoteParams["sdkRemoteFeatureFlags"] as? [String])
            ?? (remoteParams["feature_flags"] as? [String])
            ?? []
        isFeatureEnabled =
            Self.boolValue(remoteParams[Self.featureFlagKey])
            ?? Self.boolValue(featureFlags?[Self.featureFlagKey])
            ?? Self.boolValue(loggingConfig?[Self.featureFlagKey])
            ?? enabledFlagNames.contains { $0.caseInsensitiveCompare(Self.featureFlagKey) == .orderedSame }
        logLevel = (loggingConfig?["log_level"] as? String)?.uppercased()
    }

    func allows(_ level: ONE_S_LOG_LEVEL) -> Bool {
        guard isRemoteLoggingEnabled, let threshold = logLevel.flatMap(Self.oneSignalLevel) else {
            return false
        }
        return level != .LL_NONE && level.rawValue <= threshold.rawValue
    }

    static func levelName(_ level: ONE_S_LOG_LEVEL) -> String {
        switch level {
        case .LL_FATAL:
            return "FATAL"
        case .LL_ERROR:
            return "ERROR"
        case .LL_WARN:
            return "WARN"
        case .LL_INFO:
            return "INFO"
        case .LL_DEBUG:
            return "DEBUG"
        case .LL_VERBOSE:
            return "VERBOSE"
        default:
            return "NONE"
        }
    }

    private static func oneSignalLevel(_ value: String) -> ONE_S_LOG_LEVEL? {
        switch value {
        case "FATAL":
            return .LL_FATAL
        case "ERROR":
            return .LL_ERROR
        case "WARN", "WARNING":
            return .LL_WARN
        case "INFO":
            return .LL_INFO
        case "DEBUG":
            return .LL_DEBUG
        case "VERBOSE", "TRACE":
            return .LL_VERBOSE
        default:
            return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.boolValue
        }
        if let value = value as? String {
            switch value.lowercased() {
            case "true", "1":
                return true
            case "false", "0":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}

@objc(OSRemoteLoggingController)
final class OSRemoteLoggingController: NSObject, OSLogListener {
    typealias RemoteLoggerFactory = (OSRemoteLoggerProviders) -> OSRemoteLoggerProtocol

    private static let shared = OSRemoteLoggingController()
    private static let installIdKey = "PREFS_OS_INSTALL_ID"
    private static let installId: String = {
        let defaults = OneSignalUserDefaults.initShared()
        if let saved = defaults.getSavedString(forKey: installIdKey, defaultValue: nil) {
            return saved
        }
        let generated = UUID().uuidString
        defaults.saveString(forKey: installIdKey, withValue: generated)
        return generated
    }()

    private let stateQueue = DispatchQueue(label: "com.onesignal.logger.remote-lifecycle")
    private let appStateLock = NSLock()
    private let notificationCenter: NotificationCenter
    private let remoteLoggerFactory: RemoteLoggerFactory
    private var configuration = OSRemoteLoggingConfiguration(remoteParams: [:])
    private var remoteLogger: OSRemoteLoggerProtocol?
    private var appState = "unknown"
    private var notificationTokens: [NSObjectProtocol] = []
    private var isListening = false

    init(
        notificationCenter: NotificationCenter = .default,
        remoteLoggerFactory: @escaping RemoteLoggerFactory = { providers in
            OSRemoteLogger(
                installIdProvider: providers.installId,
                onesignalIdProvider: providers.onesignalId,
                pushSubscriptionIdProvider: providers.pushSubscriptionId,
                appStateProvider: providers.appState,
                featureFlagsProvider: providers.featureFlags,
                remoteLogLevelProvider: providers.remoteLogLevel,
                exporterLoggingEnabledProvider: providers.exporterLoggingEnabled
            )
        }
    ) {
        self.notificationCenter = notificationCenter
        self.remoteLoggerFactory = remoteLoggerFactory
        super.init()
    }

    @objc class func configure() {
        shared.configure(with: .current)
    }

    @objc class func reset() {
        shared.shutdown()
    }

    func configure(remoteParams: [String: Any]) {
        configure(with: OSRemoteLoggingConfiguration(remoteParams: remoteParams))
    }

    func onLogEvent(_ event: OneSignalLogEvent) {
        stateQueue.async { [weak self] in
            guard let self,
                  self.configuration.allows(event.level),
                  let remoteLogger = self.remoteLogger else {
                return
            }
            remoteLogger.log(
                level: OSRemoteLoggingConfiguration.levelName(event.level),
                message: self.message(from: event)
            )
        }
    }

    func forceFlush() {
        stateQueue.async { [weak self] in
            self?.remoteLogger?.forceFlush()
        }
    }

    func shutdown() {
        stateQueue.sync {
            stopRemoteLogging()
        }
    }

    private func configure(with newConfiguration: OSRemoteLoggingConfiguration) {
        updateAppState(Self.currentApplicationState())
        stateQueue.sync {
            self.configuration = newConfiguration
            guard newConfiguration.isRemoteLoggingEnabled else {
                self.stopRemoteLogging()
                self.logStartupDiagnostic(activePath: "local")
                return
            }

            if self.remoteLogger == nil {
                self.remoteLogger = self.remoteLoggerFactory(self.makeProviders())
                OneSignalLog.debug().__add(self)
                self.isListening = true
                self.registerLifecycleObservers()
                self.logStartupDiagnostic(activePath: "kmp")
            }
        }
    }

    private func stopRemoteLogging() {
        if isListening {
            OneSignalLog.debug().__remove(self)
            isListening = false
        }
        notificationTokens.forEach(notificationCenter.removeObserver)
        notificationTokens.removeAll()
        let activeRemoteLogger = remoteLogger
        remoteLogger = nil
        activeRemoteLogger?.shutdown()
    }

    private func registerLifecycleObservers() {
        observe(UIApplication.didBecomeActiveNotification, appState: "foreground")
        observe(Notification.Name("UISceneDidActivateNotification"), appState: "foreground")
        observe(UIApplication.willResignActiveNotification, appState: "unknown")
        observe(Notification.Name("UISceneWillDeactivateNotification"), appState: "unknown")
        observe(UIApplication.didEnterBackgroundNotification, appState: "background", flush: true)
        observe(Notification.Name("UISceneDidEnterBackgroundNotification"), appState: "background", flush: true)
        notificationTokens.append(
            notificationCenter.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.shutdown()
            }
        )
    }

    private func logStartupDiagnostic(activePath: String) {
        let kmpVersion = remoteLogger?.kmpVersion ?? "unavailable"
        let crashStoragePath = remoteLogger?.crashStoragePath ?? "unavailable"
        OneSignalLog.onesignalLog(
            .LL_WARN,
            message: "OneSignal logging initialized: sdk=\(ONESIGNAL_VERSION), "
                + "kmp=\(kmpVersion), path=\(activePath), "
                + "\(OSRemoteLoggingConfiguration.featureFlagName)=\(configuration.isFeatureEnabled), "
                + "crash_dir=\(crashStoragePath)"
        )
    }

    private func makeProviders() -> OSRemoteLoggerProviders {
        OSRemoteLoggerProviders(
            installId: { Self.installId },
            onesignalId: { OneSignalUserManagerImpl.sharedInstance.onesignalId },
            pushSubscriptionId: { OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId },
            appState: { [weak self] in self?.currentAppState ?? "unknown" },
            featureFlags: {
                OSRemoteLoggingConfiguration.current.isFeatureEnabled
                    ? [OSRemoteLoggingConfiguration.featureFlagName]
                    : []
            },
            remoteLogLevel: { OSRemoteLoggingConfiguration.current.logLevel },
            exporterLoggingEnabled: { false }
        )
    }

    private var currentAppState: String {
        appStateLock.lock()
        defer { appStateLock.unlock() }
        return appState
    }

    private func updateAppState(_ value: String) {
        appStateLock.lock()
        appState = value
        appStateLock.unlock()
    }

    private func observe(
        _ name: Notification.Name,
        appState: String,
        flush: Bool = false
    ) {
        notificationTokens.append(
            notificationCenter.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.updateAppState(appState)
                if flush {
                    self?.forceFlush()
                }
            }
        )
    }

    private static func currentApplicationState() -> String {
        let state: UIApplication.State
        if Thread.isMainThread {
            state = UIApplication.shared.applicationState
        } else {
            state = DispatchQueue.main.sync { UIApplication.shared.applicationState }
        }
        switch state {
        case .active:
            return "foreground"
        case .background:
            return "background"
        default:
            return "unknown"
        }
    }

    private func message(from event: OneSignalLogEvent) -> String {
        let prefix = "\(OSRemoteLoggingConfiguration.levelName(event.level)): "
        return event.entry.hasPrefix(prefix)
            ? String(event.entry.dropFirst(prefix.count))
            : event.entry
    }
}

struct OSRemoteLoggerProviders {
    let installId: () -> String
    let onesignalId: () -> String?
    let pushSubscriptionId: () -> String?
    let appState: () -> String
    let featureFlags: () -> [String]
    let remoteLogLevel: () -> String?
    let exporterLoggingEnabled: () -> Bool
}
