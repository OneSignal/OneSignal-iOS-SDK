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
@_spi(OneSignalInternal) import OneSignalOSCore
@_spi(OneSignalInternal) import OneSignalUser
import UIKit

struct OSRemoteLoggingConfiguration {
    private static let loggingConfigKey = "logging_config"
    private static let logLevelKey = "log_level"

    private let threshold: ONE_S_LOG_LEVEL?

    var logLevel: String? {
        threshold.map(Self.levelName)
    }

    var isRemoteLoggingEnabled: Bool {
        threshold != nil && threshold != .LL_NONE
    }

    static var current: OSRemoteLoggingConfiguration {
        let params = OSRemoteParamController.shared().remoteParams as? [String: Any] ?? [:]
        return OSRemoteLoggingConfiguration(remoteParams: params)
    }

    init(remoteParams: [String: Any]) {
        let loggingConfig = remoteParams[Self.loggingConfigKey] as? [String: Any]
        let parsedThreshold = (loggingConfig?[Self.logLevelKey] as? String)
            .map { $0.uppercased() }
            .flatMap(Self.oneSignalLevel)

        threshold = parsedThreshold
    }

    func allows(_ level: ONE_S_LOG_LEVEL) -> Bool {
        guard isRemoteLoggingEnabled, let threshold else {
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

}

@objc(OSRemoteLoggingController)
final class OSRemoteLoggingController: NSObject, OSInternalLogSink {
    typealias RemoteLoggerFactory = (OSRemoteLoggerProviders) -> OSStructuredRemoteLoggerProtocol

    private static let shared = OSRemoteLoggingController()
    private static let installIdKey = "PREFS_OS_INSTALL_ID"
    private static let cachedConfigurationKey = "PREFS_OS_REMOTE_LOGGING_CONFIGURATION"
    private static let cachedAppIdKey = "app_id"
    private static let cachedLogLevelKey = "log_level"
    private static let backgroundTaskPrefix = "com.onesignal.logger.flush."
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
    private let usesScenes: () -> Bool
    private let beginBackgroundTask: (String) -> Void
    private let endBackgroundTask: (String) -> Void
    private var configuration = OSRemoteLoggingConfiguration(remoteParams: [:])
    private var configurationGeneration = 0
    private var remoteLogger: OSStructuredRemoteLoggerProtocol?
    private var appState = "unknown"
    private var notificationTokens: [NSObjectProtocol] = []

    init(
        notificationCenter: NotificationCenter = .default,
        usesScenes: @escaping () -> Bool = { OSBundleUtils.isAppUsingUIScene() },
        beginBackgroundTask: @escaping (String) -> Void = OSBackgroundTaskManager.beginBackgroundTask,
        endBackgroundTask: @escaping (String) -> Void = OSBackgroundTaskManager.endBackgroundTask,
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
        self.usesScenes = usesScenes
        self.beginBackgroundTask = beginBackgroundTask
        self.endBackgroundTask = endBackgroundTask
        self.remoteLoggerFactory = remoteLoggerFactory
        super.init()
    }

    @objc class func configure() {
        let configuration = OSRemoteLoggingConfiguration.current
        cache(configuration: configuration)
        shared.configure(with: configuration)
    }

    @objc(configureFromCacheForAppId:)
    class func configureFromCache(appId: String?) {
        guard let appId,
              let cached = OneSignalUserDefaults.initStandard().getSavedDictionary(
                forKey: cachedConfigurationKey,
                defaultValue: nil
              ),
              cached[cachedAppIdKey] as? String == appId else {
            shared.shutdown()
            return
        }
        let logLevel = cached[cachedLogLevelKey] as? String
        let remoteParams = logLevel.map {
            ["logging_config": ["log_level": $0]]
        } ?? [:]
        shared.configure(with: OSRemoteLoggingConfiguration(remoteParams: remoteParams))
    }

    @objc class func reset() {
        shared.shutdown()
    }

    private class func cache(configuration: OSRemoteLoggingConfiguration) {
        guard let appId = OneSignalIdentifiers.currentAppId else {
            return
        }
        var cached: [String: Any] = [cachedAppIdKey: appId]
        if let logLevel = configuration.logLevel {
            cached[cachedLogLevelKey] = logLevel
        }
        OneSignalUserDefaults.initStandard().saveDictionary(
            forKey: cachedConfigurationKey,
            withValue: cached
        )
    }

    func configure(remoteParams: [String: Any]) {
        configure(with: OSRemoteLoggingConfiguration(remoteParams: remoteParams))
    }

    func captureLog(
        with level: ONE_S_LOG_LEVEL,
        message: String,
        exceptionType: String?,
        exceptionMessage: String?,
        exceptionStacktrace: String?
    ) {
        stateQueue.async { [weak self] in
            guard let self,
                  self.configuration.allows(level),
                  let remoteLogger = self.remoteLogger else {
                return
            }
            remoteLogger.log(
                level: OSRemoteLoggingConfiguration.levelName(level),
                message: message,
                exceptionType: exceptionType,
                exceptionMessage: exceptionMessage,
                exceptionStacktrace: exceptionStacktrace
            )
        }
    }

    func forceFlush(completion: @escaping () -> Void = {}) {
        stateQueue.async { [weak self] in
            guard let remoteLogger = self?.remoteLogger else {
                completion()
                return
            }
            remoteLogger.forceFlush(completion: completion)
        }
    }

    func shutdown() {
        stateQueue.sync {
            configurationGeneration += 1
            stopRemoteLogging()
        }
    }

    private func configure(with newConfiguration: OSRemoteLoggingConfiguration) {
        updateAppState(Self.currentApplicationState())
        var startGeneration: Int?
        stateQueue.sync {
            self.configurationGeneration += 1
            let generation = self.configurationGeneration
            let previousLogLevel = self.configuration.logLevel
            self.configuration = newConfiguration
            guard newConfiguration.isRemoteLoggingEnabled else {
                self.stopRemoteLogging()
                return
            }

            if previousLogLevel != newConfiguration.logLevel {
                self.stopRemoteLogging()
            }

            if self.remoteLogger == nil {
                startGeneration = generation
            }
        }

        guard let startGeneration else {
            return
        }

        let providers = makeProviders(configuration: newConfiguration)
        let newRemoteLogger = Self.onMain {
            remoteLoggerFactory(providers)
        }
        var installed = false
        stateQueue.sync {
            guard self.configurationGeneration == startGeneration,
                  self.configuration.matches(newConfiguration),
                  self.remoteLogger == nil else {
                return
            }
            self.remoteLogger = newRemoteLogger
            installed = true
        }
        guard installed else {
            newRemoteLogger.shutdown()
            return
        }

        newRemoteLogger.start()
        logStartupDiagnostic(remoteLogger: newRemoteLogger)
        stateQueue.sync {
            guard self.remoteLogger === newRemoteLogger,
                  self.configuration.matches(newConfiguration) else {
                return
            }
            OneSignalLog.__setInternalLogSink(self)
            self.registerLifecycleObservers()
        }
    }

    private func stopRemoteLogging() {
        OneSignalLog.__removeInternalLogSink(self)
        notificationTokens.forEach(notificationCenter.removeObserver)
        notificationTokens.removeAll()
        let activeRemoteLogger = remoteLogger
        remoteLogger = nil
        activeRemoteLogger?.shutdown()
    }

    private func registerLifecycleObservers() {
        if usesScenes() {
            observe(Notification.Name("UISceneDidActivateNotification"), appState: "foreground")
            observe(Notification.Name("UISceneWillDeactivateNotification"), appState: "unknown")
            observe(Notification.Name("UISceneDidEnterBackgroundNotification"), appState: "background", flush: true)
        } else {
            observe(UIApplication.didBecomeActiveNotification, appState: "foreground")
            observe(UIApplication.willResignActiveNotification, appState: "unknown")
            observe(UIApplication.didEnterBackgroundNotification, appState: "background", flush: true)
        }
        notificationTokens.append(
            notificationCenter.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.flushForLifecycle(shutdownAfterFlush: true)
            }
        )
    }

    private func logStartupDiagnostic(remoteLogger: OSStructuredRemoteLoggerProtocol) {
        OneSignalLog.onesignalLog(
            .LL_WARN,
            message: "OneSignal logging initialized: sdk=\(ONESIGNAL_VERSION), "
                + "kmp=\(remoteLogger.kmpVersion), path=kmp, "
                + "crash_dir=\(remoteLogger.crashStoragePath)"
        )
    }

    private func makeProviders(configuration: OSRemoteLoggingConfiguration) -> OSRemoteLoggerProviders {
        OSRemoteLoggerProviders(
            installId: { Self.installId },
            onesignalId: { OneSignalUserManagerImpl.sharedInstance.internalOnesignalId },
            pushSubscriptionId: { OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId },
            appState: { [weak self] in self?.currentAppState ?? "unknown" },
            featureFlags: { OSFeatureManager.shared.enabledFeatureKeys() },
            remoteLogLevel: { configuration.logLevel },
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
                    self?.flushForLifecycle(shutdownAfterFlush: false)
                }
            }
        )
    }

    private func flushForLifecycle(shutdownAfterFlush: Bool) {
        let taskIdentifier = Self.backgroundTaskPrefix + UUID().uuidString
        let endBackgroundTask = self.endBackgroundTask
        beginBackgroundTask(taskIdentifier)
        stateQueue.async { [weak self] in
            guard let self, let remoteLogger = self.remoteLogger else {
                endBackgroundTask(taskIdentifier)
                return
            }
            remoteLogger.forceFlush { [weak self] in
                guard let self else {
                    endBackgroundTask(taskIdentifier)
                    return
                }
                self.stateQueue.async {
                    if shutdownAfterFlush {
                        self.stopRemoteLogging()
                    }
                    endBackgroundTask(taskIdentifier)
                }
            }
        }
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

    private static func onMain<T>(_ work: () -> T) -> T {
        if Thread.isMainThread {
            return work()
        }
        return DispatchQueue.main.sync(execute: work)
    }

}

private extension OSRemoteLoggingConfiguration {
    func matches(_ other: OSRemoteLoggingConfiguration) -> Bool {
        logLevel == other.logLevel
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
