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

import XCTest
import OneSignalCore
import OneSignalOutcomes

class ChannelTrackerAttributionWindowTests: XCTestCase {

    private var repository: OSInfluenceDataRepository!
    private var trackerFactory: OSTrackerFactory!

    override func setUp() {
        super.setUp()
        // +[NSDate date] is swizzled in this test bundle, so the SDK clock must be set explicitly
        NSDateOverrider.reset()
        NSDateOverrider.advanceSystemTime(by: 1_000_000)
        repository = OSInfluenceDataRepository()
        trackerFactory = OSTrackerFactory(repository: repository)
        repository.saveNotifications(nil)
        repository.saveIAMs(nil)
    }

    override func tearDown() {
        repository.saveNotifications(nil)
        repository.saveIAMs(nil)
        for key in [
            OSUD_INDIRECT_SESSION_ENABLED,
            OSUD_NOTIFICATION_LIMIT,
            OSUD_IAM_LIMIT,
            OSUD_NOTIFICATION_ATTRIBUTION_WINDOW,
            OSUD_IAM_ATTRIBUTION_WINDOW
        ] {
            OneSignalUserDefaults.initShared().removeValue(forKey: key)
        }
        super.tearDown()
    }

    private func saveAttributionWindow(minutes: Int) {
        let attribution: [String: Any] = ["minutes_since_displayed": minutes, "limit": 10]
        trackerFactory.saveInfluenceParams([
            "outcomes": [
                "indirect": [
                    "enabled": true,
                    "notification_attribution": attribution,
                    "in_app_message_attribution": attribution
                ]
            ]
        ])
    }

    private func influence(_ id: String, channel: String, secondsAgo: Double) -> OSIndirectInfluence {
        let timestamp = NSDateOverrider.globalTimeOffset() - secondsAgo
        return OSIndirectInfluence(paramsInfluenceId: id, forChannel: channel, timestamp: timestamp)
    }

    func testNotificationWithinWindowMinutesIsIndirect() {
        saveAttributionWindow(minutes: 60)
        repository.saveNotifications([influence("notif-1", channel: "notification_id", secondsAgo: 5 * 60)])

        let ids = trackerFactory.notificationChannelTracker().lastReceivedIds() as? [String]

        XCTAssertEqual(ids, ["notif-1"])
    }

    func testNotificationOutsideWindowIsExcluded() {
        saveAttributionWindow(minutes: 60)
        repository.saveNotifications([
            influence("notif-old", channel: "notification_id", secondsAgo: 61 * 60),
            influence("notif-new", channel: "notification_id", secondsAgo: 59 * 60)
        ])

        let ids = trackerFactory.notificationChannelTracker().lastReceivedIds() as? [String]

        XCTAssertEqual(ids, ["notif-new"])
    }

    func testNotificationAtWindowBoundaryIsIndirect() {
        saveAttributionWindow(minutes: 60)
        repository.saveNotifications([influence("notif-edge", channel: "notification_id", secondsAgo: 60 * 60)])

        let ids = trackerFactory.notificationChannelTracker().lastReceivedIds() as? [String]

        XCTAssertEqual(ids, ["notif-edge"])
    }

    func testIAMWithinWindowMinutesIsIndirect() {
        saveAttributionWindow(minutes: 60)
        repository.saveIAMs([influence("iam-1", channel: "iam_id", secondsAgo: 5 * 60)])

        let ids = trackerFactory.iamChannelTracker().lastReceivedIds() as? [String]

        XCTAssertEqual(ids, ["iam-1"])
    }
}
