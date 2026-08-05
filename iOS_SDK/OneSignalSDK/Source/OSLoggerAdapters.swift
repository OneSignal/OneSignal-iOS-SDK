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
import OneSignalKMP
import OneSignalUser
import UIKit

final class OSLoggerAdapter: NSObject, ILogger {
    func error(message: String) {
        OneSignalLog.onesignalLog(.LL_ERROR, message: message)
    }

    func warn(message: String) {
        OneSignalLog.onesignalLog(.LL_WARN, message: message)
    }

    func info(message: String) {
        OneSignalLog.onesignalLog(.LL_INFO, message: message)
    }

    func debug(message: String) {
        OneSignalLog.onesignalLog(.LL_DEBUG, message: message)
    }
}

final class OSLogHttpSender: NSObject, ILogHttpSender {
    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()

    typealias RequestSender = (
        URLRequest,
        @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> Void

    init(session: URLSession = OSLogHttpSender.defaultSession) {
        self.requestSender = { request, completion in
            session.dataTask(with: request, completionHandler: completion).resume()
        }
    }

    init(requestSender: @escaping RequestSender) {
        self.requestSender = requestSender
    }

    private let requestSender: RequestSender

    func send(
        request: LogHttpRequest,
        completionHandler: @escaping (LogHttpResponse?, Error?) -> Void
    ) {
        guard let url = URL(string: request.url) else {
            completionHandler(
                LogHttpResponse(success: false, statusCode: -1, message: "Invalid log request URL"),
                nil
            )
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = request.body.data
        request.headers.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        urlRequest.setValue(request.contentType, forHTTPHeaderField: "Content-Type")

        requestSender(urlRequest) { _, response, error in
            if let error = error {
                completionHandler(
                    LogHttpResponse(success: false, statusCode: -1, message: error.localizedDescription),
                    nil
                )
                return
            }

            guard let response = response as? HTTPURLResponse else {
                completionHandler(
                    LogHttpResponse(success: false, statusCode: -1, message: "Missing HTTP response"),
                    nil
                )
                return
            }

            completionHandler(
                LogHttpResponse(
                    success: (200...299).contains(response.statusCode),
                    statusCode: Int32(response.statusCode),
                    message: nil
                ),
                nil
            )
        }
    }
}

final class OSLogFileStore: NSObject, ILogFileStore {
    private static let ownedSuffix = ".otlp"

    private let rootURL: URL
    private let fileManager: FileManager
    private let ioQueue = DispatchQueue(label: "com.onesignal.logger.file-store", qos: .utility)

    init(rootPath: String, fileManager: FileManager = .default) {
        self.rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        self.fileManager = fileManager
        super.init()
        try? createRootDirectory()
    }

    func save(bytes: KotlinByteArray) -> Bool {
        do {
            try createRootDirectory()
            let id = "\(Int64(Date().timeIntervalSince1970 * 1_000))-\(UUID().uuidString)\(Self.ownedSuffix)"
            try writeDurably(bytes.data, to: rootURL.appendingPathComponent(id))
            return true
        } catch {
            return false
        }
    }

    func listReadable(
        minAgeMillis: Int64,
        completionHandler: @escaping ([StoredLogFile]?, Error?) -> Void
    ) {
        ioQueue.async {
            do {
                let entries = try self.readableEntries(minAgeMillis: minAgeMillis)
                completionHandler(entries, nil)
            } catch {
                OneSignalLog.onesignalLog(
                    .LL_WARN,
                    message: "OSLogFileStore listReadable failed: \(error.localizedDescription)"
                )
                completionHandler([], nil)
            }
        }
    }

    func delete(id: String, completionHandler: @escaping (Error?) -> Void) {
        ioQueue.async {
            guard self.isSafeEntryId(id) else {
                completionHandler(nil)
                return
            }

            do {
                let url = self.rootURL.appendingPathComponent(id)
                if self.fileManager.fileExists(atPath: url.path) {
                    try self.fileManager.removeItem(at: url)
                }
            } catch {
                OneSignalLog.onesignalLog(
                    .LL_WARN,
                    message: "OSLogFileStore delete failed: \(error.localizedDescription)"
                )
            }
            completionHandler(nil)
        }
    }

    func deleteUnrecognizedEntries(
        minAgeMillis: Int64,
        completionHandler: @escaping (KotlinInt?, Error?) -> Void
    ) {
        ioQueue.async {
            var deleted = 0
            do {
                for url in try self.fileURLs() where !url.lastPathComponent.hasSuffix(Self.ownedSuffix) {
                    guard try self.isOldEnough(url, minAgeMillis: minAgeMillis) else {
                        continue
                    }
                    try self.fileManager.removeItem(at: url)
                    deleted += 1
                }
            } catch {
                OneSignalLog.onesignalLog(
                    .LL_WARN,
                    message: "OSLogFileStore cleanup failed: \(error.localizedDescription)"
                )
            }
            completionHandler(KotlinInt(int: Int32(deleted)), nil)
        }
    }

    private func readableEntries(minAgeMillis: Int64) throws -> [StoredLogFile] {
        try fileURLs()
            .filter { $0.lastPathComponent.hasSuffix(Self.ownedSuffix) }
            .filter { try isOldEnough($0, minAgeMillis: minAgeMillis) }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else {
                    return nil
                }
                return StoredLogFile(id: url.lastPathComponent, bytes: data.kotlinByteArray)
            }
    }

    private func fileURLs() throws -> [URL] {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return []
        }
        return try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }

