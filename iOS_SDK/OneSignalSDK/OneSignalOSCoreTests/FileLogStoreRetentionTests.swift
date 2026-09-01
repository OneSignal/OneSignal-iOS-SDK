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
import OneSignalKMP
@testable import OneSignalOSCore
import XCTest

/// A scratch crash directory and the staging every file-store suite needs.
class FileLogStoreTestCase: XCTestCase {
    fileprivate var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // A test may have made the directory read-only; restore it or the fixture outlives the run.
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: temporaryDirectory.path
        )
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}

/// The bounds that keep the crash directory a bounded cache rather than a queue. The policy
/// decisions themselves are unit-tested in the shared module.
final class FileLogStoreRetentionTests: FileLogStoreTestCase {
    // MARK: - write-time size limit

    func testRefusesPayloadOverThePerRecordLimit() {
        let store = makeStore()
        let oversized = Data(count: Int(CrashRetention.shared.defaultPolicy.maxRecordBytes) + 1)

        XCTAssertFalse(store.save(bytes: oversized.kotlinByteArray))
        XCTAssertEqual(ownedFileNames().count, 0)
    }

    func testAcceptsPayloadAtTheLimit() {
        let store = makeStore()
        let atLimit = Data(count: Int(CrashRetention.shared.defaultPolicy.maxRecordBytes))

        XCTAssertTrue(store.save(bytes: atLimit.kotlinByteArray))
        XCTAssertEqual(ownedFileNames().count, 1)
    }

    // MARK: - age ceiling

    func testListReadableDropsAndDeletesRecordsPastTheAgeCeiling() throws {
        let ceiling = CrashRetention.shared.defaultPolicy.maxReadAgeMillis
        try writeRecord(named: "expired.otlp", ageMillis: ceiling + 60_000)
        try writeRecord(named: "fresh.otlp", ageMillis: 60_000)

        let readable = try awaitListReadable(minAgeMillis: 0)

        XCTAssertEqual(readable.map { $0.id }, ["fresh.otlp"])
        XCTAssertFalse(fileExists("expired.otlp"))
        XCTAssertTrue(fileExists("fresh.otlp"))
    }

    func testRecordInsideTheAgeWindowIsRetained() throws {
        let ceiling = CrashRetention.shared.defaultPolicy.maxReadAgeMillis
        try writeRecord(named: "edge.otlp", ageMillis: ceiling - 60_000)

        let readable = try awaitListReadable(minAgeMillis: 0)

        XCTAssertEqual(readable.map { $0.id }, ["edge.otlp"])
        XCTAssertTrue(fileExists("edge.otlp"))
    }

    func testExpiredRecordThatCannotBeDeletedIsStillWithheldFromReaders() throws {
        // Withholding must not be contingent on the delete succeeding.
        let ceiling = CrashRetention.shared.defaultPolicy.maxReadAgeMillis
        try writeRecord(named: "expired-stuck.otlp", ageMillis: ceiling + 60_000)
        try writeRecord(named: "fresh.otlp", ageMillis: 60_000)
        // Denying directory writes fails the unlink without making the entries unreadable.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: temporaryDirectory.path
        )

        let readable = try awaitListReadable(minAgeMillis: 0)

