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

public protocol OSRemoteLoggerProtocol: AnyObject {
    var kmpVersion: String { get }
    var crashStoragePath: String { get }

    func start()
    func log(level: String, message: String)
    func forceFlush(completion: @escaping () -> Void)
    func shutdown()
}

@_spi(OneSignalInternal)
public protocol OSStructuredRemoteLoggerProtocol: OSRemoteLoggerProtocol {
    func log(
        level: String,
        message: String,
        exceptionType: String?,
        exceptionMessage: String?,
        exceptionStacktrace: String?
    )
}

public extension OSRemoteLoggerProtocol {
    func start() {}
}

#if !targetEnvironment(macCatalyst)

@_implementationOnly import OneSignalKMP

private final class OSRemoteLoggerLifecycle {
    private let lock = NSLock()
    private var isStarted = false
    private var isShuttingDown = false
    private var isShutdown = false

    var canStartUploader: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isStarted && !isShuttingDown && !isShutdown
    }

    func performIfTransportActive(_ work: () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted, !isShutdown else {
            return false
        }
        work()
        return true
    }

    func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isStarted, !isShutdown else {
            return false
        }
        isStarted = true
        return true
    }

    func beginShutdown() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isShuttingDown, !isShutdown else {
            return false
        }
        isShuttingDown = true
        return true
    }

    func finishShutdown() {
        lock.lock()
        isShutdown = true
        lock.unlock()
    }
}

final class OSCrashUploaderCoordinator {
    static let shared = OSCrashUploaderCoordinator()

    private struct PendingUpload {
        let owner: UUID
        let start: () -> Void
    }

    private let lock = NSLock()
    private var activeOwner: UUID?
    private var pendingUploads: [PendingUpload] = []

    func enqueue(owner: UUID, start: @escaping () -> Void) {
        lock.lock()
        if activeOwner == nil {
            activeOwner = owner
            lock.unlock()
            start()
            return
        }
        pendingUploads.removeAll { $0.owner == owner }
        pendingUploads.append(PendingUpload(owner: owner, start: start))
        lock.unlock()
    }

    func cancel(owner: UUID) {
        lock.lock()
        pendingUploads.removeAll { $0.owner == owner }
        guard activeOwner == owner else {
            lock.unlock()
            return
        }
        guard !pendingUploads.isEmpty else {
            activeOwner = nil
            lock.unlock()
            return
        }
        let next = pendingUploads.removeFirst()
        activeOwner = next.owner
        lock.unlock()
        next.start()
    }

    func finish(owner: UUID) {
        lock.lock()
        guard activeOwner == owner else {
            lock.unlock()
            return
        }
        guard !pendingUploads.isEmpty else {
            activeOwner = nil
            lock.unlock()
            return
        }
        let next = pendingUploads.removeFirst()
        activeOwner = next.owner
        lock.unlock()
        next.start()
    }
}

/// Owns the KMP-specific logger composition while exposing a platform-neutral
/// lifecycle API to the umbrella framework.
public final class OSRemoteLogger: OSRemoteLoggerProtocol {
    private let telemetry: ILogTelemetryRemote
    private let platformProvider: OSLoggerPlatformProvider
    private let crashHandler: ILogCrashHandler
    private let crashUploader: LogCrashUploader
    private let logger: IOSLogger
    private let lifecycle: OSRemoteLoggerLifecycle
    private let lifecycleOperationLock = NSLock()
    private let uploaderOwner = UUID()

