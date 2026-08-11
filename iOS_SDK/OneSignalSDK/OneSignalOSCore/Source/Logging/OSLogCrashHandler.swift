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
import OneSignalCore
@_implementationOnly import OneSignalKMP

private typealias OSSignalHandler = @convention(c) (Int32) -> Void
private typealias OSExceptionHandler = @convention(c) (NSException) -> Void

private func osLogUncaughtExceptionHandler(_ exception: NSException) {
    OSLogCrashHandler.active?.handle(exception: exception)
}

private func osLogSignalHandler(_ signalNumber: Int32) {
    OSLogCrashHandler.active?.handle(signalNumber: signalNumber)
}

/// Captures native fatal failures and persists them through the synchronous KMP
/// crash reporter before forwarding to the handler that was previously installed.
final class OSLogCrashHandler: ILogCrashHandler {
    fileprivate static var active: OSLogCrashHandler?

    private static let handledSignals = [
        SIGABRT,
        SIGILL,
        SIGSEGV,
        SIGFPE,
        SIGBUS,
        SIGPIPE,
        SIGTRAP
    ]

    private let reporter: ILogCrashReporter
    private var previousExceptionHandler: OSExceptionHandler?
    private var previousSignalHandlers: [Int32: OSSignalHandler] = [:]
    private var isInitialized = false
    private var didCaptureFatal = false

    init(reporter: ILogCrashReporter) {
        self.reporter = reporter
    }

    func initialize() {
        guard !isInitialized else {
            return
        }

        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler(osLogUncaughtExceptionHandler)
        for signalNumber in Self.handledSignals {
            if let previousHandler = Darwin.signal(signalNumber, osLogSignalHandler) {
                let previousAddress = Self.signalHandlerAddress(previousHandler)
                if previousAddress == Self.signalHandlerAddress(SIG_ERR) {
                    continue
                }
                if previousAddress == Self.signalHandlerAddress(SIG_IGN) {
                    Darwin.signal(signalNumber, previousHandler)
                    continue
                }
                previousSignalHandlers[signalNumber] = previousHandler
            }
        }
        Self.active = self
        isInitialized = true
    }

    func unregister() {
        guard isInitialized else {
            return
        }

        if Self.active === self {
            Self.active = nil
        }
        if Self.exceptionHandlerAddress(NSGetUncaughtExceptionHandler())
            == Self.exceptionHandlerAddress(osLogUncaughtExceptionHandler) {
            NSSetUncaughtExceptionHandler(previousExceptionHandler)
        }
        for (signalNumber, previousHandler) in previousSignalHandlers {
            guard let currentHandler = Darwin.signal(signalNumber, previousHandler) else {
                continue
            }
            if Self.signalHandlerAddress(currentHandler)
                != Self.signalHandlerAddress(osLogSignalHandler) {
                Darwin.signal(signalNumber, currentHandler)
            }
        }
        previousSignalHandlers.removeAll()
        previousExceptionHandler = nil
        isInitialized = false
        didCaptureFatal = false
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

    fileprivate func handle(signalNumber: Int32) {
        // Swift, Foundation, and Kotlin/Native are not async-signal-safe after an
        // arbitrary memory fault. Persisting here is necessarily best effort.
        // An uncaught NSException normally terminates with SIGABRT after its
        // exception handler runs. Avoid recording the same fatal failure twice.
        let stackSymbols = Thread.callStackSymbols
        if !didCaptureFatal && Self.isOneSignalAtFault(stackSymbols) {
            let signalDescription = String(cString: strsignal(signalNumber))
            capture(
                exceptionType: "Signal \(signalNumber)",
                exceptionMessage: signalDescription,
                stacktrace: stackSymbols.joined(separator: "\n")
            )
        }

        let previousHandler = previousSignalHandlers[signalNumber] ?? SIG_DFL!
        Darwin.signal(signalNumber, previousHandler)
        if Self.isCustomSignalHandler(previousHandler) {
            previousHandler(signalNumber)
        } else if Self.signalHandlerAddress(previousHandler) != Self.signalHandlerAddress(SIG_IGN) {
            Darwin.raise(signalNumber)
        }
    }

    private func capture(
        exceptionType: String,
        exceptionMessage: String,
        stacktrace: String
    ) {
        didCaptureFatal = true
        let crash = CrashData(
            threadName: Self.currentThreadName,
            exceptionType: exceptionType,
            exceptionMessage: exceptionMessage,
            stacktrace: stacktrace
        )
        do {
            _ = try reporter.saveCrash(crash: crash)
        } catch {
            OneSignalLog.onesignalLog(
                .LL_ERROR,
                message: "Unable to persist fatal crash: \(error.localizedDescription)"
            )
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

    private static func isCustomSignalHandler(_ handler: OSSignalHandler) -> Bool {
        let address = signalHandlerAddress(handler)
        return address != signalHandlerAddress(SIG_DFL!)
            && address != signalHandlerAddress(SIG_IGN)
            && address != signalHandlerAddress(SIG_ERR)
            && address != signalHandlerAddress(osLogSignalHandler)
    }

    private static func signalHandlerAddress(_ handler: OSSignalHandler) -> UInt {
        unsafeBitCast(handler, to: UInt.self)
    }

    private static func exceptionHandlerAddress(_ handler: OSExceptionHandler?) -> UInt {
        handler.map { unsafeBitCast($0, to: UInt.self) } ?? 0
    }

    static func isOneSignalAtFault(_ stackSymbols: [String]) -> Bool {
        stackSymbols.contains { $0.localizedCaseInsensitiveContains("OneSignal") }
    }
}

#endif
