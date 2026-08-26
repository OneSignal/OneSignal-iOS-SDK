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
        static let xcodeVersionInfoKey = "DTXcode"
        static let xcodeVersionAttribute = "xcode_version"
        static let macCatalystAttribute = "apple_platform"
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
    /// Nil on iOS: this describes the *host app's* Kotlin stack, and an iOS app is
    /// not a Kotlin host. The shared module's own provenance rides on
    /// `ossdk.kmp_version` instead.
    let kotlinVersion: String? = nil

    /// Nil on iOS. Apple exposes no runtime API for the Swift language version and
    /// there is no `DTSwiftVersion` key, so the only derivable value would come from
    /// the Xcode version — which maps to a Swift compiler 1:1 and is already emitted
    /// exactly as `xcode_version`. The one thing a distinct value could carry is the
    /// per-target language mode (`SWIFT_VERSION`, 5 vs 6), and that is not in the
    /// host's `Info.plist` at all.
    let swiftVersion: String? = nil

    let additionalVersionAttributes: [String: String] =
        OSLoggerPlatformProvider.hostBuildAttributes()
    var enabledFeatureFlags: [String] {
        featureFlagsProvider()
    }

    var appId: String? {
        OneSignalIdentifiers.currentAppId ?? OneSignalIdentifiers.storedAppId
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

    /// Xcode stamps its own version, the compiler, and the SDK it built against into
    /// the *host app's* `Info.plist`, alongside the deployment target the app
    /// declares. Reading `Bundle.main` is deliberate: this SDK ships as a prebuilt
    /// XCFramework, so a compile-time check here would describe OneSignal's build
    /// machine and be identical for every customer.
    ///
    /// These are build-time facts and answer what the host *commits to* supporting.
    /// The OS actually running is reported separately as `os.name` / `os.version` /
    /// `os.build_id`, and the two diverge: an app can serve only iOS 18 users while
    /// still declaring a much older `minimum_os_version`, which is what constrains
    /// raising our own deployment target.
    private static let buildMetadataKeys: [(infoKey: String, attribute: String)] = [
        ("DTXcodeBuild", "xcode_build"),
        ("DTCompiler", "build_compiler"),
        ("DTPlatformName", "build_platform_name"),
        ("DTPlatformVersion", "build_platform_version"),
        ("DTPlatformBuild", "build_platform_build"),
        ("DTSDKName", "build_sdk_name"),
        ("DTSDKBuild", "build_sdk_build"),
        ("MinimumOSVersion", "minimum_os_version")
    ]

    static func hostBuildAttributes(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> [String: String] {
        var attributes: [String: String] = [:]
        #if targetEnvironment(macCatalyst)
        attributes[Constants.macCatalystAttribute] = "mac_catalyst"
        #endif
        if let xcodeVersion = hostXcodeVersion(infoDictionary: infoDictionary) {
            attributes[Constants.xcodeVersionAttribute] = xcodeVersion
        }
        for (infoKey, attribute) in buildMetadataKeys {
            guard let value = infoDictionary?[infoKey] as? String, !value.isEmpty else {
                continue
            }
            attributes[attribute] = value
        }
        return attributes
    }

    static func hostXcodeVersion(
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary
    ) -> String? {
        guard let raw = infoDictionary?[Constants.xcodeVersionInfoKey] as? String else {
            return nil
        }
        return decodeXcodeVersion(raw)
    }

    /// `DTXcode` packs major/minor/patch into digits: `"2620"` is 26.2, `"0900"` is 9.0.
    static func decodeXcodeVersion(_ raw: String) -> String? {
        guard let packed = Int(raw.trimmingCharacters(in: .whitespaces)), packed > 0 else {
            return nil
        }
        let major = packed / 100
        let minor = (packed / 10) % 10
        let patch = packed % 10
        return patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }

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