        // Premise, not behavior: if the removal went through, this re-covers ordinary expiry.
        XCTAssertTrue(fileExists("expired-stuck.otlp"))
        XCTAssertEqual(readable.map { $0.id }, ["fresh.otlp"])
    }

    // MARK: - accumulation caps

    func testListReadableReclaimsAnInheritedOverCapBacklog() throws {
        // The upgrade case: a directory written by a build with no caps, trimmed on the first
        // uploader pass rather than waiting for the next crash.
        let max = Int(CrashRetention.shared.defaultPolicy.maxRecordCount)
        for index in 0..<(max + 10) {
            try writeRecord(named: "seed-\(index).otlp", ageMillis: Int64(1_000 * (index + 1)))
        }

        let readable = try awaitListReadable(minAgeMillis: 0)

        XCTAssertEqual(readable.count, max)
        XCTAssertEqual(ownedFileNames().count, max)
    }

    func testSaveEvictsOldestFirstPastTheCountCap() throws {
        let max = Int(CrashRetention.shared.defaultPolicy.maxRecordCount)
        for index in 0..<max {
            try writeRecord(named: "seed-\(index).otlp", ageMillis: Int64(1_000 * (index + 1)))
        }
        let oldest = "seed-\(max - 1).otlp"

        XCTAssertTrue(makeStore().save(bytes: Data("new".utf8).kotlinByteArray))

        XCTAssertEqual(ownedFileNames().count, max)
        XCTAssertFalse(fileExists(oldest))
        XCTAssertTrue(fileExists("seed-0.otlp"))
    }

    func testSaveEvictsOldestFirstPastTheTotalByteCap() throws {
        // Each record sits just under the per-record cap, so only the byte budget can breach.
        let policy = CrashRetention.shared.defaultPolicy
        let nearCap = Int(policy.maxRecordBytes) - 12_288
        for index in 0..<5 {
            try writeRecord(
                named: "big-\(index).otlp",
                ageMillis: Int64(10_000 * (index + 1)),
                bytes: nearCap
            )
        }

        XCTAssertTrue(makeStore().save(bytes: Data("new".utf8).kotlinByteArray))

        XCTAssertEqual(ownedFileNames().count, 5)
        XCTAssertFalse(fileExists("big-4.otlp"))
        XCTAssertTrue(fileExists("big-0.otlp"))
    }

    /// A backlog dated ahead of the clock ties with the new record on both sort keys, so without
    /// the `keepNames` reservation eviction is a coin flip. The repeat drives a false pass to nil.
    func testSaveNeverEvictsTheRecordItJustWroteWhateverOrderTheBacklogListsIn() throws {
        let max = Int(CrashRetention.shared.defaultPolicy.maxRecordCount)

        for _ in 0..<25 {
            for name in try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path) {
                try FileManager.default.removeItem(at: temporaryDirectory.appendingPathComponent(name))
            }
            for index in 0..<(max + 3) {
                let ahead = Int64(Date().timeIntervalSince1970 * 1_000) + 3_600_000 + Int64(index)
                try writeRecord(named: "\(ahead)-seed\(index).otlp", ageMillis: -60_000, bytes: 1)
            }

            XCTAssertTrue(makeStore().save(bytes: Data("new".utf8).kotlinByteArray))

            let survivors = ownedFileNames()
            XCTAssertEqual(survivors.count, max)
            // The just-written record is the only one whose name has no "seed" marker.
            XCTAssertEqual(survivors.filter { !$0.contains("seed") }.count, 1)
        }
    }

    // MARK: - shared-policy coupling

    func testWrittenRecordsUseTheSharedPolicySuffix() {
        // Drift from `ownedSuffix` would make every brand-new record invisible to readers.
        XCTAssertTrue(makeStore().save(bytes: Data("new".utf8).kotlinByteArray))

        let policy = CrashRetention.shared.defaultPolicy
        let written = (try? FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)) ?? []
        XCTAssertEqual(written.count, 1)
        let name = written.first ?? ""
        XCTAssertTrue(name.hasSuffix(policy.ownedSuffix))
        XCTAssertTrue(CrashRetention.shared.isOwned(name: name, policy: policy))
    }

    // MARK: - foreign entries

    func testDeleteUnrecognizedReapsOnlyThisStoresInterruptedWrites() throws {
        // Narrower than the shared selector on purpose: only our own `.otlp.tmp` is reclaimed.
        try writeRecord(named: "owned.otlp", ageMillis: 60_000)
        try writeRecord(named: "unowned", ageMillis: 60_000)
        try writeRecord(named: "interrupted.otlp.tmp", ageMillis: 60_000)

        let deleted = try awaitDeleteUnrecognized(minAgeMillis: 0)

        XCTAssertEqual(deleted, 1)
        XCTAssertTrue(fileExists("owned.otlp"))
        XCTAssertTrue(fileExists("unowned"))
        XCTAssertFalse(fileExists("interrupted.otlp.tmp"))
    }

    func testDeleteUnrecognizedPreservesTooYoungInterruptedWrites() throws {
        // The write may still be in flight; the age gate protects it.
        try writeRecord(named: "just-written.otlp.tmp", ageMillis: 100)

        let deleted = try awaitDeleteUnrecognized(minAgeMillis: 5_000)

        XCTAssertEqual(deleted, 0)
        XCTAssertTrue(fileExists("just-written.otlp.tmp"))
    }

    func testDeleteUnrecognizedAlsoBoundsAnOverCapBacklog() throws {
        // The only scan that runs when remote logging is disabled.
        let max = Int(CrashRetention.shared.defaultPolicy.maxRecordCount)
        for index in 0..<(max + 10) {
            try writeRecord(named: "seed-\(index).otlp", ageMillis: Int64(1_000 * (index + 1)))
        }

        _ = try awaitDeleteUnrecognized(minAgeMillis: 0)

        XCTAssertEqual(ownedFileNames().count, max)
    }

    func testDirectoryNamedLikeARecordIsNotTreatedAsOne() throws {
        try FileManager.default.createDirectory(
            at: temporaryDirectory.appendingPathComponent("folder.otlp"),
            withIntermediateDirectories: true
        )

        let readable = try awaitListReadable(minAgeMillis: 0)

        XCTAssertEqual(readable.map { $0.id }, [])
        XCTAssertTrue(fileExists("folder.otlp"))
    }

    // MARK: - crash-path logging

    func testSaveDoesNotFanOutThroughOneSignalLogWhenRefusingAnOversizedRecord() {
        let listener = FileLogStoreLogListener()
        OneSignalLog.debug().__add(listener)
        defer { OneSignalLog.debug().__remove(listener) }
        var crashWarnings: [String] = []
        let oversized = Data(count: Int(CrashRetention.shared.defaultPolicy.maxRecordBytes) + 1)

        XCTAssertFalse(
            makeStore(crashWarn: { crashWarnings.append($0) })
                .save(bytes: oversized.kotlinByteArray)
        )

        XCTAssertTrue(listener.entries.isEmpty)
        XCTAssertEqual(crashWarnings.count, 1)
        XCTAssertTrue(crashWarnings[0].contains("refusing record"))
    }

    // MARK: - concurrent reclaim

    func testAlreadyRemovedFileIsASuccessfulCleanup() throws {
        try writeRecord(named: "interrupted.otlp.tmp", ageMillis: 60_000)

        let deleted = try awaitDeleteUnrecognized(
            minAgeMillis: 0,
            fileManager: FileLogStoreMissingItemFileManager()
        )

        XCTAssertEqual(deleted, 1)
    }

    func testReclaimReachesTheCapWhileSeveralRecordsAreInFlight() throws {
        // A scan racing two concurrent writes must name both to the selector, or it spends an
        // eviction slot on a file the reclaim loop then refuses to unlink and stays over cap.
        let max = Int(CrashRetention.shared.defaultPolicy.maxRecordCount)
        // Dating the backlog ahead clamps every seed to "now", putting the in-flight records last
        // in the eviction order so the selector really reaches for them.
        for index in 0..<max {
            let ahead = Self.nowMillis() + 3_600_000 + Int64(index)
            try writeRecord(named: "\(ahead)-seed\(index).otlp", ageMillis: -3_600_000, bytes: 1)
        }

        let fileManager = FileLogStoreMoveBarrierFileManager()
        let store = FileLogStore(rootPath: temporaryDirectory.path, fileManager: fileManager)
        let parked = expectation(description: "both writes parked")
        parked.expectedFulfillmentCount = 2
        let release = DispatchSemaphore(value: 0)
        let parkedLock = NSLock()
        var parkedNames = Set<String>()
        fileManager.onMoved = { url in
            parkedLock.lock()
            parkedNames.insert(url.lastPathComponent)
            parkedLock.unlock()
            parked.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 10), .success)
        }

        let saved = expectation(description: "both writes complete")
        saved.expectedFulfillmentCount = 2
        for _ in 0..<2 {
            DispatchQueue.global().async {
                XCTAssertTrue(store.save(bytes: Data("new".utf8).kotlinByteArray))
                saved.fulfill()
            }
        }
        wait(for: [parked], timeout: 10)

        // Same store, so the scan sees the in-flight set the two parked writes are holding.
        let listed = expectation(description: "listReadable")
        store.listReadable(minAgeMillis: 0) { _, _ in listed.fulfill() }
        wait(for: [listed], timeout: 10)
        let survivors = Set(ownedFileNames())

        release.signal()
        release.signal()
        wait(for: [saved], timeout: 10)

        parkedLock.lock()
        let inFlight = parkedNames
        parkedLock.unlock()
        XCTAssertEqual(inFlight.count, 2)
        // Premise, not behavior: the reclaim loop skips in-flight names regardless.
        XCTAssertEqual(inFlight.subtracting(survivors), [])
        XCTAssertEqual(survivors.count, max)
    }

    func testSaveDoesNotEvictAnotherThreadsInFlightRecord() throws {
        // The write path unlinks whatever the selector returns with no in-flight check of its
        // own, so caps enforcement must not destroy the crash another thread is still capturing.
        let max = Int(CrashRetention.shared.defaultPolicy.maxRecordCount)
        for index in 0..<max {
            let ahead = Self.nowMillis() + 3_600_000 + Int64(index)
            try writeRecord(named: "\(ahead)-seed\(index).otlp", ageMillis: -3_600_000, bytes: 1)
        }

        let fileManager = FileLogStoreMoveBarrierFileManager()
        let store = FileLogStore(rootPath: temporaryDirectory.path, fileManager: fileManager)
        let parked = expectation(description: "first write parked")
        let release = DispatchSemaphore(value: 0)
        let parkedLock = NSLock()
        var parkedName: String?
        fileManager.onMoved = { url in
            parkedLock.lock()
            let isFirst = parkedName == nil
            if isFirst {
                parkedName = url.lastPathComponent
            }
            parkedLock.unlock()
            guard isFirst else {
                return
            }
            parked.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 10), .success)
        }

        let saved = expectation(description: "parked write completes")
        DispatchQueue.global().async {
            XCTAssertTrue(store.save(bytes: Data("first".utf8).kotlinByteArray))
            saved.fulfill()
        }
        wait(for: [parked], timeout: 10)

        // The parked record sorts oldest, so it is the first thing this write's eviction reaches.
        XCTAssertTrue(store.save(bytes: Data("second".utf8).kotlinByteArray))
        parkedLock.lock()
        let firstRecord = parkedName ?? ""
        parkedLock.unlock()
        let survivedItsOwnWrite = fileExists(firstRecord)

        release.signal()
        wait(for: [saved], timeout: 10)

        XCTAssertFalse(firstRecord.isEmpty)
        XCTAssertTrue(survivedItsOwnWrite)
        XCTAssertTrue(fileExists(firstRecord))
    }

    func testSaveSurvivesATempSweepOfItsInFlightWrite() {
        let fileManager = FileLogStoreReentrantCleanupFileManager()
        let store = FileLogStore(rootPath: temporaryDirectory.path, fileManager: fileManager)
        fileManager.onTemporaryWrite = {
            let done = DispatchSemaphore(value: 0)
            store.deleteUnrecognizedEntries(minAgeMillis: 0) { _, _ in done.signal() }
            XCTAssertEqual(done.wait(timeout: .now() + 5), .success)
        }

        XCTAssertTrue(store.save(bytes: Data("new".utf8).kotlinByteArray))
        XCTAssertEqual(ownedFileNames().count, 1)
        XCTAssertEqual(
            ((try? FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)) ?? [])
                .filter { $0.hasSuffix(".otlp.tmp") }
                .count,
            0
        )
    }

}

