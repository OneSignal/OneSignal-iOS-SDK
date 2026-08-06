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
import UIKit

/// Supplies iOS SDK state and platform metadata to the shared logger.
///
/// User identifiers are injected by the composition layer because
/// `OneSignalUser` depends on `OneSignalOSCore`; importing it here would create
/// a circular module dependency.
final class OSLoggerPlatformProvider: ILoggerPlatformProvider {
    typealias IdentifierProvider = () -> String?
    typealias AppStateProvider = () -> String

    private enum Constants {
        static let installIdKey = "PREFS_OS_INSTALL_ID"
        static let sdkBase = "ios"
        static let deviceManufacturer = "Apple"
        static let unknown = "unknown"
        static let osBuildName = "kern.osversion"
        static let loggingConfigKey = "logging_config"
        static let logLevelKey = "log_level"
        static let disabledLogLevel = "NONE"
        static let crashDirectoryComponents = ["onesignal", "logger", "crashes"]

        /// Prevents reading a report while a terminating process may still be
        /// completing its durable write.
        static let minimumFileAgeMillis: Int64 = 5_000
    }

    private static let processStartedAt = processStartDate()
    private let onesignalIdProvider: IdentifierProvider
    private let pushSubscriptionIdProvider: IdentifierProvider
    private let appStateProvider: AppStateProvider

    init(
        onesignalIdProvider: @escaping IdentifierProvider,
        pushSubscriptionIdProvider: @escaping IdentifierProvider,
        appStateProvider: @escaping AppStateProvider
    ) {
        self.onesignalIdProvider = onesignalIdProvider
        self.pushSubscriptionIdProvider = pushSubscriptionIdProvider
        self.appStateProvider = appStateProvider
    }

    private lazy var installId: String = {
        let defaults = OneSignalUserDefaults.initShared()
        if let saved = defaults.getSavedString(forKey: Constants.installIdKey, defaultValue: nil) {
            return saved
        }
        let generated = UUID().uuidString
        defaults.saveString(forKey: Constants.installIdKey, withValue: generated)
        return generated
    }()

    func getInstallId(completionHandler: @escaping (String?, Error?) -> Void) {
        completionHandler(installId, nil)
    }

    let sdkBase = Constants.sdkBase
    let sdkBaseVersion = ONESIGNAL_VERSION
    let appPackageId = Bundle.main.bundleIdentifier ?? Constants.unknown
    let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? Constants.unknown
    let deviceManufacturer = Constants.deviceManufacturer
    let deviceModel = OSDeviceUtils.getDeviceVariant() ?? Constants.unknown
    let osName = UIDevice.current.systemName
    let osVersion = UIDevice.current.systemVersion
    let osBuildId = OSLoggerPlatformProvider.systemValue(named: Constants.osBuildName)
    let sdkWrapper = OneSignalWrapper.sdkType
    let sdkWrapperVersion = OneSignalWrapper.sdkVersion
    let enabledFeatureFlags: [String] = []

    var appId: String? {
        OneSignalIdentifiers.currentAppId
    }

    var onesignalId: String? {
        onesignalIdProvider()
    }

    var pushSubscriptionId: String? {
        pushSubscriptionIdProvider()
    }

    var appState: String {
        appStateProvider()
    }

    var processUptime: Int64 {
        Int64(max(0, Date().timeIntervalSince(Self.processStartedAt) * 1_000))
    }

    var currentThreadName: String {
        if let name = Thread.current.name, !name.isEmpty {
            return name
        }
        if Thread.isMainThread {
            return "main"
        }
        var name = [CChar](repeating: 0, count: 64)
        return pthread_getname_np(pthread_self(), &name, name.count) == 0
            ? String(cString: name)
            : Constants.unknown
    }

    let crashStoragePath: String = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return Constants.crashDirectoryComponents.reduce(caches) {
            $0.appendingPathComponent($1, isDirectory: true)
        }.path
    }()

    let minFileAgeForReadMillis = Constants.minimumFileAgeMillis

    var isRemoteLoggingEnabled: Bool {
        guard let level = remoteLogLevel else {
            return false
        }
        return level != Constants.disabledLogLevel
    }

    var remoteLogLevel: String? {
        let config =
            OSRemoteParamController.shared().remoteParams[Constants.loggingConfigKey]
            as? [String: Any]
        return (config?[Constants.logLevelKey] as? String)?.uppercased()
    }

    let isExporterLoggingEnabled = false

    var appIdForHeaders: String {
        appId ?? ""
    }

    let apiBaseUrl = OS_API_SERVER_URL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    private static func systemValue(named name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return Constants.unknown
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
            return Constants.unknown
        }
        return String(cString: value)
    }

    private static func processStartDate() -> Date {
        var processInfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, u_int(name.count), &processInfo, &size, nil, 0) == 0 else {
            return Date()
        }
        let start = processInfo.kp_proc.p_starttime
        return Date(
            timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000
        )
    }
}
