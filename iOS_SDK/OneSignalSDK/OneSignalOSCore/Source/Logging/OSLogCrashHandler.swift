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

import Darwin
import Foundation
import OneSignalCore
@_implementationOnly import OneSignalKMP

private typealias OSExceptionHandler = @convention(c) (NSException) -> Void

private func osLogUncaughtExceptionHandler(_ exception: NSException) {
    OSLogCrashHandler.handleActive(exception)
}

struct OSResolvedStackFrame: Equatable {
    let imagePath: String?
    let symbolName: String?
}

/// Prints KMP crash-reporter diagnostics with `NSLog`. Honors the console log level
/// without going through `OneSignalLog` (listeners, alert UI, remote sink).
final class OSCrashLogger: ILogger {
    private let consoleLogLevel: () -> ONE_S_LOG_LEVEL
    private let write: (String) -> Void

    init(
        consoleLogLevel: @escaping () -> ONE_S_LOG_LEVEL = { OneSignalLog.getLevel() },
        write: @escaping (String) -> Void = { NSLog("%@", $0) }
    ) {
        self.consoleLogLevel = consoleLogLevel
        self.write = write
    }

    func error(message: String) {
        emit(.LL_ERROR, label: "ERROR", message: message)
    }

    func warn(message: String) {
        emit(.LL_WARN, label: "WARN", message: message)
    }

    func info(message: String) {
        emit(.LL_INFO, label: "INFO", message: message)
    }

    func debug(message: String) {
        emit(.LL_DEBUG, label: "DEBUG", message: message)
    }

    private func emit(_ level: ONE_S_LOG_LEVEL, label: String, message: String) {
        guard level.rawValue <= consoleLogLevel().rawValue else {
            return
        }
        write("[OneSignal crash] \(label): \(message)")
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
        "OneSignalKMP",
        "OneSignalLiveActivities",
        "OneSignalLocation",
        "OneSignalNotifications",
        "OneSignalOSCore",
        "OneSignalOutcomes",
        "OneSignalUser"
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
        handle(
            exception: exception,
            stackSymbols: exception.callStackSymbols,
            resolvedFrames: Self.resolveStackFrames(exception.callStackReturnAddresses)
        )
    }

    func handle(
        exception: NSException,
        stackSymbols: [String],
        resolvedFrames: [OSResolvedStackFrame]
    ) {
        guard Self.isOneSignalAtFault(resolvedFrames) else {
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

    static func isOneSignalAtFault(_ frames: [OSResolvedStackFrame]) -> Bool {
        frames.contains { frame in
            guard let imagePath = frame.imagePath,
                  !isSystemImage(imagePath) else {
                return false
            }
            if oneSignalModules.contains(imageName(from: imagePath)) {
                return true
            }
            guard let symbolName = frame.symbolName else {
                return false
            }
            return isOneSignalSymbol(symbolName)
        }
    }

    private static func resolveStackFrames(_ addresses: [NSNumber]) -> [OSResolvedStackFrame] {
        addresses.map { address in
            guard let pointer = UnsafeRawPointer(bitPattern: address.uintValue) else {
                return OSResolvedStackFrame(imagePath: nil, symbolName: nil)
            }
            var info = Dl_info()
            guard dladdr(pointer, &info) != 0 else {
                return OSResolvedStackFrame(imagePath: nil, symbolName: nil)
            }
            return OSResolvedStackFrame(
                imagePath: info.dli_fname.map { String(cString: $0) },
                symbolName: info.dli_sname.map { String(cString: $0) }
            )
        }
    }

    private static func imageName(from path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    private static func isSystemImage(_ path: String) -> Bool {
        path.contains("/System/Library/") || path.contains("/usr/lib/")
    }

    private static func isOneSignalSymbol(_ symbol: String) -> Bool {
        let symbolWithoutLeadingUnderscores = symbol.drop(while: { $0 == "_" })
        if symbolWithoutLeadingUnderscores.hasPrefix("-[OneSignal")
            || symbolWithoutLeadingUnderscores.hasPrefix("+[OneSignal")
            || symbolWithoutLeadingUnderscores.hasPrefix("onesignal_")
            || symbolWithoutLeadingUnderscores.contains("kfun:com.onesignal.") {
            return true
        }
        guard let module = swiftModuleName(from: String(symbolWithoutLeadingUnderscores)) else {
            return false
        }
        return oneSignalModules.contains(module)
    }

    private static func swiftModuleName(from symbol: String) -> String? {
        guard symbol.hasPrefix("$s") else {
            return nil
        }
        let moduleLengthStart = symbol.index(symbol.startIndex, offsetBy: 2)
        var moduleNameStart = moduleLengthStart
        while moduleNameStart < symbol.endIndex, symbol[moduleNameStart].isNumber {
            moduleNameStart = symbol.index(after: moduleNameStart)
        }
        guard moduleNameStart > moduleLengthStart,
              let moduleLength = Int(symbol[moduleLengthStart..<moduleNameStart]),
              let moduleNameEnd = symbol.index(
                moduleNameStart,
                offsetBy: moduleLength,
                limitedBy: symbol.endIndex
              ) else {
            return nil
        }
        return String(symbol[moduleNameStart..<moduleNameEnd])
    }
}
