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

/// Persists encoded crash logs so they can be uploaded after the app restarts.
///
/// Writes are synchronous and durable because fatal handlers may terminate the
/// process immediately after `save` returns. Directory scans and cleanup run on
/// a utility queue to keep disk I/O off the caller.
final class FileLogStore: ILogFileStore {
    /// Complete records use `.otlp`; interrupted durable writes leave
    /// `.otlp.tmp` files that are safe to reap after the minimum-age gate.
    private static let ownedFileSuffix = ".otlp"
    private static let temporaryFileSuffix = ".otlp.tmp"
    private static let queueLabel = "com.onesignal.logger.file-store"

    private let rootURL: URL
    private let fileManager: FileManager
    private let ioQueue = DispatchQueue(label: queueLabel, qos: .utility)

    init(rootPath: String, fileManager: FileManager = .default) {
        self.rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        self.fileManager = fileManager
        try? createRootDirectory()
    }

    func save(bytes: KotlinByteArray) -> Bool {
        guard bytes.size > 0 else {
            return false
        }
        do {
            try createRootDirectory()
            let timestamp = Int64(Date().timeIntervalSince1970 * 1_000)
            let id = "\(timestamp)-\(UUID().uuidString)\(Self.ownedFileSuffix)"
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
                    message: "FileLogStore listReadable failed: \(error.localizedDescription)"
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
                    message: "FileLogStore delete failed: \(error.localizedDescription)"
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
                for url in try self.fileURLs()
                    where url.lastPathComponent.hasSuffix(Self.temporaryFileSuffix) {
                    guard try self.isOldEnough(url, minAgeMillis: minAgeMillis) else {
                        continue
                    }
                    try self.fileManager.removeItem(at: url)
                    deleted += 1
                }
            } catch {
                OneSignalLog.onesignalLog(
                    .LL_WARN,
                    message: "FileLogStore cleanup failed: \(error.localizedDescription)"
                )
            }
            completionHandler(KotlinInt(int: Int32(deleted)), nil)
        }
    }

    private func readableEntries(minAgeMillis: Int64) throws -> [StoredLogFile] {
        try fileURLs()
            .filter { $0.lastPathComponent.hasSuffix(Self.ownedFileSuffix) }
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
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: temporaryURL.path
            )
            try data.withUnsafeBytes { rawBuffer in
                guard var pointer = rawBuffer.baseAddress else {
                    return
                }
                var remaining = rawBuffer.count
                while remaining > 0 {
                    let count = Darwin.write(descriptor, pointer, remaining)
                    if count < 0 && errno == EINTR {
                        continue
                    }
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

#endif