    private func isOldEnough(_ url: URL, minAgeMillis: Int64) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        guard let modifiedAt = values.contentModificationDate else {
            return false
        }
        return Date().timeIntervalSince(modifiedAt) * 1_000 >= Double(max(0, minAgeMillis))
    }

    private func isSafeEntryId(_ id: String) -> Bool {
        !id.isEmpty && URL(fileURLWithPath: id).lastPathComponent == id
    }

    private func createRootDirectory() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private func writeDurably(_ data: Data, to targetURL: URL) throws {
        let temporaryURL = targetURL.appendingPathExtension("tmp")
        let descriptor = open(temporaryURL.path, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        var isClosed = false
        defer {
            if !isClosed {
                close(descriptor)
            }
        }

        do {
            try data.withUnsafeBytes { rawBuffer in
                guard var pointer = rawBuffer.baseAddress else {
                    return
                }
                var remaining = rawBuffer.count
                while remaining > 0 {
                    let count = Darwin.write(descriptor, pointer, remaining)
                    guard count > 0 else {
                        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                    }
                    pointer = pointer.advanced(by: count)
                    remaining -= count
                }
            }
            guard fsync(descriptor) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            guard close(descriptor) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            isClosed = true
            try fileManager.moveItem(at: temporaryURL, to: targetURL)
            try syncDirectory()
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private func syncDirectory() throws {
        let descriptor = open(rootURL.path, O_RDONLY)
        guard descriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}

final class OSLoggerPlatformProvider: NSObject, ILoggerPlatformProvider {
    private static let installIdKey = "PREFS_OS_INSTALL_ID"
    private static let processStartedAt = processStartDate()

    private lazy var installId: String = {
        let defaults = OneSignalUserDefaults.initShared()
        if let saved = defaults.getSavedString(forKey: Self.installIdKey, defaultValue: nil) {
            return saved
        }
        let generated = UUID().uuidString
        defaults.saveString(forKey: Self.installIdKey, withValue: generated)
        return generated
    }()

    func getInstallId(completionHandler: @escaping (String?, Error?) -> Void) {
        completionHandler(installId, nil)
    }

    let sdkBase = "ios"
    let sdkBaseVersion = ONESIGNAL_VERSION
    let appPackageId = Bundle.main.bundleIdentifier ?? "unknown"
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let deviceManufacturer = "Apple"
    let deviceModel = OSDeviceUtils.getDeviceVariant() ?? "unknown"
    let osName = UIDevice.current.systemName
    let osVersion = UIDevice.current.systemVersion
    let osBuildId = OSLoggerPlatformProvider.systemValue(named: "kern.osversion")
    let sdkWrapper = OneSignalWrapper.sdkType
    let sdkWrapperVersion = OneSignalWrapper.sdkVersion
    let enabledFeatureFlags: [String] = []

    var appId: String? {
        OneSignalIdentifiers.currentAppId
    }

    var onesignalId: String? {
        OneSignalUserManagerImpl.sharedInstance.onesignalId
    }

    var pushSubscriptionId: String? {
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId
    }

    var appState: String {
        switch UIApplication.shared.applicationState {
        case .active:
            return "foreground"
        case .background:
            return "background"
        default:
            return "unknown"
        }
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
            : "unknown"
    }

    let crashStoragePath: String = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches
            .appendingPathComponent("onesignal", isDirectory: true)
            .appendingPathComponent("logger", isDirectory: true)
            .appendingPathComponent("crashes", isDirectory: true)
            .path
    }()

    let minFileAgeForReadMillis: Int64 = 5_000

    var isRemoteLoggingEnabled: Bool {
        guard let level = remoteLogLevel else {
            return false
        }
        return level != "NONE"
    }

    var remoteLogLevel: String? {
        let config = OSRemoteParamController.shared().remoteParams["logging_config"] as? [String: Any]
        return (config?["log_level"] as? String)?.uppercased()
    }

    let isExporterLoggingEnabled = false

    var appIdForHeaders: String {
        appId ?? ""
    }

    let apiBaseUrl = OS_API_SERVER_URL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    private static func systemValue(named name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return "unknown"
        }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
            return "unknown"
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

private extension KotlinByteArray {
    var data: Data {
        Data((0..<size).map { UInt8(bitPattern: get(index: $0)) })
    }
}

private extension Data {
    var kotlinByteArray: KotlinByteArray {
        KotlinByteArray(size: Int32(count)) { index in
            KotlinByte(value: Int8(bitPattern: self[Int(index.int32Value)]))
        }
    }
}
