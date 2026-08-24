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
        store = OSFeatureFlagsStore()
    }

    override func tearDown() {
        OSFeatureManager.localFeatureOverrides = []
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

final class OSFeatureFlagsRefreshServiceTests: XCTestCase {
    private var store: OSFeatureFlagsStore!

    override func setUp() {
        super.setUp()
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAG_METADATA)
        store = OSFeatureFlagsStore()
    }

    override func tearDown() {
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAGS)
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_REMOTE_FEATURE_FLAG_METADATA)
        super.tearDown()
    }

    private func makeService(
        http: IFeatureFlagsHttp,
        queue: ControllableDispatchQueue,
        notificationCenter: NotificationCenter = NotificationCenter(),
        usesScenes: @escaping () -> Bool = { false },
        appIdProvider: @escaping () -> String? = { "app-id-1" },
        isInForegroundProvider: (() -> Bool)? = { true }
    ) -> OSFeatureFlagsRefreshService {
        OSFeatureFlagsRefreshService(
            backend: OSFeatureFlagsBackendService(http: http, sdkVersionProvider: { "050506" }),
            store: store,
            ioQueue: queue,
            notificationCenter: notificationCenter,
            usesScenes: usesScenes,
            appIdProvider: appIdProvider,
            isInForegroundProvider: isInForegroundProvider,
            refreshInterval: 10_000
        )
    }

    private func countingHttp(_ counter: @escaping () -> Void) -> StubFeatureFlagsHttp {
        StubFeatureFlagsHttp { _, completion in
            counter()
            completion(FeatureFlagsHttpResponse(statusCode: 200, body: #"{"features":[]}"#), nil)
        }
    }

    func testSuccessfulFetchPersistsKeysOnTheStore() {
        let http = StubFeatureFlagsHttp { _, completion in
            completion(
                FeatureFlagsHttpResponse(
                    statusCode: 200,
                    body: #"{"features":["sdk_identity_verification"]}"#
                ),
                nil
            )
        }
        let service = makeService(http: http, queue: ControllableDispatchQueue())

        service.startPolling()

        XCTAssertEqual(store.sdkRemoteFeatureFlags, [FeatureFlag.sdkIdentityVerification.key])
    }

    func testUnavailableFetchLeavesCachedFlagsInPlace() {
        store.applyRemoteFlags(["sdk_identity_verification"], metadata: nil)
        let http = StubFeatureFlagsHttp { _, completion in
            completion(FeatureFlagsHttpResponse(statusCode: 500, body: "boom"), nil)
        }
        let service = makeService(http: http, queue: ControllableDispatchQueue())

        service.startPolling()

        XCTAssertEqual(store.sdkRemoteFeatureFlags, ["sdk_identity_verification"])
    }

    func testSameAppIdRefocusDoesNotDoubleFetch() {
        var fetches = 0
        let service = makeService(http: countingHttp { fetches += 1 }, queue: ControllableDispatchQueue())

        service.startPolling()
        service.onFocus()

        XCTAssertEqual(fetches, 1)
    }

    func testAppIdChangeRefetchesWithTheFullTurbinePath() {
        var appId = "app-id-1"
        var fetched: [String] = []
        let http = StubFeatureFlagsHttp { path, completion in
            fetched.append(path)
            completion(FeatureFlagsHttpResponse(statusCode: 200, body: #"{"features":[]}"#), nil)
        }
        let service = makeService(http: http, queue: ControllableDispatchQueue(), appIdProvider: { appId })

        service.startPolling()
        service.onUnfocused()
        appId = "app-id-2"
        service.onFocus()

        // Asserting the whole path, not just the app id: the platform segment is the
        // cross-platform contract this wiring exists to keep stable.
        XCTAssertEqual(fetched, [
            "apps/app-id-1/sdk/features/ios/050506",
            "apps/app-id-2/sdk/features/ios/050506"
        ])
    }

    func testPollReschedulesItselfAfterTheRefreshInterval() {
        var fetches = 0
        let queue = ControllableDispatchQueue()
        let service = makeService(http: countingHttp { fetches += 1 }, queue: queue)

        service.startPolling()
        XCTAssertEqual(fetches, 1)

        queue.runPendingDeferredWork()

        XCTAssertEqual(fetches, 2)
    }

    func testUnfocusCancelsTheScheduledPoll() {
        var fetches = 0
        let queue = ControllableDispatchQueue()
        let service = makeService(http: countingHttp { fetches += 1 }, queue: queue)

        service.startPolling()
        XCTAssertEqual(fetches, 1)

        service.onUnfocused()
        queue.runPendingDeferredWork()

        XCTAssertEqual(fetches, 1, "the queued poll belongs to a cancelled generation")
    }

    func testDoesNotPollWhileBackgrounded() {
        var fetches = 0
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: ControllableDispatchQueue(),
            isInForegroundProvider: { false }
        )

        service.startPolling()

        XCTAssertEqual(fetches, 0)
    }

    func testDoesNotPollUntilTheHostReportsForeground() {
        var fetches = 0
        // No override, so the service uses its own tracked state, which starts false.
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: ControllableDispatchQueue(),
            isInForegroundProvider: nil
        )

        service.startPolling()
        XCTAssertEqual(fetches, 0, "a background launch must not fetch")

        service.setForeground(true)
        service.startPolling()

        XCTAssertEqual(fetches, 1)
    }

    func testMomentarilyEmptyAppIdDoesNotWedgePolling() {
        // The app id is readable when polling is armed but empty by the time the poll
        // runs. Without releasing the dedupe key, no later focus could ever restart.
        var appIdReads = ["app-id-1", ""]
        var fetches = 0
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: ControllableDispatchQueue(),
            appIdProvider: { appIdReads.isEmpty ? "app-id-1" : appIdReads.removeFirst() }
        )

        service.startPolling()
        XCTAssertEqual(fetches, 0)

        service.onFocus()

        XCTAssertEqual(fetches, 1, "a later focus must be able to restart polling")
    }

    func testBackgroundingOneOfTwoScenesKeepsPolling() {
        var fetches = 0
        let center = NotificationCenter()
        let queue = ControllableDispatchQueue()
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: queue,
            notificationCenter: center,
            usesScenes: { true },
            isInForegroundProvider: nil
        )
        service.startPolling()

        center.post(name: Notification.Name("UISceneDidActivateNotification"), object: nil)
        center.post(name: Notification.Name("UISceneDidActivateNotification"), object: nil)
        XCTAssertEqual(fetches, 1, "the second scene is deduped against the same app id")

        center.post(name: Notification.Name("UISceneDidEnterBackgroundNotification"), object: nil)
        queue.runPendingDeferredWork()

        XCTAssertEqual(fetches, 2, "one scene is still foregrounded")
    }

    func testBackgroundingTheLastSceneStopsPolling() {
        var fetches = 0
        let center = NotificationCenter()
        let queue = ControllableDispatchQueue()
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: queue,
            notificationCenter: center,
            usesScenes: { true },
            isInForegroundProvider: nil
        )
        service.startPolling()

        center.post(name: Notification.Name("UISceneDidActivateNotification"), object: nil)
        XCTAssertEqual(fetches, 1)

        center.post(name: Notification.Name("UISceneDidEnterBackgroundNotification"), object: nil)
        queue.runPendingDeferredWork()

        XCTAssertEqual(fetches, 1)
    }
}

private final class StubFeatureFlagsHttp: IFeatureFlagsHttp {
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

/// Runs immediate work inline and holds deferred work until a test releases it, so the
/// self-rescheduling poll loop can be stepped without waiting out the refresh interval.
private final class ControllableDispatchQueue: OSDispatchQueue {
    private var deferredWork: [() -> Void] = []

    func async(execute work: @escaping @convention(block) () -> Void) {
        work()
    }

    func asyncAfterTime(deadline: DispatchTime, execute work: @escaping @Sendable @convention(block) () -> Void) {
        deferredWork.append(work)
    }

    /// Runs work queued so far. Work scheduled *by* that work is left for the next call,
    /// so a single step cannot recurse forever.
    func runPendingDeferredWork() {
        let scheduled = deferredWork
        deferredWork.removeAll()
        scheduled.forEach { $0() }
    }
}
