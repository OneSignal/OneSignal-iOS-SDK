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

// Kotlin/Native does not produce a Mac Catalyst framework slice.
#if !targetEnvironment(macCatalyst)

import Darwin
import Foundation
@_implementationOnly import OneSignalKMP

private typealias OSExceptionHandler = @convention(c) (NSException) -> Void

private func osLogUncaughtExceptionHandler(_ exception: NSException) {
    OSLogCrashHandler.handleActive(exception)
}

final class OSCrashLogger: ILogger {
    func error(message: String) {
        NSLog("[OneSignal crash] ERROR: %@", message)
    }

    func warn(message: String) {
        NSLog("[OneSignal crash] WARN: %@", message)
    }

    func info(message: String) {
        NSLog("[OneSignal crash] INFO: %@", message)
    }

    func debug(message: String) {
        NSLog("[OneSignal crash] DEBUG: %@", message)
    }
}

/// Captures uncaught Objective-C exceptions through the synchronous KMP crash
/// reporter before forwarding to the handler that was previously installed.
///
/// POSIX signals are intentionally not intercepted because Swift, Foundation,
/// Kotlin/Native, and the durable file store are not async-signal-safe.
final class OSLogCrashHandler: ILogCrashHandler {
    private static let oneSignalModules: Set<String> = [
        "OneSignal",
        "OneSignalCore",
        "OneSignalExtension",
        "OneSignalFramework",
        "OneSignalInAppMessages",
        "OneSignalLiveActivities",
        "OneSignalLocation",
        "OneSignalNotifications",
        "OneSignalOSCore",
        "OneSignalOutcomes",
        "OneSignalUser"
    ]
    private static let exceptionRuntimeModules: Set<String> = [
        "CoreFoundation",
        "libobjc",
        "libobjc.A.dylib"
    ]
    private static let registryLock = NSLock()
    private static let handlingThreadKey = "com.onesignal.logger.handling-exception"
    private static var active: OSLogCrashHandler?
    private static var inactivePreviousHandler: OSExceptionHandler?

    private let reporter: ILogCrashReporter
    private var previousExceptionHandler: OSExceptionHandler?
    private var isInitialized = false

    init(reporter: ILogCrashReporter) {
        self.reporter = reporter
    }

    func initialize() {
        Self.registryLock.lock()
        defer { Self.registryLock.unlock() }
        guard !isInitialized else {
            return
        }
        guard Self.active == nil else {
            return
        }

        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        Self.inactivePreviousHandler = previousExceptionHandler
        Self.active = self
        NSSetUncaughtExceptionHandler(osLogUncaughtExceptionHandler)
        isInitialized = true
    }

    func unregister() {
        Self.registryLock.lock()
        defer { Self.registryLock.unlock() }
        guard isInitialized else {
            return
        }

        let isCurrentHandler = Self.exceptionHandlerAddress(NSGetUncaughtExceptionHandler())
            == Self.exceptionHandlerAddress(osLogUncaughtExceptionHandler)
        if Self.active === self, isCurrentHandler {
            NSSetUncaughtExceptionHandler(previousExceptionHandler)
        }
        if Self.active === self {
            Self.active = nil
        }
        isInitialized = false
    }

    func handle(exception: NSException) {
        handle(exception: exception, stackSymbols: exception.callStackSymbols)
    }

    func handle(exception: NSException, stackSymbols: [String]) {
        guard Self.isOneSignalAtFault(stackSymbols) else {
            previousExceptionHandler?(exception)
            return
        }
        capture(
            exceptionType: exception.name.rawValue,
            exceptionMessage: exception.reason ?? exception.description,
            stacktrace: stackSymbols.joined(separator: "\n")
        )
        previousExceptionHandler?(exception)
    }

    private func capture(
        exceptionType: String,
        exceptionMessage: String,
        stacktrace: String
    ) {
        let crash = CrashData(
            threadName: Self.currentThreadName,
            exceptionType: exceptionType,
            exceptionMessage: exceptionMessage,
            stacktrace: stacktrace
        )
        do {
            try reporter.saveCrash(crash: crash)
        } catch {
            NSLog("[OneSignal crash] Unable to persist fatal crash: %@", error.localizedDescription)
        }
    }

    private static var currentThreadName: String {
        if let name = Thread.current.name, !name.isEmpty {
            return name
        }
        if Thread.isMainThread {
            return "main"
        }
        var name = [CChar](repeating: 0, count: 64)
        guard pthread_getname_np(pthread_self(), &name, name.count) == 0 else {
            return "unknown"
        }
        let threadName = String(cString: name)
        return threadName.isEmpty ? "unknown" : threadName
    }

    private static func exceptionHandlerAddress(_ handler: OSExceptionHandler?) -> UInt {
        handler.map { unsafeBitCast($0, to: UInt.self) } ?? 0
    }

    static func handleActive(_ exception: NSException) {
        let threadDictionary = Thread.current.threadDictionary
        guard threadDictionary[handlingThreadKey] == nil else {
            return
        }
        threadDictionary[handlingThreadKey] = true
        defer { threadDictionary.removeObject(forKey: handlingThreadKey) }

        registryLock.lock()
        let handler = active
        let previousHandler = inactivePreviousHandler
        registryLock.unlock()
        if let handler {
            handler.handle(exception: exception)
        } else {
            previousHandler?(exception)
        }
    }

    static func isOneSignalAtFault(_ stackSymbols: [String]) -> Bool {
        for frame in stackSymbols {
            guard let module = moduleName(from: frame) else {
                continue
            }
            if exceptionRuntimeModules.contains(module) {
                continue
            }
            return oneSignalModules.contains(module)
        }
        return false
    }

    private static func moduleName(from frame: String) -> String? {
        let fields = frame.split(whereSeparator: { $0.isWhitespace })
        guard fields.count > 1 else {
            return nil
        }
        return String(fields[1])
    }
}

#endif
