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
import UIKit
import XCTest

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
        appIdProvider: @escaping () -> String? = { "app-id-1" },
        isInForegroundProvider: (() -> Bool)? = { true }
    ) -> OSFeatureFlagsRefreshService {
        OSFeatureFlagsRefreshService(
            backend: OSFeatureFlagsBackendService(http: http, sdkVersionProvider: { "050506" }),
            store: store,
            ioQueue: queue,
            notificationCenter: notificationCenter,
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

    func testBecomingActiveStartsPollingAndBackgroundingStopsIt() {
        var fetches = 0
        let center = NotificationCenter()
        let queue = ControllableDispatchQueue()
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: queue,
            notificationCenter: center,
            isInForegroundProvider: nil
        )
        service.startPolling()
        XCTAssertEqual(fetches, 0, "a background launch must not fetch")

        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(fetches, 1)

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        queue.runPendingDeferredWork()

        XCTAssertEqual(fetches, 1, "backgrounding cancels the scheduled poll")
    }

    /// UIKit can post `didBecomeActive` repeatedly without an intervening background
    /// event. A counter-based approach treated each as another live scene and then needed
    /// as many background events to stop, so polling outlived the foreground.
    func testRepeatedActivationStillStopsOnASingleBackgroundEvent() {
        var fetches = 0
        let center = NotificationCenter()
        let queue = ControllableDispatchQueue()
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: queue,
            notificationCenter: center,
            isInForegroundProvider: nil
        )
        service.startPolling()

        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(fetches, 1, "redundant activations dedupe against the same app id")

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        queue.runPendingDeferredWork()

        XCTAssertEqual(fetches, 1, "one background event must undo any number of activations")
    }

    func testResetStopsAnAlreadyQueuedStart() {
        var fetches = 0
        let queue = ControllableDispatchQueue(deferImmediateWork: true)
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: queue,
            isInForegroundProvider: { true }
        )

        // `startPolling` is queued but has not run; the reset lands first, exactly as it
        // would when `handleAppIdChange` fires while startup work is still in flight.
        service.startPolling()
        service.stopPolling()
        queue.runPendingDeferredWork()

        XCTAssertEqual(fetches, 0, "a dropped instance must not resurrect its poll loop")
    }

    func testResetLeavesNoLifecycleObserversBehind() {
        var fetches = 0
        let center = ObserverTrackingCenter()
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: ControllableDispatchQueue(),
            notificationCenter: center,
            isInForegroundProvider: { true }
        )
        service.startPolling()
        XCTAssertEqual(center.liveObserverCount, 2)

        service.stopPolling()

        XCTAssertEqual(center.liveObserverCount, 0)
    }

    /// The reset lands between `addObserver` returning and the service recording the
    /// token. Nothing else holds the token at that instant, so if `observe` does not tear
    /// it down itself it outlives the service with no way left to reach it.
    func testObserverRegisteredDuringAResetIsTornDown() {
        var fetches = 0
        let center = ObserverTrackingCenter()
        let service = makeService(
            http: countingHttp { fetches += 1 },
            queue: ControllableDispatchQueue(),
            notificationCenter: center,
            isInForegroundProvider: { true }
        )
        center.onAddObserver = { [weak service] in
            service?.stopPolling()
        }

        service.startPolling()

        XCTAssertEqual(center.liveObserverCount, 0, "no observer may survive the reset that raced it")
        XCTAssertEqual(fetches, 0, "and the dropped instance must not start a loop")
    }
}

/// Counts observers that are currently registered, so a test can assert teardown rather
/// than infer it, and can inject a reset into the window inside `observe`.
private final class ObserverTrackingCenter: NotificationCenter {
    var onAddObserver: (() -> Void)?
    private(set) var liveObserverCount = 0

    override func addObserver(
        forName name: NSNotification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping (Notification) -> Void
    ) -> NSObjectProtocol {
        let token = super.addObserver(forName: name, object: obj, queue: queue, using: block)
        liveObserverCount += 1
        onAddObserver?()
        return token
    }

    override func removeObserver(_ observer: Any) {
        super.removeObserver(observer)
        liveObserverCount -= 1
    }
}

/// Runs immediate work inline and holds deferred work until a test releases it, so the
/// self-rescheduling poll loop can be stepped without waiting out the refresh interval.
///
/// `deferImmediateWork` also holds `async` work, which lets a test interleave a reset
/// ahead of already-queued startup work.
private final class ControllableDispatchQueue: OSDispatchQueue {
    private let deferImmediateWork: Bool
    private var deferredWork: [() -> Void] = []

    init(deferImmediateWork: Bool = false) {
        self.deferImmediateWork = deferImmediateWork
    }

    func async(execute work: @escaping @convention(block) () -> Void) {
        guard !deferImmediateWork else {
            deferredWork.append(work)
            return
        }
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
