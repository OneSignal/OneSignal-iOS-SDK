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
import XCTest
import OneSignalCore
@testable import OneSignalOSCore

/// Covers `flushDeltaQueue` routing: matched deltas go to executors and leave the repo
/// queue; unmatched names stay queued (and in order).
final class OSOperationRepoFlushTests: XCTestCase {

    private let knownDelta = "test_known_delta"
    private let unknownDelta = "test_unknown_delta"

    override func setUp() {
        super.setUp()
        OneSignalIdentifiers.currentAppId = "test-app-id"
        resetOperationRepo()
        // Pause so the poller (started by addExecutor/start) cannot flush mid-setup.
        OSOperationRepo.sharedInstance.paused = true
        OSOperationRepo.sharedInstance.pollIntervalMilliseconds = 60_000
    }

    override func tearDown() {
        resetOperationRepo()
        super.tearDown()
    }

    func testFlush_sendsMatchedDeltasToExecutorAndClearsRepoQueue() {
        let executor = MockOperationExecutor(supportedDeltas: [knownDelta])
        let processExpectation = expectation(description: "processDeltaQueue")
        executor.onProcessDeltaQueue = { processExpectation.fulfill() }

        let repo = OSOperationRepo.sharedInstance
        repo.addExecutor(executor)

        let deltaA = makeDelta(name: knownDelta, property: "a")
        let deltaB = makeDelta(name: knownDelta, property: "b")
        repo.enqueueDelta(deltaA)
        repo.enqueueDelta(deltaB)
        waitUntil("both deltas enqueued") { repo.deltaQueue.count == 2 }

        repo.paused = false
        repo.addFlushDeltaQueueToDispatchQueue()
        wait(for: [processExpectation], timeout: 2.0)

        XCTAssertEqual(executor.enqueued.map(\.property), ["a", "b"])
        XCTAssertTrue(repo.deltaQueue.isEmpty)
    }

    func testFlush_keepsUnmatchedDeltasInRepoQueue() {
        let executor = MockOperationExecutor(supportedDeltas: [knownDelta])
        let processExpectation = expectation(description: "processDeltaQueue")
        executor.onProcessDeltaQueue = { processExpectation.fulfill() }

        let repo = OSOperationRepo.sharedInstance
        repo.addExecutor(executor)

        let deltaA = makeDelta(name: unknownDelta, property: "a")
        let deltaB = makeDelta(name: unknownDelta, property: "b")
        repo.enqueueDelta(deltaA)
        repo.enqueueDelta(deltaB)
        waitUntil("both deltas enqueued") { repo.deltaQueue.count == 2 }

        repo.paused = false
        repo.addFlushDeltaQueueToDispatchQueue()
        wait(for: [processExpectation], timeout: 2.0)

        XCTAssertTrue(executor.enqueued.isEmpty)
        XCTAssertEqual(repo.deltaQueue.map(\.property), ["a", "b"])
    }

    func testFlush_routesMatchedAndPreservesUnmatchedOrder() {
        let executor = MockOperationExecutor(supportedDeltas: [knownDelta])
        let processExpectation = expectation(description: "processDeltaQueue")
        executor.onProcessDeltaQueue = { processExpectation.fulfill() }

        let repo = OSOperationRepo.sharedInstance
        repo.addExecutor(executor)

        // Interleaved matched/unmatched: assert dispatch order and retained queue order.
        repo.enqueueDelta(makeDelta(name: knownDelta, property: "known-1"))
        repo.enqueueDelta(makeDelta(name: unknownDelta, property: "unknown-1"))
        repo.enqueueDelta(makeDelta(name: knownDelta, property: "known-2"))
        repo.enqueueDelta(makeDelta(name: unknownDelta, property: "unknown-2"))
        repo.enqueueDelta(makeDelta(name: knownDelta, property: "known-3"))
        waitUntil("all deltas enqueued") { repo.deltaQueue.count == 5 }

        repo.paused = false
        repo.addFlushDeltaQueueToDispatchQueue()
        wait(for: [processExpectation], timeout: 2.0)

        XCTAssertEqual(executor.enqueued.map(\.property), ["known-1", "known-2", "known-3"])
        XCTAssertEqual(repo.deltaQueue.map(\.property), ["unknown-1", "unknown-2"])
    }

    // MARK: - Helpers

    private func resetOperationRepo() {
        let repo = OSOperationRepo.sharedInstance
        repo.deltaQueue.removeAll()
        repo.executors.removeAll()
        repo.deltasToExecutorMap.removeAll()
        repo.paused = false
    }

    private func makeDelta(name: String, property: String) -> OSDelta {
        OSDelta(
            name: name,
            identityModelId: UUID().uuidString,
            externalId: nil,
            model: OSModel(changeNotifier: OSEventProducer()),
            property: property,
            value: property
        )
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2.0,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) {
        let exp = expectation(description: description)
        let timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                exp.fulfill()
            }
        }
        let result = XCTWaiter.wait(for: [exp], timeout: timeout)
        timer.invalidate()
        XCTAssertEqual(result, .completed, "Timed out waiting for: \(description)", file: file, line: line)
    }
}

private final class MockOperationExecutor: OSOperationExecutor {
    let supportedDeltas: [String]
    private(set) var enqueued: [OSDelta] = []
    var onProcessDeltaQueue: (() -> Void)?

    init(supportedDeltas: [String]) {
        self.supportedDeltas = supportedDeltas
    }

    func enqueueDelta(_ delta: OSDelta) {
        enqueued.append(delta)
    }

    func cacheDeltaQueue() {}

    func processDeltaQueue(inBackground: Bool) {
        onProcessDeltaQueue?()
    }
}
