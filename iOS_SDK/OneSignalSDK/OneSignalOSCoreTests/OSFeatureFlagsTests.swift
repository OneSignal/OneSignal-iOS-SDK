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

final class OSFeatureManagerTests: XCTestCase {
    private var store: OSFeatureFlagsStore!

    override func setUp() {
        super.setUp()
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAG_METADATA)
        OSFeatureManager.localFeatureOverrides = []
        // One test drives the real singleton, so drop it either side to keep the
        // process-wide latch from leaking between cases.
        OSFeatureManager.reset()
        store = OSFeatureFlagsStore()
    }

    override func tearDown() {
        OSFeatureManager.localFeatureOverrides = []
        OSFeatureManager.didConstructForTesting = nil
        OSFeatureManager.reset()
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAG_METADATA)
        super.tearDown()
    }

    func testIsEnabledIsFalseWhenTheKeyIsNotPresent() {
        let manager = OSFeatureManager(store: store)
        XCTAssertFalse(manager.isEnabled(featureKey: FeatureFlag.sdkIdentityVerification.key))
    }

    func testInitialStateEnablesAFeatureWhenItsKeyIsPresent() {
        store.applyRemoteFlags([FeatureFlag.sdkIdentityVerification.key], metadata: nil)
        let manager = OSFeatureManager(store: store)
        XCTAssertTrue(manager.isEnabled(featureKey: FeatureFlag.sdkIdentityVerification.key))
    }

    func testInitialStateEnablesAFeatureWhenTheRemoteKeyDiffersOnlyByLetterCase() {
        store.applyRemoteFlags(["SDK_Identity_Verification"], metadata: nil)
        let manager = OSFeatureManager(store: store)
        XCTAssertTrue(manager.isEnabled(featureKey: FeatureFlag.sdkIdentityVerification.key))
    }

    func testRemoteFeatureFlagMetadataReturnsParsedJSONFromStore() {
        store.applyRemoteFlags([], metadata: #"{"X":{"note":"y"}}"#)
        let manager = OSFeatureManager(store: store)
        let meta = manager.remoteFeatureFlagMetadata()
        XCTAssertNotNil(meta)
        XCTAssertTrue(meta?["X"]?.contains("\"note\"") == true)
        XCTAssertTrue(meta?["X"]?.contains("y") == true)
    }

    func testRemoteFeatureFlagMetadataIsNilWhenStoreHasNoMetadata() {
        let manager = OSFeatureManager(store: store)
        XCTAssertNil(manager.remoteFeatureFlagMetadata())
    }

    func testEnabledFeatureKeysIsEmptyWhenNoFlagsAreEnabled() {
        let manager = OSFeatureManager(store: store)
        XCTAssertEqual(manager.enabledFeatureKeys(), [])
    }

    func testEnabledFeatureKeysReturnsCanonicalKeyWhenEnabledAtStartup() {
        store.applyRemoteFlags([FeatureFlag.sdkIdentityVerification.key], metadata: nil)
        let manager = OSFeatureManager(store: store)
        XCTAssertEqual(manager.enabledFeatureKeys(), [FeatureFlag.sdkIdentityVerification.key])
    }

    func testIdentityVerificationIsImmediateMidSessionFlagFlipFlowsThroughIsEnabled() {
        let manager = OSFeatureManager(store: store)
        XCTAssertFalse(manager.isEnabled(featureKey: FeatureFlag.sdkIdentityVerification.key))

        store.applyRemoteFlags([FeatureFlag.sdkIdentityVerification.key], metadata: nil)

        XCTAssertTrue(manager.isEnabled(featureKey: FeatureFlag.sdkIdentityVerification.key))
    }

    func testAppStartupCustomLoggingStaysLatchedMidSession() {
        store.applyRemoteFlags([FeatureFlag.sdkCustomLogging.key], metadata: nil)
        let manager = OSFeatureManager(store: store)
        XCTAssertTrue(manager.isEnabled(featureKey: FeatureFlag.sdkCustomLogging.key))

        store.applyRemoteFlags([], metadata: nil)

        XCTAssertTrue(manager.isEnabled(featureKey: FeatureFlag.sdkCustomLogging.key))
    }

    /// Construction happens outside the lock, so an app-id change can land after a
    /// manager has read storage but before it publishes itself. Publishing it anyway
    /// would restore exactly the `APP_STARTUP` latch the reset existed to drop.
    func testResetDuringConstructionDiscardsTheStaleManager() {
        OSFeatureFlagsStore.shared.applyRemoteFlags([FeatureFlag.sdkCustomLogging.key], metadata: nil)
        OSFeatureManager.reset()

        var alreadyReset = false
        OSFeatureManager.didConstructForTesting = {
            guard !alreadyReset else {
                return
            }
            alreadyReset = true
            OSFeatureManager.resetAndClearCachedFlags()
        }
        defer { OSFeatureManager.didConstructForTesting = nil }

        let manager = OSFeatureManager.shared

        XCTAssertTrue(alreadyReset, "the race hook must have fired")
        XCTAssertFalse(
            manager.isEnabled(featureKey: FeatureFlag.sdkCustomLogging.key),
            "the published manager must not carry a latch read before the reset"
        )
    }
}

