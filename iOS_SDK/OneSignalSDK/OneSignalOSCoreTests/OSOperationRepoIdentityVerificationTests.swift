/*
 Modified MIT License

 Copyright 2025 OneSignal

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

/// Covers Operation Repo Identity Verification: hold until `requirement` is known, drop unsigned work.
final class OSOperationRepoIdentityVerificationTests: XCTestCase {

    private let deltaName = "test_delta"

    private var jwtConfig = OSUserJwtConfig()
    private var featureManager = OSFeatureManager(enabledKeys: [])

    override func setUp() {
        super.setUp()
        OneSignalIdentifiers.currentAppId = "test-app-id"
        OSOperationRepoTestEnvironment.clearCache()
        jwtConfig = OSUserJwtConfig()
        featureManager = OSFeatureManager(enabledKeys: [])
    }

    override func tearDown() {
        OSOperationRepoTestEnvironment.clearCache()
        super.tearDown()
    }

    // MARK: - Deferral while the requirement is unknown

    func testNothingFlushesWhileTheRequirementIsUnknown() {
        let repo = makeRepo()
        let executor = MockOperationExecutor(supportedDeltas: [deltaName])
        let notProcessed = expectation(description: "processDeltaQueue is not called")
        notProcessed.isInverted = true
        executor.onProcessDeltaQueue = { notProcessed.fulfill() }
        repo.addExecutor(executor)

        repo.enqueueDelta(makeDelta(externalId: "user-1", property: "a"))
        repo.enqueueDelta(makeDelta(externalId: "user-1", property: "b"))
        waitUntil("both deltas enqueued") { repo.deltaQueue.count == 2 }

        repo.addFlushDeltaQueueToDispatchQueue()

        wait(for: [notProcessed], timeout: 0.5)
        XCTAssertTrue(executor.enqueued.isEmpty)
        XCTAssertEqual(repo.deltaQueue.map(\.property), ["a", "b"])
    }

    /// Enqueue still persists while unknown; only flush waits.
    func testDeltasEnqueuedWhileTheRequirementIsUnknownArePersisted() {
        let repo = makeRepo()
        repo.enqueueDelta(makeDelta(externalId: "user-1", property: "a"))
        waitUntil("delta enqueued") { repo.deltaQueue.count == 1 }

        let cached = OSOperationRepoTestEnvironment.cachedDeltaQueue()
        XCTAssertEqual(cached?.map(\.property), ["a"])
    }

    /// Hydration must flush immediately rather than wait out a poll interval.
    func testHydratingTheRequirementReleasesHeldDeltasImmediately() {
        let repo = makeRepo()
        let executor = MockOperationExecutor(supportedDeltas: [deltaName])
        let processed = expectation(description: "processDeltaQueue")
        executor.onProcessDeltaQueue = { processed.fulfill() }
        repo.addExecutor(executor)

        repo.enqueueDelta(makeDelta(externalId: "user-1", property: "a"))
        waitUntil("delta enqueued") { repo.deltaQueue.count == 1 }

        jwtConfig.hydrate(requiresUserAuth: false)

        wait(for: [processed], timeout: 2.0)
        XCTAssertEqual(executor.enqueued.map(\.property), ["a"])
        XCTAssertTrue(repo.deltaQueue.isEmpty)
    }

    // MARK: - Anonymous suppression

    /// No `externalId` means nothing to sign with, so drop at enqueue while IV is required.
    func testAnonymousDeltasAreDroppedAtEnqueueWhileIdentityVerificationIsRequired() {
        // Hydrate first and pause so this asserts the enqueue drop, not a flush.
        jwtConfig.hydrate(requiresUserAuth: true)
        let repo = makeRepo()
        repo.paused = true

        repo.enqueueDelta(makeDelta(externalId: nil, property: "anonymous"))
        repo.enqueueDelta(makeDelta(externalId: "user-1", property: "identified"))

        // Identified Delta is the sync point; the queue is serial.
        waitUntil("identified delta enqueued") { repo.deltaQueue.count == 1 }
        XCTAssertEqual(repo.deltaQueue.map(\.property), ["identified"])
    }

    /// Flush must drop restored anonymous Deltas; they never pass through enqueue.
    func testAnonymousDeltasRestoredFromTheCacheAreDroppedAtFlush() {
        OSOperationRepoTestEnvironment.seedCachedDeltaQueue([
            makeDelta(externalId: nil, property: "anonymous"),
            makeDelta(externalId: "user-1", property: "identified")
        ])

        let repo = makeRepo()
        XCTAssertEqual(repo.deltaQueue.count, 2, "the repo should restore both Deltas before judging them")

        let executor = MockOperationExecutor(supportedDeltas: [deltaName])
        let processed = expectation(description: "processDeltaQueue")
        executor.onProcessDeltaQueue = { processed.fulfill() }
        repo.addExecutor(executor)

        jwtConfig.hydrate(requiresUserAuth: true)

        wait(for: [processed], timeout: 2.0)
        XCTAssertEqual(executor.enqueued.map(\.property), ["identified"])
        XCTAssertTrue(repo.deltaQueue.isEmpty)
    }

    /// The rollout flag alone must not suppress; only `jwt_required` turns it on.
    func testAnonymousDeltasSurviveWhenTheFlagIsOnButTheAppDoesNotRequireAuth() {
        featureManager = OSFeatureManager(enabledKeys: [OSFeatureFlag.identityVerification.rawValue])

        let repo = makeRepo()
        let executor = MockOperationExecutor(supportedDeltas: [deltaName])
        let processed = expectation(description: "processDeltaQueue")
        executor.onProcessDeltaQueue = { processed.fulfill() }
        repo.addExecutor(executor)

        repo.enqueueDelta(makeDelta(externalId: nil, property: "anonymous"))
        waitUntil("delta enqueued") { repo.deltaQueue.count == 1 }

        jwtConfig.hydrate(requiresUserAuth: false)

        wait(for: [processed], timeout: 2.0)
        XCTAssertEqual(executor.enqueued.map(\.property), ["anonymous"])
    }

    // MARK: - Purge when the requirement arrives as required

    /// Unsupported delta name on purpose so survival is by `externalId`, not routing.
    func testLearningThatAuthIsRequiredDropsAnonymousDeltasAndKeepsIdentifiedOnes() {
        OSOperationRepoTestEnvironment.seedCachedDeltaQueue([
            makeDelta(externalId: nil, property: "anonymous"),
            makeDelta(externalId: "user-1", property: "identified")
        ])

        let repo = makeRepo()
        let executor = MockOperationExecutor(supportedDeltas: ["some_other_delta"])
        let processed = expectation(description: "processDeltaQueue")
        executor.onProcessDeltaQueue = { processed.fulfill() }
        repo.addExecutor(executor)

        jwtConfig.hydrate(requiresUserAuth: true)

        wait(for: [processed], timeout: 2.0)
        XCTAssertEqual(repo.deltaQueue.map(\.property), ["identified"])

        let cached = OSOperationRepoTestEnvironment.cachedDeltaQueue()
        XCTAssertEqual(cached?.map(\.property), ["identified"], "the drop has to survive a restart")
    }

    /// Executor caches hold last session's deltas, so the purge must reach them too.
    func testFlushingWhileAuthIsRequiredDrivesThePurgeIntoExecutors() {
        let repo = makeRepo()
        let executor = MockOperationExecutor(supportedDeltas: [deltaName])
        repo.addExecutor(executor)

        jwtConfig.hydrate(requiresUserAuth: true)

        waitUntil("executor asked to purge") { executor.removeOperationsWithoutExternalIdCallCount >= 1 }
    }

    func testFlushingWhileAuthIsNotRequiredLeavesAnonymousDeltasAlone() {
        OSOperationRepoTestEnvironment.seedCachedDeltaQueue([
            makeDelta(externalId: nil, property: "anonymous")
        ])

        let repo = makeRepo()
        let executor = MockOperationExecutor(supportedDeltas: ["some_other_delta"])
        let processed = expectation(description: "processDeltaQueue")
        executor.onProcessDeltaQueue = { processed.fulfill() }
        repo.addExecutor(executor)

        jwtConfig.hydrate(requiresUserAuth: false)

        wait(for: [processed], timeout: 2.0)
        XCTAssertEqual(repo.deltaQueue.map(\.property), ["anonymous"])
        XCTAssertEqual(executor.removeOperationsWithoutExternalIdCallCount, 0)
    }

    // MARK: - Helpers

    private func makeRepo() -> OSOperationRepo {
        return OSOperationRepoTestEnvironment.makeRepo(jwtConfig: jwtConfig, featureManager: featureManager)
    }

    private func makeDelta(externalId: String?, property: String) -> OSDelta {
        return OSOperationRepoTestEnvironment.makeDelta(name: deltaName, externalId: externalId, property: property)
    }
}
