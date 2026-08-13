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

#if !targetEnvironment(macCatalyst)

@_implementationOnly import OneSignalKMP

/// Owns the KMP-specific logger composition while exposing a platform-neutral
/// lifecycle API to the umbrella framework.
public final class OSRemoteLogger: OSRemoteLoggerProtocol {
    private let telemetry: ILogTelemetryRemote
    private let platformProvider: OSLoggerPlatformProvider

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
        self.platformProvider = provider
        self.telemetry = LoggerFactory.shared.createRemoteTelemetry(
            platformProvider: provider,
            httpSender: OneSignalLogHttpSender(
                logger: logger,
                isDiagnosticsEnabled: exporterLoggingEnabledProvider
            )
        )
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
        telemetry.shutdown()
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