/// Record dating when the filesystem will not supply a write time. Data protection denies
/// attributes while the directory still lists, on every reboot until first unlock, so this is
/// the ordinary Apple case rather than a corner of it.
final class FileLogStoreRecordDatingTests: FileLogStoreTestCase {
    // MARK: - reading

    func testRecordWithUnreadableAttributesIsDatedByItsNameAndUploaded() throws {
        // The state of every record on the first launch after a reboot.
        let opaque = try writeProductionShapedRecord(ageMillis: 60_000)
        let fresh = try writeProductionShapedRecord(ageMillis: 60_000)

        let readable = try awaitListReadable(minAgeMillis: 0, attributesUnreadableFor: [opaque])

        XCTAssertTrue(fileExists(opaque))
        XCTAssertEqual(readable.map { $0.id }.sorted(), [opaque, fresh].sorted())
    }

    func testRecordWithUnreadableAttributesPastTheCeilingStillExpires() throws {
        // The fallback must not become an amnesty.
        let ceiling = CrashRetention.shared.defaultPolicy.maxReadAgeMillis
        let stale = try writeProductionShapedRecord(ageMillis: ceiling + 60_000)
        let fresh = try writeProductionShapedRecord(ageMillis: 60_000)

        let readable = try awaitListReadable(minAgeMillis: 0, attributesUnreadableFor: [stale, fresh])

        XCTAssertFalse(fileExists(stale))
        XCTAssertEqual(readable.map { $0.id }, [fresh])
    }

