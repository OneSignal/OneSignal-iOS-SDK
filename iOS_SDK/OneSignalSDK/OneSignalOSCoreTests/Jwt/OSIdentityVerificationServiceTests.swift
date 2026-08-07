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

final class OSIdentityVerificationServiceTests: XCTestCase {

    private var jwtConfig = OSUserJwtConfig()
    private var featureManager = OSFeatureManager(enabledKeys: [])

    override func setUp() {
        super.setUp()
        clearCache()
        jwtConfig = OSUserJwtConfig()
        featureManager = OSFeatureManager(enabledKeys: [])
    }

    override func tearDown() {
        clearCache()
        super.tearDown()
    }

    private func clearCache() {
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_USE_IDENTITY_VERIFICATION)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_FEATURE_FLAGS)
    }

    private func makeService() -> OSIdentityVerificationService {
        return OSIdentityVerificationService(featureManager: featureManager, jwtConfig: jwtConfig)
    }

    // MARK: - Gates

    func testBothGatesAreOffForAnAppWithoutTheFlagOrTheRequirement() {
        let service = makeService()
        jwtConfig.hydrate(requiresUserAuth: false)

        XCTAssertFalse(service.newCodePathsRun)
        XCTAssertFalse(service.ivBehaviorActive)
    }

    func testTheFlagAloneRunsTheNewCodePathsWithoutTurningOnTheBehavior() {
        featureManager = OSFeatureManager(enabledKeys: [OSFeatureFlag.identityVerification.rawValue])
        let service = makeService()
        jwtConfig.hydrate(requiresUserAuth: false)

        XCTAssertTrue(service.newCodePathsRun)
        XCTAssertFalse(service.ivBehaviorActive)
    }

    func testAnAppThatRequiresAuthIsGatedInRegardlessOfTheFlag() {
        let service = makeService()
        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertTrue(service.newCodePathsRun)
        XCTAssertTrue(service.ivBehaviorActive)
    }

    func testBothGatesAreOffBeforeRemoteParamsAreRead() {
        let service = makeService()

        XCTAssertFalse(service.newCodePathsRun)
        XCTAssertFalse(service.ivBehaviorActive)
    }

    func testAnUnknownRequirementStaysVisibleWhileTheFlagRunsTheNewCodePaths() {
        featureManager = OSFeatureManager(enabledKeys: [OSFeatureFlag.identityVerification.rawValue])
        let service = makeService()

        XCTAssertTrue(service.newCodePathsRun)
        // Neither gate can tell unknown from off, so callers about to send unsigned work read this instead
        XCTAssertFalse(service.ivBehaviorActive)
        XCTAssertEqual(service.requirement, .unknown)
    }

    func testGatesFollowTheFlagWithinTheSameRun() {
        let realFeatureManager = OSFeatureManager()
        let service = OSIdentityVerificationService(featureManager: realFeatureManager, jwtConfig: jwtConfig)
        jwtConfig.hydrate(requiresUserAuth: false)

        realFeatureManager.setEnabledFeatureKeys([OSFeatureFlag.identityVerification.rawValue])
        XCTAssertTrue(service.newCodePathsRun)

        realFeatureManager.setEnabledFeatureKeys([])
        XCTAssertFalse(service.newCodePathsRun)
    }

    // MARK: - Hydration handler

    func testTheHandlerRunsForEveryHydration() {
        let service = makeService()
        var requirements: [OSRequiresUserAuth] = []
        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { requirements.append($0) }

        jwtConfig.hydrate(requiresUserAuth: true)
        jwtConfig.hydrate(requiresUserAuth: true)

        // Work deferred while the requirement was unknown needs the repeat too, not just the change
        XCTAssertEqual(requirements, [.on, .on])
    }

    func testTheHandlerReceivesTheHydratedRequirement() {
        let service = makeService()
        var requirement: OSRequiresUserAuth?
        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { requirement = $0 }

        jwtConfig.hydrate(requiresUserAuth: false)

        XCTAssertEqual(requirement, .off)
    }

    func testRemovingTheHandlerStopsTheCallbacks() {
        let service = makeService()
        var callCount = 0
        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { _ in callCount += 1 }
        service.removeOnJwtConfigHydratedHandler(for: .operationRepo)

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(callCount, 0)
    }

    func testAHandlerRegisteredAfterHydrationRunsImmediately() {
        let service = makeService()
        jwtConfig.hydrate(requiresUserAuth: true)

        var requirement: OSRequiresUserAuth?
        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { requirement = $0 }

        // Remote params can return before the repo subscribes, and that hydration does not come again
        XCTAssertEqual(requirement, .on)
    }

    func testAHandlerRegisteredBeforeRemoteParamsWaitsForThem() {
        let service = makeService()
        var callCount = 0

        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { _ in callCount += 1 }

        XCTAssertEqual(callCount, 0)
    }

    func testHydratingAfterTheServiceIsReleasedIsANoOp() {
        var service: OSIdentityVerificationService? = makeService()
        var callCount = 0
        service?.addOnJwtConfigHydratedHandler(for: .operationRepo) { _ in callCount += 1 }
        service = nil

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(callCount, 0)
    }

    // MARK: - Multiple observers

    /// The User executor and the operation repo both wait on hydration; neither may displace the other.
    func testEveryObserverIsNotified() {
        let service = makeService()
        var notified: [OSJwtConfigHydratedObserver] = []
        service.addOnJwtConfigHydratedHandler(for: .userExecutor) { _ in notified.append(.userExecutor) }
        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { _ in notified.append(.operationRepo) }

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(notified, [.userExecutor, .operationRepo])
    }

    /// Registration order, so a held Create User goes out before Deltas that need its `onesignal_id`.
    func testObserversAreNotifiedInRegistrationOrder() {
        let service = makeService()
        var notified: [OSJwtConfigHydratedObserver] = []
        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { _ in notified.append(.operationRepo) }
        service.addOnJwtConfigHydratedHandler(for: .userExecutor) { _ in notified.append(.userExecutor) }

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(notified, [.operationRepo, .userExecutor])
    }

    /// A rebuilt observer replaces its own registration rather than leaving the old closure behind.
    func testReRegisteringTheSameObserverReplacesIt() {
        let service = makeService()
        var firstCallCount = 0
        var secondCallCount = 0
        service.addOnJwtConfigHydratedHandler(for: .userExecutor) { _ in firstCallCount += 1 }
        service.addOnJwtConfigHydratedHandler(for: .userExecutor) { _ in secondCallCount += 1 }

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(firstCallCount, 0)
        XCTAssertEqual(secondCallCount, 1)
    }

    /// Replacing keeps the original position, so ordering does not shift under a rebuild.
    func testReplacingAnObserverKeepsItsPosition() {
        let service = makeService()
        var notified: [String] = []
        service.addOnJwtConfigHydratedHandler(for: .userExecutor) { _ in notified.append("user-executor-original") }
        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { _ in notified.append("operation-repo") }
        service.addOnJwtConfigHydratedHandler(for: .userExecutor) { _ in notified.append("user-executor-replacement") }

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(notified, ["user-executor-replacement", "operation-repo"])
    }

    func testRemovingOneObserverLeavesTheOther() {
        let service = makeService()
        var notified: [OSJwtConfigHydratedObserver] = []
        service.addOnJwtConfigHydratedHandler(for: .userExecutor) { _ in notified.append(.userExecutor) }
        service.addOnJwtConfigHydratedHandler(for: .operationRepo) { _ in notified.append(.operationRepo) }
        service.removeOnJwtConfigHydratedHandler(for: .userExecutor)

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(notified, [.operationRepo])
    }
}
