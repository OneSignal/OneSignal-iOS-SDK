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

/// Persists encoded crash logs so they can be uploaded after the app restarts.
///
/// Writes are synchronous and durable because fatal handlers may terminate the
/// process immediately after `save` returns. Directory scans and cleanup run on
/// a utility queue to keep disk I/O off the caller.
///
/// This is a bounded cache, not a queue. Retention decisions — which records have aged out,
/// which exceed the accumulation caps — come from `CrashRetention` in the shared module, so
/// iOS and Android reclaim identically; this type contributes only the file I/O. Without
/// those bounds a record that never uploads successfully is re-read and re-sent on every
/// launch for the life of the install.
final class FileLogStore: ILogFileStore {
    /// Complete records use the shared policy's suffix; interrupted durable writes leave
    /// `.tmp` files alongside them that are safe to reap after the minimum-age gate.
    ///
    /// Taken from the policy rather than restated, so what this store writes cannot drift out
    /// of what `isOwned` accepts — a mismatch would hide brand-new records from every reader.
    private static let ownedFileSuffix = CrashRetention.shared.defaultPolicy.ownedSuffix
    private static let temporaryFileSuffix = ownedFileSuffix + ".tmp"
    private static let queueLabel = "com.onesignal.logger.file-store"

    /// The shared bounds, named once. Kotlin default arguments do not cross the Objective-C
    /// boundary, so every selector call must pass this explicitly — binding it here keeps the
    /// four numbers from being restated, and possibly transposed, at each call site.
    private static let retentionPolicy = CrashRetention.shared.defaultPolicy

    /// Reads the attributes a `CrashDirEntry` is built from. Injectable because the failure that
    /// matters here — attributes unreadable while the directory still lists — cannot be staged on
    /// a real filesystem: revoking directory access fails the listing itself instead.
    typealias AttributeLookup = (URL) -> URLResourceValues?

    static let defaultAttributeLookup: AttributeLookup = { url in
        try? url.resourceValues(forKeys: [
            .contentModificationDateKey,
            .fileSizeKey,
            .isRegularFileKey
        ])
    }

    private let rootURL: URL
    private let fileManager: FileManager
    private let attributeLookup: AttributeLookup
    /// Crash-path diagnostics. `OneSignalLog` fans out to app listeners and the remote sink.
    private let crashWarn: (String) -> Void
    private let ioQueue = DispatchQueue(label: queueLabel, qos: .utility)
    private let inFlightLock = NSLock()
    private var inFlightNames = Set<String>()

    init(
        rootPath: String,
        fileManager: FileManager = .default,
        crashWarn: ((String) -> Void)? = nil,
        attributeLookup: @escaping AttributeLookup = FileLogStore.defaultAttributeLookup
    ) {
        self.rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        self.fileManager = fileManager
        let crashLogger = OSCrashLogger()
        self.crashWarn = crashWarn ?? { crashLogger.warn(message: $0) }
        self.attributeLookup = attributeLookup
        try? createRootDirectory()
    }

