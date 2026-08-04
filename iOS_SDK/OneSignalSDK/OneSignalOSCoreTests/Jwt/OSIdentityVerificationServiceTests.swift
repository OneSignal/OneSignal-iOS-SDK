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
        service.setOnJwtConfigHydratedHandler { requirements.append($0) }

        jwtConfig.hydrate(requiresUserAuth: true)
        jwtConfig.hydrate(requiresUserAuth: true)

        // Work deferred while the requirement was unknown needs the repeat too, not just the change
        XCTAssertEqual(requirements, [.on, .on])
    }

    func testTheHandlerReceivesTheHydratedRequirement() {
        let service = makeService()
        var requirement: OSRequiresUserAuth?
        service.setOnJwtConfigHydratedHandler { requirement = $0 }

        jwtConfig.hydrate(requiresUserAuth: false)

        XCTAssertEqual(requirement, .off)
    }

    func testClearingTheHandlerStopsTheCallbacks() {
        let service = makeService()
        var callCount = 0
        service.setOnJwtConfigHydratedHandler { _ in callCount += 1 }
        service.setOnJwtConfigHydratedHandler(nil)

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(callCount, 0)
    }

    func testHydratingAfterTheServiceIsReleasedIsANoOp() {
        var service: OSIdentityVerificationService? = makeService()
        var callCount = 0
        service?.setOnJwtConfigHydratedHandler { _ in callCount += 1 }
        service = nil

        jwtConfig.hydrate(requiresUserAuth: true)

        XCTAssertEqual(callCount, 0)
    }
}
