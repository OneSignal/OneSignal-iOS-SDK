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

/// Persisted remote-logging params from the params API, mirroring Android's
/// `RemoteLoggingConfigModel` (`logLevel` + `isEnabled`).
struct OSRemoteLoggingConfiguration: Equatable {
    static let loggingConfigKey = "logging_config"
    static let logLevelKey = "log_level"
    static let cachedAppIdKey = "app_id"
    static let cachedLogLevelKey = "log_level"
    static let cachedIsEnabledKey = "is_enabled"

    /// Minimum log level to export remotely. `nil` when the backend omitted a valid `log_level`.
    let logLevel: ONE_S_LOG_LEVEL?

    /// Set true when the server sends a valid `log_level` (including `NONE`), false otherwise.
    let isEnabled: Bool

    var logLevelName: String? {
        logLevel.map(Self.levelName)
    }

    static var current: OSRemoteLoggingConfiguration {
        let params = OSRemoteParamController.shared().remoteParams as? [String: Any] ?? [:]
        return OSRemoteLoggingConfiguration(remoteParams: params)
    }

    static let disabled = OSRemoteLoggingConfiguration(logLevel: nil, isEnabled: false)

    init(logLevel: ONE_S_LOG_LEVEL?, isEnabled: Bool) {
        self.logLevel = logLevel
        self.isEnabled = isEnabled
    }

    init(remoteParams: [String: Any]) {
        let loggingConfig = remoteParams[Self.loggingConfigKey] as? [String: Any]
        let parsed = (loggingConfig?[Self.logLevelKey] as? String)
            .map { $0.uppercased() }
            .flatMap(Self.oneSignalLevel)
        self.init(logLevel: parsed, isEnabled: parsed != nil)
    }

    init(cached: [AnyHashable: Any]) {
        let parsed = (cached[Self.cachedLogLevelKey] as? String)
            .map { $0.uppercased() }
            .flatMap(Self.oneSignalLevel)
        let isEnabled = (cached[Self.cachedIsEnabledKey] as? Bool) ?? (parsed != nil)
        // A cache written by a newer SDK can name a level this one cannot parse.
        // Android falls back to ERROR when enabling without a level; matching that
        // avoids starting a logger that is enabled yet can never export anything.
        self.init(logLevel: parsed ?? (isEnabled ? .LL_ERROR : nil), isEnabled: isEnabled)
    }

    func cachePayload(appId: String) -> [String: Any] {
        var cached: [String: Any] = [
            Self.cachedAppIdKey: appId,
            Self.cachedIsEnabledKey: isEnabled
        ]
        if let logLevelName {
            cached[Self.cachedLogLevelKey] = logLevelName
        }
        return cached
    }

    func allows(_ level: ONE_S_LOG_LEVEL) -> Bool {
        guard isEnabled, let logLevel, logLevel != .LL_NONE else {
            return false
        }
        return level != .LL_NONE && level.rawValue <= logLevel.rawValue
    }

    func matches(_ other: OSRemoteLoggingConfiguration) -> Bool {
        logLevel == other.logLevel && isEnabled == other.isEnabled
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

    static func oneSignalLevel(_ value: String) -> ONE_S_LOG_LEVEL? {
        switch value {
        case "NONE":
            return .LL_NONE
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

enum OSRemoteLoggingConfigAction: Equatable {
    case noChange
    case enable(ONE_S_LOG_LEVEL)
    case updateLogLevel(old: ONE_S_LOG_LEVEL, new: ONE_S_LOG_LEVEL)
    case disable
}

/// Pure diff of old vs new remote-logging config, mirroring Android's `OtelConfigEvaluator`.
/// Android diffs a separate `OtelConfig` snapshot because its config lives in a
/// persistence-backed `Model`; `OSRemoteLoggingConfiguration` is already a value type,
/// so it is diffed directly.
enum OSRemoteLoggingConfigEvaluator {
    static func evaluate(
        old: OSRemoteLoggingConfiguration?,
        new: OSRemoteLoggingConfiguration
    ) -> OSRemoteLoggingConfigAction {
        let wasEnabled = old?.isEnabled == true
        let isNowEnabled = new.isEnabled

        switch (wasEnabled, isNowEnabled) {
        case (false, true):
            return .enable(new.logLevel ?? .LL_ERROR)
        case (true, false):
            return .disable
        case (true, true) where old?.logLevel != new.logLevel:
            return .updateLogLevel(
                old: old?.logLevel ?? .LL_ERROR,
                new: new.logLevel ?? .LL_ERROR
            )
        default:
            return .noChange
        }
    }
}
