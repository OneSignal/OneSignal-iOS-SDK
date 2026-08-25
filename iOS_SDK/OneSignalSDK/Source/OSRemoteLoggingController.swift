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

@objc(OSRemoteLoggingController)
final class OSRemoteLoggingController: NSObject, OSInternalLogSink {
    typealias RemoteLoggerFactory = (OSRemoteLoggerProviders) -> OSStructuredRemoteLoggerProtocol

    private static let shared = OSRemoteLoggingController()
    private static let installIdKey = "PREFS_OS_INSTALL_ID"
    private static let cachedConfigurationKey = "PREFS_OS_REMOTE_LOGGING_CONFIGURATION"
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
    private var configuration = OSRemoteLoggingConfiguration.disabled
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

    @objc static func configure() {
        let configuration = OSRemoteLoggingConfiguration.current
        cache(configuration: configuration)
        shared.configure(with: configuration)
    }

    @objc(configureFromCacheForAppId:)
    static func configureFromCache(appId: String?) {
        guard let appId,
              let cached = OneSignalUserDefaults.initStandard().getSavedDictionary(
                forKey: cachedConfigurationKey,
                defaultValue: nil
              ),
              cached[OSRemoteLoggingConfiguration.cachedAppIdKey] as? String == appId else {
            shared.shutdown()
            return
        }
        shared.configure(with: OSRemoteLoggingConfiguration(cached: cached))
    }

    @objc static func reset() {
        shared.shutdown()
    }

    private static func cache(configuration: OSRemoteLoggingConfiguration) {
        guard let appId = OneSignalIdentifiers.currentAppId else {
            return
        }
        OneSignalUserDefaults.initStandard().saveDictionary(
            forKey: cachedConfigurationKey,
            withValue: configuration.cachePayload(appId: appId)
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
        guard let startGeneration = applyConfiguration(newConfiguration) else {
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

    /// Applies `newConfiguration` and tears down the running logger when the evaluated
    /// action calls for it. Returns the generation a replacement logger should be built
    /// for, or nil when the current state already satisfies the configuration.
    private func applyConfiguration(_ newConfiguration: OSRemoteLoggingConfiguration) -> Int? {
        var startGeneration: Int?
        stateQueue.sync {
            self.configurationGeneration += 1
            let generation = self.configurationGeneration
            let action = OSRemoteLoggingConfigEvaluator.evaluate(
                old: self.configuration,
                new: newConfiguration
            )
            self.configuration = newConfiguration

            switch action {
            case .disable:
                self.stopRemoteLogging()
            case .updateLogLevel:
                // Android rebuilds remote telemetry on a level change rather than
                // swapping a filter on the live instance: `startLogging` shuts the
                // previous one down before constructing a new one. Rebuilding matters
                // for more than parity here — the platform provider handed to KMP is
                // built alongside the logger, so keeping the old instance would go on
                // reporting the previous level into KMP, and the crash uploader would
                // never re-run after a level escalates away from NONE.
                self.stopRemoteLogging()
                startGeneration = generation
            case .enable, .noChange:
                guard newConfiguration.isEnabled else {
                    self.stopRemoteLogging()
                    break
                }
                if self.remoteLogger == nil {
                    startGeneration = generation
                }
            }
        }
        return startGeneration
    }

    private func stopRemoteLogging() {
        OneSignalLog.__removeInternalLogSink(self)
        notificationTokens.forEach(notificationCenter.removeObserver)
        notificationTokens.removeAll()
        let activeRemoteLogger = remoteLogger
        remoteLogger = nil
        activeRemoteLogger?.shutdown()
    }

}

// MARK: - App state, lifecycle observers, and thread helpers

private extension OSRemoteLoggingController {
    func registerLifecycleObservers() {
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
            // Deliberately non-forcing: this closure runs on arbitrary threads and
            // synchronously from the crash handler, and it can fire before storage is
            // readable. Touching `.shared` here would both latch APP_STARTUP flags from
            // an empty prewarm read and do lock/UserDefaults work on a crashing thread.
            featureFlags: { OSFeatureManager.enabledFeatureKeysIfInitialized() },
            remoteLogLevel: { configuration.logLevelName },
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

struct OSRemoteLoggerProviders {
    let installId: () -> String
    let onesignalId: () -> String?
    let pushSubscriptionId: () -> String?
    let appState: () -> String
    let featureFlags: () -> [String]
    let remoteLogLevel: () -> String?
    let exporterLoggingEnabled: () -> Bool
}