    func testFilesystemTimeDecidesWhenBothSourcesAreAvailable() throws {
        // The name is a fallback, not a second opinion: a rewritten record keeps its original
        // millis, so a readable timestamp has to win.
        let ceiling = CrashRetention.shared.defaultPolicy.maxReadAgeMillis
        let staleName = "\(Self.nowMillis() - ceiling - 60_000)-\(UUID().uuidString).otlp"
        try writeRecord(named: staleName, ageMillis: 60_000)

        let readable = try awaitListReadable(minAgeMillis: 0)

        XCTAssertEqual(readable.map { $0.id }, [staleName])
        XCTAssertTrue(fileExists(staleName))
    }

    func testEntryIsKeptWhenRegularFileBitCannotBeRead() throws {
        // Keep the entry unless the bit is known false; nil must not discard it.
        try writeRecord(named: "present.otlp", ageMillis: 60_000)
        let lookup: FileLogStore.AttributeLookup = { url in
            guard url.lastPathComponent == "present.otlp" else {
                return FileLogStore.defaultAttributeLookup(url)
            }
            var values = URLResourceValues()
            values.contentModificationDate = Date(timeIntervalSinceNow: -60)
            return values
        }

        let readable = try awaitListReadable(minAgeMillis: 0, attributeLookup: lookup)

        XCTAssertEqual(readable.map { $0.id }, ["present.otlp"])
        XCTAssertTrue(fileExists("present.otlp"))
    }

