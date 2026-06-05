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
}
