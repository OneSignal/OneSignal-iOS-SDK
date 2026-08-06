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

final class OSLoggerAdaptersTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testFileStoreSynchronouslySavesAndListsPayload() throws {
        let store = OSLogFileStore(rootPath: temporaryDirectory.path)
        let payload = makeKotlinBytes([1, 2, 3, 255])

        XCTAssertTrue(store.save(bytes: payload))
        let files = try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files[0].hasSuffix(".otlp"))

        let listed = expectation(description: "lists saved payload")
        store.listReadable(minAgeMillis: 0) { records, error in
            XCTAssertNil(error)
            XCTAssertEqual(records?.count, 1)
            XCTAssertEqual(records?.first?.id, files[0])
            XCTAssertEqual(records?.first?.bytes.bytes, [1, 2, 3, 255])
            listed.fulfill()
        }
        wait(for: [listed], timeout: 2)
    }

    func testFileStoreDeletesOnlyOldUnrecognizedEntries() throws {
        let store = OSLogFileStore(rootPath: temporaryDirectory.path)
        XCTAssertTrue(store.save(bytes: makeKotlinBytes([1])))

        let foreignURL = temporaryDirectory.appendingPathComponent("legacy-crash")
        try Data([2]).write(to: foreignURL)

        let cleaned = expectation(description: "cleans foreign payload")
        store.deleteUnrecognizedEntries(minAgeMillis: 0) { count, error in
            XCTAssertNil(error)
            XCTAssertEqual(count?.int32Value, 1)
            XCTAssertFalse(FileManager.default.fileExists(atPath: foreignURL.path))
            cleaned.fulfill()
        }
        wait(for: [cleaned], timeout: 2)

        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)
                .filter { $0.hasSuffix(".otlp") }
                .count,
            1
        )
    }

    func testHttpSenderPostsEncodedBytesAndPassesHeaders() {
        let sent = expectation(description: "sends payload")
        let sender = OSLogHttpSender { request, completion in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-protobuf")
            XCTAssertEqual(request.value(forHTTPHeaderField: "SDK-Version"), "onesignal/ios/test")
            XCTAssertEqual(request.httpBody, Data([4, 5, 6]))
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 202,
                httpVersion: nil,
                headerFields: nil
            )!
            completion(nil, response, nil)
        }

        let request = LogHttpRequest(
            url: "https://example.com/sdk/log",
            headers: ["SDK-Version": "onesignal/ios/test"],
            contentType: "application/x-protobuf",
            body: makeKotlinBytes([4, 5, 6])
        )
        sender.send(request: request) { response, error in
            XCTAssertNil(error)
            XCTAssertEqual(response?.statusCode, 202)
            XCTAssertTrue(response?.success == true)
            sent.fulfill()
        }

        wait(for: [sent], timeout: 2)
    }

    func testLoggerDelegatesToOneSignalLog() {
        let listener = LoggerAdapterListener()
        OneSignalLog.debug().__add(listener)
        defer { OneSignalLog.debug().__remove(listener) }

        let logger = OSLoggerAdapter()
        logger.error(message: "error")
        logger.warn(message: "warn")
        logger.info(message: "info")
        logger.debug(message: "debug")

        XCTAssertEqual(listener.levels, [.LL_ERROR, .LL_WARN, .LL_INFO, .LL_DEBUG])
    }

    func testPlatformProviderReturnsInjectedIdentifiersAndPlatformMetadata() {
        let provider = OSLoggerPlatformProvider(
            onesignalIdProvider: { "onesignal-id" },
            pushSubscriptionIdProvider: { "subscription-id" },
            appStateProvider: { "foreground" }
        )
        var firstInstallId: String?
        var secondInstallId: String?

        provider.getInstallId { value, _ in firstInstallId = value }
        provider.getInstallId { value, _ in secondInstallId = value }

        XCTAssertFalse(firstInstallId?.isEmpty ?? true)
        XCTAssertEqual(firstInstallId, secondInstallId)
        XCTAssertEqual(provider.onesignalId, "onesignal-id")
        XCTAssertEqual(provider.pushSubscriptionId, "subscription-id")
        XCTAssertEqual(provider.appState, "foreground")
        XCTAssertEqual(provider.sdkBase, "ios")
        XCTAssertFalse(provider.appPackageId.isEmpty)
        XCTAssertFalse(provider.osVersion.isEmpty)
        XCTAssertGreaterThanOrEqual(provider.processUptime, 0)
    }

    private func makeKotlinBytes(_ bytes: [UInt8]) -> KotlinByteArray {
        KotlinByteArray(size: Int32(bytes.count)) { index in
            KotlinByte(value: Int8(bitPattern: bytes[Int(index.int32Value)]))
        }
    }
}

private final class LoggerAdapterListener: NSObject, OSLogListener {
    var levels: [ONE_S_LOG_LEVEL] = []

    func onLogEvent(_ event: OneSignalLogEvent) {
        levels.append(event.level)
    }
}

private extension KotlinByteArray {
    var bytes: [UInt8] {
        (0..<size).map { UInt8(bitPattern: get(index: $0)) }
    }
}
