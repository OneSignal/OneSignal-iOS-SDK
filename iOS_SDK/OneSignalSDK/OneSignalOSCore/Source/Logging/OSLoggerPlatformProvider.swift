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
import UIKit

/// Supplies iOS SDK state and platform metadata to the shared logger.
///
/// Mutable SDK state is injected by the composition layer because
/// `OneSignalUser` depends on `OneSignalOSCore`; importing it here would create
/// a circular module dependency. Providers must be safe to invoke from arbitrary
/// threads, including synchronously from a crash handler. Construct this adapter
/// on the main thread because its static device metadata comes from `UIDevice`.
final class OSLoggerPlatformProvider: ILoggerPlatformProvider {
    typealias IdentifierProvider = () -> String?
    typealias InstallIdProvider = () -> String
    typealias AppStateProvider = () -> String
    typealias FeatureFlagsProvider = () -> [String]
    typealias LogLevelProvider = () -> String?
    typealias BoolProvider = () -> Bool

    private enum Constants {
        static let sdkBase = "ios"
        static let deviceManufacturer = "Apple"
        static let unknown = "unknown"
        static let osBuildName = "kern.osversion"
        static let disabledLogLevel = "NONE"
        static let crashDirectoryComponents = ["onesignal", "logger", "crashes"]

        /// Prevents reading a report while a terminating process may still be
        /// completing its durable write.
        static let minimumFileAgeMillis: Int64 = 5_000
    }

    private static let processStartedAtUptime =
        processStartUptime() ?? ProcessInfo.processInfo.systemUptime

    private let installIdProvider: InstallIdProvider
    private let onesignalIdProvider: IdentifierProvider
    private let pushSubscriptionIdProvider: IdentifierProvider
    private let appStateProvider: AppStateProvider
    private let featureFlagsProvider: FeatureFlagsProvider
    private let remoteLogLevelProvider: LogLevelProvider
    private let exporterLoggingEnabledProvider: BoolProvider

    init(
        installIdProvider: @escaping InstallIdProvider,
        onesignalIdProvider: @escaping IdentifierProvider,
        pushSubscriptionIdProvider: @escaping IdentifierProvider,
        appStateProvider: @escaping AppStateProvider,
        featureFlagsProvider: @escaping FeatureFlagsProvider,
        remoteLogLevelProvider: @escaping LogLevelProvider,
        exporterLoggingEnabledProvider: @escaping BoolProvider
    ) {
        self.installIdProvider = installIdProvider
        self.onesignalIdProvider = onesignalIdProvider
        self.pushSubscriptionIdProvider = pushSubscriptionIdProvider
        self.appStateProvider = appStateProvider
        self.featureFlagsProvider = featureFlagsProvider
        self.remoteLogLevelProvider = remoteLogLevelProvider
        self.exporterLoggingEnabledProvider = exporterLoggingEnabledProvider
    }

    /// The completion must run inline because crash reporting blocks the
    /// crashing thread until this value is returned.
    func getInstallId(completionHandler: @escaping (String?, Error?) -> Void) {
        completionHandler(installIdProvider(), nil)
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
    var enabledFeatureFlags: [String] {
        featureFlagsProvider()
    }

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
        Self.processUptimeMillis(
            systemUptime: ProcessInfo.processInfo.systemUptime,
            processStartUptime: Self.processStartedAtUptime
        )
    }

    var currentThreadName: String {
        if let name = Thread.current.name, !name.isEmpty {
            return name
        }
        if Thread.isMainThread {
            return "main"
        }
        var name = [CChar](repeating: 0, count: 64)
        guard pthread_getname_np(pthread_self(), &name, name.count) == 0 else {
            return Constants.unknown
        }
        let threadName = String(cString: name)
        return threadName.isEmpty ? Constants.unknown : threadName
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
        remoteLogLevelProvider()?.uppercased()
    }

    var isExporterLoggingEnabled: Bool {
        exporterLoggingEnabledProvider()
    }

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

    static func processUptimeMillis(
        systemUptime: TimeInterval,
        processStartUptime: TimeInterval
    ) -> Int64 {
        Int64(max(0, systemUptime - processStartUptime) * 1_000)
    }

    private static func processStartUptime() -> TimeInterval? {
        var processInfo = kinfo_proc()
        var processInfoSize = MemoryLayout<kinfo_proc>.stride
        var processName = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(
            &processName,
            u_int(processName.count),
            &processInfo,
            &processInfoSize,
            nil,
            0
        ) == 0 else {
            return nil
        }

        var bootTime = timeval()
        var bootTimeSize = MemoryLayout<timeval>.stride
        var bootName = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(
            &bootName,
            u_int(bootName.count),
            &bootTime,
            &bootTimeSize,
            nil,
            0
        ) == 0 else {
            return nil
        }

        let processStart = timeInterval(processInfo.kp_proc.p_starttime)
        let systemBoot = timeInterval(bootTime)
        return max(0, processStart - systemBoot)
    }

    private static func timeInterval(_ value: timeval) -> TimeInterval {
        TimeInterval(value.tv_sec) + TimeInterval(value.tv_usec) / 1_000_000
    }

}

#endif
