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
import OneSignalKMP
@testable import OneSignalOSCore
import XCTest

/// The crash directory is a bounded cache, not a queue. Before retention existed, a record that
/// never uploaded was re-read and re-sent on every launch and the directory grew until the OS
/// reclaimed the cache. These cover the bounds that prevent that; the policy decisions
/// themselves are unit-tested in the shared module.
final class FileLogStoreRetentionTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    // MARK: - write-time size limit

    func testRefusesPayloadOverThePerRecordLimit() {
        let store = makeStore()
        let oversized = Data(count: Int(CrashRetention.shared.maxRecordBytes) + 1)

        XCTAssertFalse(store.save(bytes: oversized.kotlinByteArray))
        XCTAssertEqual(ownedFileNames().count, 0)
    }

    func testAcceptsPayloadAtTheLimit() {
        let store = makeStore()
        let atLimit = Data(count: Int(CrashRetention.shared.maxRecordBytes))

        XCTAssertTrue(store.save(bytes: atLimit.kotlinByteArray))
        XCTAssertEqual(ownedFileNames().count, 1)
    }

    // MARK: - age ceiling

    func testListReadableDropsAndDeletesRecordsPastTheAgeCeiling() throws {
        let ceiling = CrashRetention.shared.maxReadAgeMillis
        try writeRecord(named: "expired.otlp", ageMillis: ceiling + 60_000)
        try writeRecord(named: "fresh.otlp", ageMillis: 60_000)

        let readable = try awaitListReadable(minAgeMillis: 0)

        XCTAssertEqual(readable.map { $0.id }, ["fresh.otlp"])
        XCTAssertFalse(fileExists("expired.otlp"))
        XCTAssertTrue(fileExists("fresh.otlp"))
    }

    func testRecordInsideTheAgeWindowIsRetained() throws {
        let ceiling = CrashRetention.shared.maxReadAgeMillis
        try writeRecord(named: "edge.otlp", ageMillis: ceiling - 60_000)

        let readable = try awaitListReadable(minAgeMillis: 0)

        XCTAssertEqual(readable.map { $0.id }, ["edge.otlp"])
        XCTAssertTrue(fileExists("edge.otlp"))
    }

    // MARK: - accumulation caps

    func testListReadableReclaimsAnInheritedOverCapBacklog() throws {
        // The upgrade case: a directory written by a build with no caps. It must be trimmed on
        // the first uploader pass rather than waiting for the next crash to trigger a write.
        let max = Int(CrashRetention.shared.maxRecordCount)
        for index in 0..<(max + 10) {
            try writeRecord(named: "seed-\(index).otlp", ageMillis: Int64(1_000 * (index + 1)))
        }

        let readable = try awaitListReadable(minAgeMillis: 0)

        XCTAssertEqual(readable.count, max)
        XCTAssertEqual(ownedFileNames().count, max)
    }

    func testSaveEvictsOldestFirstPastTheCountCap() throws {
        let max = Int(CrashRetention.shared.maxRecordCount)
        for index in 0..<max {
            try writeRecord(named: "seed-\(index).otlp", ageMillis: Int64(1_000 * (index + 1)))
        }
        let oldest = "seed-\(max - 1).otlp"

        XCTAssertTrue(makeStore().save(bytes: Data("new".utf8).kotlinByteArray))

        XCTAssertEqual(ownedFileNames().count, max)
        XCTAssertFalse(fileExists(oldest))
        XCTAssertTrue(fileExists("seed-0.otlp"))
    }

    func testSaveNeverEvictsTheRecordItJustWrote() throws {
        let max = Int(CrashRetention.shared.maxRecordCount)
        for index in 0..<(max + 5) {
            try writeRecord(named: "seed-\(index).otlp", ageMillis: Int64(1_000 * (index + 1)))
        }

        XCTAssertTrue(makeStore().save(bytes: Data("new".utf8).kotlinByteArray))

        let survivors = ownedFileNames()
        XCTAssertEqual(survivors.count, max)
        // The just-written record is the only one not named seed-*.
        XCTAssertEqual(survivors.filter { !$0.hasPrefix("seed-") }.count, 1)
    }

    // MARK: - foreign entries

    func testDeleteUnrecognizedReapsOnlyThisStoresInterruptedWrites() throws {
        // Narrower than Android on purpose: iOS never ran the OpenTelemetry pipeline, so there
        // is no legacy format sharing this directory. Only our own `.otlp.tmp` is reclaimed.
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
        // This is the only scan that runs when remote logging is disabled, so it is the sole
        // opportunity to bound a directory nothing ever reads.
        let max = Int(CrashRetention.shared.maxRecordCount)
        for index in 0..<(max + 10) {
            try writeRecord(named: "seed-\(index).otlp", ageMillis: Int64(1_000 * (index + 1)))
        }

        _ = try awaitDeleteUnrecognized(minAgeMillis: 0)

        XCTAssertEqual(ownedFileNames().count, max)
    }

    // MARK: - helpers

    private func makeStore() -> FileLogStore {
        FileLogStore(rootPath: temporaryDirectory.path)
    }

    private func writeRecord(named name: String, ageMillis: Int64, bytes: Int = 16) throws {
        let url = temporaryDirectory.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        let modified = Date(timeIntervalSinceNow: -Double(ageMillis) / 1_000)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    }

    private func fileExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: temporaryDirectory.appendingPathComponent(name).path)
    }

    private func ownedFileNames() -> [String] {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)) ?? []
        return contents.filter { $0.hasSuffix(".otlp") }
    }

    private func awaitListReadable(minAgeMillis: Int64) throws -> [StoredLogFile] {
        let expectation = expectation(description: "listReadable")
        var result: [StoredLogFile] = []
        makeStore().listReadable(minAgeMillis: minAgeMillis) { entries, _ in
            result = entries ?? []
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        return result
    }

    private func awaitDeleteUnrecognized(minAgeMillis: Int64) throws -> Int {
        let expectation = expectation(description: "deleteUnrecognizedEntries")
        var deleted = 0
        makeStore().deleteUnrecognizedEntries(minAgeMillis: minAgeMillis) { count, _ in
            deleted = Int(truncating: count ?? 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5)
        return deleted
    }
}