final class OSFeatureFlagsBackendServiceTests: XCTestCase {
    func test403ForbiddenReturnsUnavailableAndIsClientError() throws {
        let outcome = try fetch(statusCode: 403, body: #"{"errors":["Forbidden"]}"#)
        XCTAssertTrue(outcome.isUnavailable)
        XCTAssertTrue(outcome.reason == RemoteFeatureFlagsUnavailableReason.nonSuccessHttp)
        XCTAssertTrue(outcome.isClientError)
    }

    func test500ServerErrorIsNotClientError() throws {
        let outcome = try fetch(statusCode: 500, body: "boom")
        XCTAssertTrue(outcome.isUnavailable)
        XCTAssertTrue(outcome.reason == RemoteFeatureFlagsUnavailableReason.nonSuccessHttp)
        XCTAssertFalse(outcome.isClientError)
    }

    func test200WithValidEmptyFeaturesArrayIsSuccess() throws {
        let outcome = try fetch(statusCode: 200, body: #"{"features":[]}"#)
        XCTAssertTrue(outcome.isSuccess)
        XCTAssertNotNil(outcome.result)
        XCTAssertEqual(stringArray(outcome.result?.enabledKeys), [])
    }

    func test200WithNonContractJSONIsInvalidJson() throws {
        let outcome = try fetch(statusCode: 200, body: #"{"errors":["Forbidden"]}"#)
        XCTAssertTrue(outcome.isUnavailable)
        XCTAssertTrue(outcome.reason == RemoteFeatureFlagsUnavailableReason.invalidJson)
    }

    func test200WithHTMLBodyIsInvalidJsonAndDoesNotThrow() throws {
        let html = "<html><head><title>Burp</title></head><body>intercepted</body></html>"
        let outcome = try fetch(statusCode: 200, body: html)
        XCTAssertTrue(outcome.isUnavailable)
        XCTAssertTrue(outcome.reason == RemoteFeatureFlagsUnavailableReason.invalidJson)
    }

    func test200WithEmptyBodyIsUnavailable() throws {
        let outcome = try fetch(statusCode: 200, body: nil)
        XCTAssertTrue(outcome.isUnavailable)
        XCTAssertTrue(outcome.reason == RemoteFeatureFlagsUnavailableReason.emptyBody)
    }

    func testPathShapingAppIdReturnsInvalidAppIdWithoutHTTP() throws {
        var didGet = false
        let http = StubFeatureFlagsHttp { _, completion in
            didGet = true
            completion(FeatureFlagsHttpResponse(statusCode: 200, body: #"{"features":[]}"#), nil)
        }
        let outcome = try fetch(appId: "app/../other", http: http)
        XCTAssertTrue(outcome.isUnavailable)
        XCTAssertTrue(outcome.reason == RemoteFeatureFlagsUnavailableReason.invalidAppId)
        XCTAssertFalse(didGet)
    }

    func testSdkVersionFromONESIGNAL_VERSIONMatchesTurbineLabelRules() {
        XCTAssertTrue(TurbineSdkFeatureFlagsPath.shared.isValidFeaturesSdkVersionLabel(label: ONESIGNAL_VERSION))
    }

    private func fetch(
        statusCode: Int32 = 200,
        body: String? = nil,
        appId: String = "appId",
        http: IFeatureFlagsHttp? = nil
    ) throws -> RemoteFeatureFlagsFetchOutcome {
        let transport = http ?? StubFeatureFlagsHttp { _, completion in
            completion(FeatureFlagsHttpResponse(statusCode: statusCode, body: body), nil)
        }
        let service = OSFeatureFlagsBackendService(http: transport, sdkVersionProvider: { "050506" })
        let done = expectation(description: "fetch")
        var outcome: RemoteFeatureFlagsFetchOutcome?
        service.fetchRemoteFeatureFlags(appId: appId) {
            outcome = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 2)
        return try XCTUnwrap(outcome)
    }

    private func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
        }
        if let array = value as? NSArray {
            return array.compactMap { $0 as? String }
        }
        return []
    }
}

final class StubFeatureFlagsHttp: IFeatureFlagsHttp {
    let onGet: (
        String,
        @escaping (FeatureFlagsHttpResponse?, Error?) -> Void
    ) -> Void

    init(onGet: @escaping (String, @escaping (FeatureFlagsHttpResponse?, Error?) -> Void) -> Void) {
        self.onGet = onGet
    }

    func get(relativePath: String, completionHandler: @escaping (FeatureFlagsHttpResponse?, Error?) -> Void) {
        onGet(relativePath, completionHandler)
    }
}
