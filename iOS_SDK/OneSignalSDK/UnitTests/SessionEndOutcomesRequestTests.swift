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
import OneSignalOutcomes

class SessionEndOutcomesRequestTests: XCTestCase {

    func testUnattributedInfluence() {
        let influenceParam = OSFocusInfluenceParam(
            paramsInfluenceIds: nil,
            influenceKey: "notification_ids",
            directInfluence: false,
            influenceDirectKey: "direct"
        )!

        let request = OSRequestSendSessionEndOutcomes.withActiveTime(
            120,
            appId: "test-app-id",
            pushSubscriptionId: "test-push-sub-id",
            onesignalId: "test-onesignal-id",
            influenceParams: [influenceParam]
        )

        XCTAssertEqual(request.path, "outcomes/measure")
        XCTAssertEqual(request.method, POST)

        let params = request.parameters as! [String: Any]
        XCTAssertEqual(params["app_id"] as? String, "test-app-id")
        XCTAssertEqual(params["id"] as? String, "os__session_duration")
        XCTAssertEqual(params["session_time"] as? Int, 120)
        XCTAssertEqual(params["onesignal_id"] as? String, "test-onesignal-id")

        let subscription = params["subscription"] as! [String: Any]
        XCTAssertEqual(subscription["id"] as? String, "test-push-sub-id")
        XCTAssertEqual(subscription["type"] as? String, "iOSPush")

        XCTAssertEqual(params["direct"] as? Bool, false)
        XCTAssertNil(params["notification_ids"])
    }

    func testAttributedDirectInfluence() {
        let notificationIds = ["notif-1", "notif-2"]
        let influenceParam = OSFocusInfluenceParam(
            paramsInfluenceIds: notificationIds,
            influenceKey: "notification_ids",
            directInfluence: true,
            influenceDirectKey: "direct"
        )!

        let request = OSRequestSendSessionEndOutcomes.withActiveTime(
            60,
            appId: "test-app-id",
            pushSubscriptionId: "test-push-sub-id",
            onesignalId: "test-onesignal-id",
            influenceParams: [influenceParam]
        )

        let params = request.parameters as! [String: Any]
        XCTAssertEqual(params["direct"] as? Bool, true)
        XCTAssertEqual(params["notification_ids"] as? [String], notificationIds)
        XCTAssertEqual(params["session_time"] as? Int, 60)
    }

    func testAttributedIndirectInfluence() {
        let notificationIds = ["notif-1", "notif-2", "notif-3"]
        let influenceParam = OSFocusInfluenceParam(
            paramsInfluenceIds: notificationIds,
            influenceKey: "notification_ids",
            directInfluence: false,
            influenceDirectKey: "direct"
        )!

        let request = OSRequestSendSessionEndOutcomes.withActiveTime(
            90,
            appId: "test-app-id",
            pushSubscriptionId: "test-push-sub-id",
            onesignalId: "test-onesignal-id",
            influenceParams: [influenceParam]
        )

        let params = request.parameters as! [String: Any]
        XCTAssertEqual(params["direct"] as? Bool, false)
        XCTAssertEqual(params["notification_ids"] as? [String], notificationIds)
    }
}