    // MARK: - records nothing can date

    func testUndatableRecordIsWithheldFromReadersRatherThanExpiredOrUploaded() throws {
        // No millis in the name and no readable timestamp. Deleting it would destroy a crash
        // report on no evidence; uploading it would claim an age nothing measured.
        try writeRecord(named: "opaque.otlp", ageMillis: 60_000)
        let fresh = try writeProductionShapedRecord(ageMillis: 60_000)

        let readable = try awaitListReadable(minAgeMillis: 0, attributesUnreadableFor: ["opaque.otlp"])

        XCTAssertTrue(fileExists("opaque.otlp"))
        XCTAssertEqual(readable.map { $0.id }, [fresh])
    }

    func testUndatableRecordsAreStillCountedAndEvictedByTheCaps() throws {
        // Withholding alone would leak: an entry no age gate can select is bounded only by caps.
        let max = Int(CrashRetention.shared.defaultPolicy.maxRecordCount)
        let undatable = (0..<(max + 10)).map { "opaque-\($0).otlp" }
        for name in undatable {
            try writeRecord(named: name, ageMillis: 60_000)
        }

        let readable = try awaitListReadable(
            minAgeMillis: 0,
            attributesUnreadableFor: Set(undatable)
        )

        XCTAssertEqual(readable.count, 0)
        XCTAssertEqual(ownedFileNames().count, max)
    }

    // MARK: - the temp sweep

    func testYoungInterruptedWriteWithUnreadableAttributesIsDatedByItsName() throws {
        // A temp carries the same `{millis}-{uuid}` prefix, so this one is protected by its real
        // age rather than because the sweep gave up on dating it.
        let inFlight = try writeProductionShapedRecord(ageMillis: 100, suffix: ".otlp.tmp")

        let deleted = try awaitDeleteUnrecognized(
            minAgeMillis: 5_000,
            attributesUnreadableFor: [inFlight]
        )

        XCTAssertEqual(deleted, 0)
        XCTAssertTrue(fileExists(inFlight))
    }

    func testOldInterruptedWriteWithUnreadableAttributesIsReaped() throws {
        // Its name dates it, so it is reclaimed on the same pass a readable one would be.
        let abandoned = try writeProductionShapedRecord(ageMillis: 60_000, suffix: ".otlp.tmp")

        let deleted = try awaitDeleteUnrecognized(
            minAgeMillis: 5_000,
            attributesUnreadableFor: [abandoned]
        )

        XCTAssertEqual(deleted, 1)
        XCTAssertFalse(fileExists(abandoned))
    }

    func testUndatableInterruptedWriteIsLeftAlone() throws {
        // Undatable, so it may be a write still in flight: not grounds to delete it.
        try writeRecord(named: "in-flight.otlp.tmp", ageMillis: 60_000)

        let deleted = try awaitDeleteUnrecognized(
            minAgeMillis: 0,
            attributesUnreadableFor: ["in-flight.otlp.tmp"]
        )

        XCTAssertEqual(deleted, 0)
        XCTAssertTrue(fileExists("in-flight.otlp.tmp"))
    }
}

