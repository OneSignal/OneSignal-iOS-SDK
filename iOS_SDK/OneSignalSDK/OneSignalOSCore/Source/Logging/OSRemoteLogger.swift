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

@_implementationOnly import OneSignalKMP

final class OSRemoteLoggerLifecycle {
    /// A condition rather than a plain lock so teardown can wait on in-flight flushes.
    private let lock = NSCondition()
    private var isStarted = false
    private var isShuttingDown = false
    private var isShutdown = false
    private var activeFlushes = 0

    /// True while the transport is usable and teardown has not begun. Gates record
    /// emission, uploader start, and explicit flushes alike, so nothing new is accepted
    /// once the SDK has been told to stop. Keyed on shutdown *beginning* rather than
    /// finishing, because the final drain is asynchronous.
    var isActive: Bool {
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

    /// Rejects once shutdown has *begun*, not just once it has finished. The final
    /// drain is asynchronous, so a logger told to shut down can otherwise still be
    /// started afterwards and install a crash handler nothing will ever unregister.
    func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isStarted, !isShuttingDown, !isShutdown else {
            return false
        }
        isStarted = true
        return true
    }

    /// Claims a flush slot, so teardown can tell a flush is still crossing into KMP.
    /// Returns false once shutdown has begun, meaning the caller must not cross.
    func beginFlush() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isStarted, !isShuttingDown, !isShutdown else {
            return false
        }
        activeFlushes += 1
        return true
    }

    func endFlush() {
        lock.lock()
        activeFlushes -= 1
        if activeFlushes == 0 {
            lock.broadcast()
        }
        lock.unlock()
    }

    /// Blocks until flushes admitted before shutdown began have finished, so the
    /// teardown drain never overlaps one. `beginFlush` already refuses new flushes by
    /// this point, so the set can only shrink. Bounded, because a wedged flush must
    /// not stop teardown from completing.
    func waitForFlushesToDrain(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        lock.lock()
        defer { lock.unlock() }
        while activeFlushes > 0, lock.wait(until: deadline) {}
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
        lock.unlock()
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
    @_spi(OneSignalInternal)
    public typealias RequestSender = (
        URLRequest,
        @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> Void

    private let telemetry: ILogTelemetryRemote
    private let platformProvider: OSLoggerPlatformProvider
    private let crashHandler: ILogCrashHandler
    private let crashUploader: LogCrashUploader
    private let logger: IOSLogger
    private let lifecycle: OSRemoteLoggerLifecycle
    private let eventSink: OSSdkEventSinkAttaching
    private let lifecycleOperationLock = NSLock()
    private let uploaderOwner = UUID()

    /// Serial so overlapping teardowns cannot stack several bounded drains at once.
    private static let teardownQueue = DispatchQueue(label: "com.onesignal.logger.remote-teardown")

    /// Matches the bound KMP puts on its own shutdown drain, so a wedged flush delays
    /// teardown by no more than the drain itself already can.
    private static let flushDrainTimeout: TimeInterval = 5

    public convenience init(
        installIdProvider: @escaping () -> String,
        onesignalIdProvider: @escaping () -> String?,
        pushSubscriptionIdProvider: @escaping () -> String?,
        appStateProvider: @escaping () -> String,
        featureFlagsProvider: @escaping () -> [String],
        remoteLogLevelProvider: @escaping () -> String?,
        exporterLoggingEnabledProvider: @escaping () -> Bool
    ) {
        self.init(
            installIdProvider: installIdProvider,
            onesignalIdProvider: onesignalIdProvider,
            pushSubscriptionIdProvider: pushSubscriptionIdProvider,
            appStateProvider: appStateProvider,
            featureFlagsProvider: featureFlagsProvider,
            remoteLogLevelProvider: remoteLogLevelProvider,
            exporterLoggingEnabledProvider: exporterLoggingEnabledProvider,
            requestSenderOverride: nil
        )
    }

    @_spi(OneSignalInternal)
    public convenience init(
        installIdProvider: @escaping () -> String,
        onesignalIdProvider: @escaping () -> String?,
        pushSubscriptionIdProvider: @escaping () -> String?,
        appStateProvider: @escaping () -> String,
        featureFlagsProvider: @escaping () -> [String],
        remoteLogLevelProvider: @escaping () -> String?,
        exporterLoggingEnabledProvider: @escaping () -> Bool,
        requestSender: @escaping RequestSender
    ) {
        self.init(
            installIdProvider: installIdProvider,
            onesignalIdProvider: onesignalIdProvider,
            pushSubscriptionIdProvider: pushSubscriptionIdProvider,
            appStateProvider: appStateProvider,
            featureFlagsProvider: featureFlagsProvider,
            remoteLogLevelProvider: remoteLogLevelProvider,
            exporterLoggingEnabledProvider: exporterLoggingEnabledProvider,
            requestSenderOverride: requestSender
        )
    }

    /// Internal rather than private so tests can stand in an event sink; the public
    /// convenience initializers above are the only production entry points.
    init(
        installIdProvider: @escaping () -> String,
        onesignalIdProvider: @escaping () -> String?,
        pushSubscriptionIdProvider: @escaping () -> String?,
        appStateProvider: @escaping () -> String,
        featureFlagsProvider: @escaping () -> [String],
        remoteLogLevelProvider: @escaping () -> String?,
        exporterLoggingEnabledProvider: @escaping () -> Bool,
        requestSenderOverride: RequestSender?,
        eventSink: OSSdkEventSinkAttaching = OSSdkEventRecorder.shared
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
        // Console-only logger on purpose. Exporter diagnostics describe the POST that
        // ships log records, so routing them through OneSignalLog would feed each POST
        // back into the export queue as a new record and never settle.
        let httpSender = Self.makeHttpSender(
            requestSender: requestSenderOverride,
            logger: crashLogger,
            isDiagnosticsEnabled: exporterLoggingEnabledProvider,
            lifecycle: lifecycle
        )
        let remoteTelemetry = LoggerFactory.shared.createRemoteTelemetry(
            platformProvider: provider,
            httpSender: httpSender
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
        self.eventSink = eventSink
    }

    private static func makeHttpSender(
        requestSender: RequestSender?,
        logger: ILogger,
        isDiagnosticsEnabled: @escaping () -> Bool,
        lifecycle: OSRemoteLoggerLifecycle
    ) -> OneSignalLogHttpSender {
        let executeIfEnabled: (@escaping () -> Void) -> Bool = { work in
            lifecycle.performIfTransportActive(work)
        }
        if let requestSender {
            return OneSignalLogHttpSender(
                requestSender: requestSender,
                logger: logger,
                isDiagnosticsEnabled: isDiagnosticsEnabled,
                executeIfEnabled: executeIfEnabled
            )
        }
        return OneSignalLogHttpSender(
            logger: logger,
            isDiagnosticsEnabled: isDiagnosticsEnabled,
            executeIfEnabled: executeIfEnabled
        )
    }

    public func start() {
        lifecycleOperationLock.lock()
        guard lifecycle.start() else {
            lifecycleOperationLock.unlock()
            return
        }

        crashHandler.initialize()
        // Named events ride this telemetry, the sink log lines and crash records use, so the
        // recorder follows it: attached here, detached in `shutdown()`. Anything recorded in
        // between waits in the recorder's own queue.
        eventSink.attach(telemetry)
        lifecycleOperationLock.unlock()
        let owner = uploaderOwner
        let crashUploader = self.crashUploader
        let logger = self.logger
        let lifecycle = self.lifecycle
        OSCrashUploaderCoordinator.shared.enqueue(owner: owner) {
            guard lifecycle.isActive else {
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
        guard lifecycle.isActive else {
            return
        }
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
        // Claiming a slot rather than just testing a flag: the flush completes
        // asynchronously even when started inline, so shutdown could otherwise begin
        // after the check passed and drain the same telemetry concurrently.
        // `shutdown()` waits for the slot to be released. The completion still has to
        // run on every path — callers end a background task in it, and swallowing it
        // would leak that task.
        guard lifecycle.beginFlush() else {
            completion()
            return
        }
        let lifecycle = self.lifecycle
        telemetry.forceFlush(completionHandler: { _ in
            lifecycle.endFlush()
            completion()
        })
    }

    public func shutdown() {
        lifecycleOperationLock.lock()
        guard lifecycle.beginShutdown() else {
            lifecycleOperationLock.unlock()
            return
        }

        OSCrashUploaderCoordinator.shared.cancel(owner: uploaderOwner)
        crashHandler.unregister()
        eventSink.detach()
        lifecycleOperationLock.unlock()

        // `telemetry.shutdown()` blocks for up to five seconds draining buffered
        // records, and callers reach here from app launch and app-id changes, where
        // that would stall the UI. `beginShutdown()` has already closed the door on
        // new records, so the drain can finish on its own thread. Unregistering the
        // crash handler stays synchronous above: a later logger cannot install its
        // handler while this one is still registered.
        Self.teardownQueue.async { [self] in
            // A flush admitted just before `beginShutdown()` may still be crossing
            // into KMP; the drain below would otherwise run alongside it. Safe to
            // block here: this is a background queue, and the KMP completion that
            // releases the slot resumes on main.
            lifecycle.waitForFlushesToDrain(timeout: Self.flushDrainTimeout)
            telemetry.shutdown()
            lifecycle.finishShutdown()
        }
    }
}

@_spi(OneSignalInternal)
extension OSRemoteLogger: OSStructuredRemoteLoggerProtocol {}
