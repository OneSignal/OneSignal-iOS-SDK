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

import XCTest
@testable import OneSignalLiveActivities

final class LiveActivitiesManagerTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    // MARK: - Helper Methods

    private func createTrackingURL(
        from clientURL: URL?,
        activityId: String = "test-activity-id",
        activityType: String = "TestActivityType",
        notificationId: String? = "test-notification-id"
    ) -> URL? {
        return LiveActivityTrackingUtils.buildTrackingURL(
            originalURL: clientURL,
            activityId: activityId,
            activityType: activityType,
            notificationId: notificationId
        )
    }

    // MARK: - Tests

    func testTrackClickAndReturnOriginal_nonTrackingURL_returnsOriginalURL() throws {
        /* Setup */
        let originalURL = URL(string: "https://example.com/path")!

        /* Then */
        XCTAssertEqual(OneSignalLiveActivitiesManagerImpl.trackClickAndReturnOriginal(originalURL), originalURL)
    }

    func testTrackClickAndReturnOriginal_validTrackingURLWithAllParameters_tracksClickAndReturnsRedirectURL() throws {
        /* Setup */
        let originalURL = URL(string: "https://example.com/destination")!
        let trackingURL = createTrackingURL(from: originalURL)
        XCTAssertNotNil(trackingURL)

        /* Verify tracking URL structure */
        let trackingURLString = trackingURL!.absoluteString
        XCTAssertTrue(trackingURLString.starts(with: "onesignal-liveactivity://track/click?"))
        XCTAssertTrue(trackingURLString.contains("clickId="))
        XCTAssertTrue(trackingURLString.contains("activityId=test-activity-id"))
        XCTAssertTrue(trackingURLString.contains("activityType=TestActivityType"))
        XCTAssertTrue(trackingURLString.contains("notificationId=test-notification-id"))
        XCTAssertTrue(trackingURLString.contains("redirect=https://example.com/destination"))

        XCTAssertEqual(trackingURL!.scheme, "onesignal-liveactivity")
        XCTAssertEqual(trackingURL!.host, "track")
        XCTAssertEqual(trackingURL!.path, "/click")

        let components = URLComponents(url: trackingURL!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertNotNil(queryItems.first(where: { $0.name == "clickId" })?.value)
        XCTAssertEqual(queryItems.first(where: { $0.name == "activityId" })?.value, "test-activity-id")
        XCTAssertEqual(queryItems.first(where: { $0.name == "activityType" })?.value, "TestActivityType")
        XCTAssertEqual(queryItems.first(where: { $0.name == "notificationId" })?.value, "test-notification-id")
        XCTAssertEqual(queryItems.first(where: { $0.name == "redirect" })?.value, "https://example.com/destination")

        /* Then */
        XCTAssertEqual(OneSignalLiveActivitiesManagerImpl.trackClickAndReturnOriginal(trackingURL!), originalURL)
    }

    func testTrackClickAndReturnOriginal_validTrackingURLWithoutNotificationId_tracksClickAndReturnsRedirectURL() throws {
        /* Setup */
        let clientURL = URL(string: "https://example.com/destination")!
        let trackingURL = createTrackingURL(from: clientURL, notificationId: nil)
        XCTAssertNotNil(trackingURL)

        /* Then */
        XCTAssertEqual(OneSignalLiveActivitiesManagerImpl.trackClickAndReturnOriginal(trackingURL!), clientURL)
    }

    func testTrackClickAndReturnOriginal_trackingURLMissingRequiredParameters_returnsRedirectURLWithoutTracking() throws {
        /* Setup */
        let redirectURL = "https://example.com/destination"
        let trackingURLString = "onesignal-liveactivity://track/click?activityId=test-activity-id&redirect=\(redirectURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"
        let trackingURL = URL(string: trackingURLString)!

        /* When */
        let result = OneSignalLiveActivitiesManagerImpl.trackClickAndReturnOriginal(trackingURL)

        /* Then */
        XCTAssertEqual(result!.absoluteString, redirectURL)
    }

    func testTrackClickAndReturnOriginal_trackingURLWithNoRedirectParameter_returnsNil() throws {
        /* Setup */
        let trackingURL = createTrackingURL(from: nil)
        XCTAssertNotNil(trackingURL)

        /* Then */
        XCTAssertNil(OneSignalLiveActivitiesManagerImpl.trackClickAndReturnOriginal(trackingURL!))
    }

    func testTrackClickAndReturnOriginal_malformedTrackingURL_returnsOriginalURL() throws {
        /* Setup */
        let malformedURL = URL(string: "liveactivity://foo/wrong-path?clickId=test-click-id")!

        /* Then */
        XCTAssertEqual(OneSignalLiveActivitiesManagerImpl.trackClickAndReturnOriginal(malformedURL), malformedURL)
    }

    func testTrackClickAndReturnOriginal_complexURLWithQueryParamsAndFragment_preservesAllComponents() throws {
        /* Setup */
        let clientURL = URL(string: "https://example.com/page?param1=value1&param2=value2#section")!
        let trackingURL = createTrackingURL(from: clientURL)
        XCTAssertNotNil(trackingURL)

        /* When */
        let result = OneSignalLiveActivitiesManagerImpl.trackClickAndReturnOriginal(trackingURL!)

        /* Then */
        XCTAssertEqual(result!, clientURL)
        XCTAssertEqual(result!.scheme, "https")
        XCTAssertEqual(result!.host, "example.com")
        XCTAssertEqual(result!.path, "/page")
        XCTAssertEqual(result!.query, "param1=value1&param2=value2")
        XCTAssertEqual(result!.fragment, "section")
    }

    // MARK: - Duplicate activities

    private final class FakeActivity: OSLiveActivityInstance {
        let id: String
        let oneSignalActivityId: String
        let pushTokenString: String?
        var isLive: Bool

        init(id: String, oneSignalActivityId: String, pushTokenString: String? = nil, isLive: Bool = true) {
            self.id = id
            self.oneSignalActivityId = oneSignalActivityId
            self.pushTokenString = pushTokenString
            self.isLive = isLive
        }
    }

    func testDuplicateGroups_groupsOnlyLiveActivitiesSharingAnActivityId() throws {
        let activities = [
            FakeActivity(id: "x1", oneSignalActivityId: "x"),
            FakeActivity(id: "y1", oneSignalActivityId: "y"),
            FakeActivity(id: "x2", oneSignalActivityId: "x"),
            FakeActivity(id: "y2", oneSignalActivityId: "y", isLive: false),
            FakeActivity(id: "z1", oneSignalActivityId: "z")
        ]

        let groups = OneSignalLiveActivitiesManagerImpl.duplicateGroups(activities)

        XCTAssertEqual(Array(groups.keys), ["x"])
        XCTAssertEqual(groups["x"]?.map(\.id), ["x1", "x2"])
    }

    func testActivityToKeep_prefersTheActivityWithTheCachedToken() throws {
        let group = [
            FakeActivity(id: "a1", oneSignalActivityId: "a", pushTokenString: "token-1"),
            FakeActivity(id: "a2", oneSignalActivityId: "a", pushTokenString: "token-2"),
            FakeActivity(id: "a3", oneSignalActivityId: "a", pushTokenString: "token-3")
        ]

        XCTAssertEqual(OneSignalLiveActivitiesManagerImpl.activityToKeep(group, cachedUpdateToken: "token-2")?.id, "a2")
    }

    func testActivityToKeep_withoutACachedMatch_keepsAnActivityWithAToken() throws {
        let group = [
            FakeActivity(id: "a1", oneSignalActivityId: "a"),
            FakeActivity(id: "a2", oneSignalActivityId: "a", pushTokenString: "token-2")
        ]

        XCTAssertEqual(OneSignalLiveActivitiesManagerImpl.activityToKeep(group, cachedUpdateToken: "token-other")?.id, "a2")
        XCTAssertEqual(OneSignalLiveActivitiesManagerImpl.activityToKeep(group, cachedUpdateToken: nil)?.id, "a2")
    }

    func testActivityToKeep_withoutTokens_keepsTheFirstActivity() throws {
        let group = [
            FakeActivity(id: "a1", oneSignalActivityId: "a"),
            FakeActivity(id: "a2", oneSignalActivityId: "a")
        ]

        XCTAssertEqual(OneSignalLiveActivitiesManagerImpl.activityToKeep(group, cachedUpdateToken: nil)?.id, "a1")
    }

    func testEndDuplicates_endsAllButOneActivityPerActivityId() async throws {
        let activities = [
            FakeActivity(id: "x1", oneSignalActivityId: "x", pushTokenString: "token-x1"),
            FakeActivity(id: "x2", oneSignalActivityId: "x", pushTokenString: "token-x2"),
            FakeActivity(id: "x3", oneSignalActivityId: "x", pushTokenString: "token-x3"),
            FakeActivity(id: "y1", oneSignalActivityId: "y"),
            FakeActivity(id: "y2", oneSignalActivityId: "y", pushTokenString: "token-y2")
        ]
        let cachedTokens = ["x": "token-x3"]
        var ended = [String]()

        let kept = await OneSignalLiveActivitiesManagerImpl.endDuplicates(
            OneSignalLiveActivitiesManagerImpl.duplicateGroups(activities),
            cachedUpdateToken: { cachedTokens[$0] },
            end: { ended.append($0.id) }
        )

        XCTAssertEqual(Set(kept.map(\.id)), ["x3", "y2"])
        XCTAssertEqual(Set(ended), ["x1", "x2", "y1"])
    }

    func testEndDuplicates_whenTheCachedTokenActivityHasEnded_keepsTheLiveOne() async throws {
        let endedActivity = FakeActivity(id: "x1", oneSignalActivityId: "x", pushTokenString: "token-x1", isLive: false)
        let liveActivity = FakeActivity(id: "x2", oneSignalActivityId: "x", pushTokenString: "token-x2")
        var ended = [String]()

        let kept = await OneSignalLiveActivitiesManagerImpl.endDuplicates(
            ["x": [endedActivity, liveActivity]],
            cachedUpdateToken: { _ in "token-x1" },
            end: { ended.append($0.id) }
        )

        XCTAssertEqual(kept.map(\.id), ["x2"])
        XCTAssertEqual(ended, [])
    }

    func testEndDuplicates_whenTheKeeperEndsDuringTheAwaits_returnsNothing() async throws {
        let keeper = FakeActivity(id: "x1", oneSignalActivityId: "x", pushTokenString: "token-x1")
        let duplicate = FakeActivity(id: "x2", oneSignalActivityId: "x", pushTokenString: "token-x2")

        let kept = await OneSignalLiveActivitiesManagerImpl.endDuplicates(
            ["x": [keeper, duplicate]],
            cachedUpdateToken: { _ in "token-x1" },
            // A new activity with the same activityId ends the keeper while this call waits.
            end: { _ in keeper.isLive = false }
        )

        XCTAssertTrue(kept.isEmpty)
    }

    func testHasLiveDuplicate_whenAnotherLiveActivityHasTheSameActivityId_returnsTrue() throws {
        let dismissed = FakeActivity(id: "a1", oneSignalActivityId: "a", isLive: false)
        let activities = [dismissed, FakeActivity(id: "a2", oneSignalActivityId: "a")]

        XCTAssertTrue(OneSignalLiveActivitiesManagerImpl.hasLiveDuplicate(dismissed, in: activities))
    }

    func testHasLiveDuplicate_withoutAnotherLiveActivityForTheActivityId_returnsFalse() throws {
        let dismissed = FakeActivity(id: "a1", oneSignalActivityId: "a", isLive: false)
        let activities = [
            dismissed,
            FakeActivity(id: "a2", oneSignalActivityId: "a", isLive: false),
            FakeActivity(id: "b1", oneSignalActivityId: "b")
        ]

        XCTAssertFalse(OneSignalLiveActivitiesManagerImpl.hasLiveDuplicate(dismissed, in: activities))
        XCTAssertFalse(OneSignalLiveActivitiesManagerImpl.hasLiveDuplicate(dismissed, in: []))
    }

    func testHasLiveDuplicate_forALiveActivityWithoutAnotherForItsActivityId_returnsFalse() throws {
        let live = FakeActivity(id: "a1", oneSignalActivityId: "a")
        let activities = [live, FakeActivity(id: "b1", oneSignalActivityId: "b")]

        XCTAssertFalse(OneSignalLiveActivitiesManagerImpl.hasLiveDuplicate(live, in: activities))
    }
}