private extension FileLogStoreTestCase {
    /// - Parameter attributesUnreadableFor: names whose resource values the store should see as
    ///   unavailable. This cannot be staged on disk: revoking access fails the listing instead.
    func makeStore(
        attributesUnreadableFor denied: Set<String> = [],
        fileManager: FileManager = .default,
        crashWarn: ((String) -> Void)? = nil,
        attributeLookup: FileLogStore.AttributeLookup? = nil
    ) -> FileLogStore {
        let lookup = attributeLookup ?? { url in
            denied.contains(url.lastPathComponent)
                ? nil
                : FileLogStore.defaultAttributeLookup(url)
        }
        return FileLogStore(
            rootPath: temporaryDirectory.path,
            fileManager: fileManager,
            crashWarn: crashWarn,
            attributeLookup: lookup
        )
    }

    func writeRecord(named name: String, ageMillis: Int64, bytes: Int = 16) throws {
        let url = temporaryDirectory.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        let modified = Date(timeIntervalSinceNow: -Double(ageMillis) / 1_000)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }

    /// A record named the way the store names its own: `{millis}-{uuid}.otlp`. Anything asserting
    /// on dating must use this shape — a name without leading millis cannot reach the name
    /// fallback and silently tests the undatable path instead.
    /// - Returns: the generated name.
    @discardableResult
    func writeProductionShapedRecord(
        ageMillis: Int64,
        bytes: Int = 16,
        suffix: String = ".otlp"
    ) throws -> String {
        let name = "\(Self.nowMillis() - ageMillis)-\(UUID().uuidString)\(suffix)"
        try writeRecord(named: name, ageMillis: ageMillis, bytes: bytes)
        return name
    }

    static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1_000)
    }

    func fileExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent(name).path)
    }

    func ownedFileNames() -> [String] {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)) ?? []
        return contents.filter { $0.hasSuffix(CrashRetention.shared.defaultPolicy.ownedSuffix) }
    }

    func awaitListReadable(
        minAgeMillis: Int64,
        attributesUnreadableFor denied: Set<String> = [],
        attributeLookup: FileLogStore.AttributeLookup? = nil
    ) throws -> [StoredLogFile] {
        let expectation = expectation(description: "listReadable")
        var result: [StoredLogFile] = []
        makeStore(attributesUnreadableFor: denied, attributeLookup: attributeLookup)
            .listReadable(minAgeMillis: minAgeMillis) { entries, _ in
                result = entries ?? []
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 5)
        return result
    }

    func awaitDeleteUnrecognized(
        minAgeMillis: Int64,
        attributesUnreadableFor denied: Set<String> = [],
        fileManager: FileManager = .default
    ) throws -> Int {
        let expectation = expectation(description: "deleteUnrecognizedEntries")
        var deleted = 0
        makeStore(attributesUnreadableFor: denied, fileManager: fileManager)
            .deleteUnrecognizedEntries(minAgeMillis: minAgeMillis) { count, _ in
                deleted = Int(truncating: count ?? 0)
                expectation.fulfill()
            }
        wait(for: [expectation], timeout: 5)
        return deleted
    }
}

private final class FileLogStoreLogListener: NSObject, OSLogListener {
    var entries: [String] = []

    func onLogEvent(_ event: OneSignalLogEvent) {
        entries.append(event.entry)
    }
}

/// `removeItem` reports the file already gone, the way a racing crash-path eviction looks.
private final class FileLogStoreMissingItemFileManager: FileManager {
    override func removeItem(at url: URL) throws {
        throw CocoaError(.fileNoSuchFile)
    }
}

/// Parks the durable write just after its `.tmp` moves into place, so the record is on disk and
/// still in flight while another thread scans the directory.
private final class FileLogStoreMoveBarrierFileManager: FileManager {
    var onMoved: ((URL) -> Void)?

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        try super.moveItem(at: srcURL, to: dstURL)
        onMoved?(dstURL)
    }
}

/// Invokes a hook once the durable write has created its `.tmp`, so a concurrent temp sweep can
/// race the in-flight name.
private final class FileLogStoreReentrantCleanupFileManager: FileManager {
    var onTemporaryWrite: (() -> Void)?

    override func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAtPath path: String) throws {
        try super.setAttributes(attributes, ofItemAtPath: path)
        if path.hasSuffix(".tmp") {
            onTemporaryWrite?()
        }
    }
}