    public init(
        installIdProvider: @escaping () -> String,
        onesignalIdProvider: @escaping () -> String?,
        pushSubscriptionIdProvider: @escaping () -> String?,
        appStateProvider: @escaping () -> String,
        featureFlagsProvider: @escaping () -> [String],
        remoteLogLevelProvider: @escaping () -> String?,
        exporterLoggingEnabledProvider: @escaping () -> Bool
    ) {
        let provider = OSLoggerPlatformProvider(
            installIdProvider: installIdProvider,
            onesignalIdProvider: onesignalIdProvider,
            pushSubscriptionIdProvider: pushSubscriptionIdProvider,
            appStateProvider: appStateProvider,
            featureFlagsProvider: featureFlagsProvider,
            remoteLogLevelProvider: remoteLogLevelProvider,
            exporterLoggingEnabledProvider: exporterLoggingEnabledProvider
        )
        let logger = IOSLogger()
        let crashLogger = OSCrashLogger()
        let lifecycle = OSRemoteLoggerLifecycle()
        let fileStore = FileLogStore(rootPath: provider.crashStoragePath)
        let remoteTelemetry = LoggerFactory.shared.createRemoteTelemetry(
            platformProvider: provider,
            httpSender: OneSignalLogHttpSender(
                logger: logger,
                isDiagnosticsEnabled: exporterLoggingEnabledProvider,
                executeIfEnabled: { work in
                    lifecycle.performIfTransportActive(work)
                }
            )
        )
        let crashTelemetry = LoggerFactory.shared.createCrashLocalTelemetry(
            platformProvider: provider,
            fileStore: fileStore
        )
        let crashReporter = LoggerFactory.shared.createCrashReporter(
            crashTelemetry: crashTelemetry,
            logger: crashLogger
        )
        let crashHandler = OSLogCrashHandler(reporter: crashReporter)
        let crashUploader = LoggerFactory.shared.createCrashUploader(
            platformProvider: provider,
            remote: remoteTelemetry,
            fileStore: fileStore,
            logger: logger
        )

        self.platformProvider = provider
        self.telemetry = remoteTelemetry
        self.crashHandler = crashHandler
        self.crashUploader = crashUploader
        self.logger = logger
        self.lifecycle = lifecycle
    }

    public func start() {
        lifecycleOperationLock.lock()
        defer { lifecycleOperationLock.unlock() }
        guard lifecycle.start() else {
            return
        }

        crashHandler.initialize()
        let owner = uploaderOwner
        let crashUploader = self.crashUploader
        let logger = self.logger
        let lifecycle = self.lifecycle
        OSCrashUploaderCoordinator.shared.enqueue(owner: owner) {
            guard lifecycle.canStartUploader else {
                OSCrashUploaderCoordinator.shared.finish(owner: owner)
                return
            }
            crashUploader.start { error in
                if let error {
                    logger.error(message: "LogCrashUploader failed: \(error.localizedDescription)")
                }
                OSCrashUploaderCoordinator.shared.finish(owner: owner)
            }
        }
    }

    public var kmpVersion: String {
        LoggerBuildInfo.shared.KMP_VERSION
    }

    public var crashStoragePath: String {
        platformProvider.crashStoragePath
    }

    public func log(level: String, message: String) {
        log(
            level: level,
            message: message,
            exceptionType: nil,
            exceptionMessage: nil,
            exceptionStacktrace: nil
        )
    }

    public func log(
        level: String,
        message: String,
        exceptionType: String?,
        exceptionMessage: String?,
        exceptionStacktrace: String?
    ) {
        LogLoggingHelper.shared.log(
            telemetry: telemetry,
            level: level,
            message: message,
            exceptionType: exceptionType,
            exceptionMessage: exceptionMessage,
            exceptionStacktrace: exceptionStacktrace,
            completionHandler: { _ in }
        )
    }

    public func forceFlush(completion: @escaping () -> Void) {
        telemetry.forceFlush(completionHandler: { _ in completion() })
    }

    public func shutdown() {
        lifecycleOperationLock.lock()
        defer { lifecycleOperationLock.unlock() }
        guard lifecycle.beginShutdown() else {
            return
        }

        OSCrashUploaderCoordinator.shared.cancel(owner: uploaderOwner)
        crashHandler.unregister()
        telemetry.shutdown()
        lifecycle.finishShutdown()
    }
}

@_spi(OneSignalInternal)
extension OSRemoteLogger: OSStructuredRemoteLoggerProtocol {}

#else

public final class OSRemoteLogger: OSRemoteLoggerProtocol {
    public init(
        installIdProvider: @escaping () -> String,
        onesignalIdProvider: @escaping () -> String?,
        pushSubscriptionIdProvider: @escaping () -> String?,
        appStateProvider: @escaping () -> String,
        featureFlagsProvider: @escaping () -> [String],
        remoteLogLevelProvider: @escaping () -> String?,
        exporterLoggingEnabledProvider: @escaping () -> Bool
    ) {}

    public let kmpVersion = "unavailable"
    public let crashStoragePath = "unavailable"

    public func start() {}
    public func log(level: String, message: String) {}
    public func log(
        level: String,
        message: String,
        exceptionType: String?,
        exceptionMessage: String?,
        exceptionStacktrace: String?
    ) {}
    public func forceFlush(completion: @escaping () -> Void) {
        completion()
    }
    public func shutdown() {}
}

@_spi(OneSignalInternal)
extension OSRemoteLogger: OSStructuredRemoteLoggerProtocol {}

#endif