    func save(bytes: KotlinByteArray) -> Bool {
        guard bytes.size > 0 else {
            return false
        }
        // Refuse rather than store-then-reclaim. A record this large would either claim the
        // whole shared budget or be deleted before it could be uploaded, so losing it loudly
        // here beats losing it silently on a later launch.
        guard Int64(bytes.size) <= Self.retentionPolicy.maxRecordBytes else {
            crashWarn(
                "FileLogStore refusing record of \(bytes.size) bytes, over the "
                    + "\(Self.retentionPolicy.maxRecordBytes)-byte limit"
            )
            return false
        }
        do {
            try createRootDirectory()
            let timestamp = Int64(Date().timeIntervalSince1970 * 1_000)
            let id = "\(timestamp)-\(UUID().uuidString)\(Self.ownedFileSuffix)"
            let targetURL = rootURL.appendingPathComponent(id)
            let tmpName = targetURL.appendingPathExtension("tmp").lastPathComponent
            try withInFlightNames([id, tmpName]) {
                try writeDurably(bytes.data, to: targetURL)
                enforceAccumulationCaps(keepName: id)
            }
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
                // Also the only scan that runs when remote logging is disabled, so it is the
                // sole chance to bound a directory `listReadable` never touches.
                _ = self.reclaim(entries: try self.directoryEntries())

                // Deliberately narrower than the shared `selectUnrecognized`, which reaps any
                // non-owned file. iOS never ran the OpenTelemetry pipeline, so there is no
                // legacy format to clean up here — only this store's own interrupted writes.
                // Anything else in the directory belongs to someone we should not assume about.
                let now = Self.nowMillis()
                let inFlight = self.snapshotInFlightNames()
                for entry in try self.directoryEntries()
                    where entry.name.hasSuffix(Self.temporaryFileSuffix)
                    // Unknown mtime is stored as 0, which would otherwise look older than any
                    // age gate — including an in-flight write whose attributes cannot be read.
                    && entry.lastModifiedMs > 0
                    && !inFlight.contains(entry.name)
                    && now - entry.lastModifiedMs >= max(0, minAgeMillis) {
                    // Per-entry, so one undeletable leftover cannot strand the rest of the
                    // sweep — a file locked before first unlock would otherwise wedge it.
                    if self.remove(name: entry.name) {
                        deleted += 1
                    }
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
        let entries = try directoryEntries()
        // Reclaim before reading so payloads are only materialized for records that survive
        // both bounds — an over-cap backlog is never fully loaded into memory.
        let reclaimed = reclaim(entries: entries)
        let now = Self.nowMillis()

        return entries
            .filter { CrashRetention.shared.isOwned(name: $0.name, policy: Self.retentionPolicy) }
            .filter { !reclaimed.contains($0.name) }
            .filter { now - $0.lastModifiedMs >= max(0, minAgeMillis) }
            .compactMap { entry in
                let url = rootURL.appendingPathComponent(entry.name)
                guard let data = try? Data(contentsOf: url) else {
                    return nil
                }
                return StoredLogFile(id: entry.name, bytes: data.kotlinByteArray)
            }
    }

    /// Applies the shared retention policy and deletes what it selects.
    ///
    /// - Returns: names that must be withheld from readers, including any whose unlink failed —
    ///   a record past the ceiling must not be uploaded even if it could not be removed.
    private func reclaim(entries: [CrashDirEntry]) -> Set<String> {
        let now = Self.nowMillis()
        var withheld = Set<String>()

        let inFlight = snapshotInFlightNames()
        let expired = CrashRetention.shared.selectExpiredOwned(
            entries: entries,
            nowMs: now,
            policy: Self.retentionPolicy
        )
        for entry in expired where !inFlight.contains(entry.name) {
            withheld.insert(entry.name)
            remove(name: entry.name)
        }

        // Only the survivors of the expiry pass, per the ILogFileStore contract: an expired
        // record still in the listing consumes a count slot and budget, so the overflow pass
        // would evict live records to make room for ones already being deleted.
        let survivors = entries.filter { !withheld.contains($0.name) }
        let overflow = CrashRetention.shared.selectOverflowOwned(
            entries: survivors,
            nowMs: now,
            keepName: inFlight.first { CrashRetention.shared.isOwned(name: $0, policy: Self.retentionPolicy) },
            policy: Self.retentionPolicy
        )
        for entry in overflow where !inFlight.contains(entry.name) {
            withheld.insert(entry.name)
            remove(name: entry.name)
        }

        if !withheld.isEmpty {
            OneSignalLog.onesignalLog(
                .LL_DEBUG,
                message: "FileLogStore reclaimed \(expired.count) expired and "
                    + "\(overflow.count) over-cap record(s)"
            )
        }
        return withheld
    }

    /// Trims the directory back inside the accumulation caps after a write, always keeping
    /// [keepName]. Runs synchronously on the crashing thread, so it exits on one directory
    /// listing in the steady state and only sorts when the caps are actually breached.
    ///
    /// Overflow only, deliberately: expiry is a scan the crashing thread should not pay for when
    /// nothing is over cap, and an under-cap expired record is reclaimed on the next uploader
    /// pass by `listReadable` / `deleteUnrecognizedEntries`, both of which run expiry. This is
    /// the same split Android's write path makes.
    private func enforceAccumulationCaps(keepName: String) {
        guard let entries = try? directoryEntries() else {
            return
        }
        guard !CrashRetention.shared.isWithinCaps(
            entries: entries,
            policy: Self.retentionPolicy
        ) else {
            return
        }
        let overflow = CrashRetention.shared.selectOverflowOwned(
            entries: entries,
            nowMs: Self.nowMillis(),
            keepName: keepName,
            policy: Self.retentionPolicy
        )
        for entry in overflow {
            remove(name: entry.name, crashSafe: true)
        }
    }

    /// - Returns: whether the file is gone. Callers reclaiming records ignore this — a failed
    ///   unlink is still withheld from readers — but the temp sweep counts only real deletions.
    ///   An already-removed file is success: crash-path eviction and the async reclaim can
    ///   target the same name.
    @discardableResult
    private func remove(name: String, crashSafe: Bool = false) -> Bool {
        do {
            try fileManager.removeItem(at: rootURL.appendingPathComponent(name))
            return true
        } catch {
            if fileLogStoreIsAlreadyRemoved(error) {
                return true
            }
            let message = "FileLogStore failed to reclaim \(name): \(error.localizedDescription)"
            if crashSafe {
                crashWarn(message)
            } else {
                OneSignalLog.onesignalLog(.LL_WARN, message: message)
            }
            return false
        }
    }

    /// Snapshots the directory as the platform-neutral entries the shared policy consumes.
    ///
    /// Unreadable attributes — data protection before first unlock, a transient I/O error —
    /// keep the entry in the snapshot rather than omitting it. Omission would put the file
    /// outside every bound at once. Missing mtime is stored as 0: owned records then read as
    /// unrecoverably stale (matching Android's `File.lastModified()`), while the temp sweep
    /// treats 0 as unknown and leaves `.otlp.tmp` alone so an in-flight write is not reaped.
    /// Entries are dropped only when `isRegularFile` is known false, not when that bit cannot
    /// be read — the latter used to discard the file before this fallback could run.
    private func directoryEntries() throws -> [CrashDirEntry] {
        guard fileManager.fileExists(atPath: rootURL.path) else {
            return []
        }
        return try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isRegularFileKey
            ],
            options: [.skipsHiddenFiles]
        ).compactMap { url in
            let values = attributeLookup(url)
            if values?.isRegularFile == false {
                return nil
            }
            let name = url.lastPathComponent
            return CrashDirEntry(
                name: name,
                lastModifiedMs: values?.contentModificationDate.map {
                    Int64($0.timeIntervalSince1970 * 1_000)
                } ?? 0,
                lengthBytes: Int64(values?.fileSize ?? 0)
            )
        }
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000)
    }

    private func withInFlightNames(_ names: [String], _ body: () throws -> Void) rethrows {
        inFlightLock.lock()
        inFlightNames.formUnion(names)
        inFlightLock.unlock()
        defer {
            inFlightLock.lock()
            inFlightNames.subtract(names)
            inFlightLock.unlock()
        }
        try body()
    }

    private func snapshotInFlightNames() -> Set<String> {
        inFlightLock.lock()
        defer { inFlightLock.unlock() }
        return inFlightNames
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

private func fileLogStoreIsAlreadyRemoved(_ error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain {
        return nsError.code == CocoaError.fileNoSuchFile.rawValue
            || nsError.code == CocoaError.fileReadNoSuchFile.rawValue
    }
    return nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOENT)
}
