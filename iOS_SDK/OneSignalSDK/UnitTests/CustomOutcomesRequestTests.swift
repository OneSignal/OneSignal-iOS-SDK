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
import OneSignalOSCore
import OneSignalOutcomes

/// The three v1 custom outcome requests, and the controller path that fills their user ids.
class CustomOutcomesRequestTests: XCTestCase {

    private typealias Builder = (OSOutcomeEvent, String, NSNumber, String?, String?) -> OSRequestSendOutcomesV1ToServer

    private let builders: [(name: String, build: Builder)] = [
        ("direct", OSRequestSendOutcomesV1ToServer.direct(withOutcome:appId:deviceType:pushSubscriptionId:onesignalId:)),
        ("indirect", OSRequestSendOutcomesV1ToServer.indirect(withOutcome:appId:deviceType:pushSubscriptionId:onesignalId:)),
        ("unattributed", OSRequestSendOutcomesV1ToServer.unattributed(withOutcome:appId:deviceType:pushSubscriptionId:onesignalId:))
    ]

    private func outcome(_ session: OSInfluenceType) -> OSOutcomeEvent {
        return OSOutcomeEvent(session: session, notificationIds: ["notif-1"], name: "purchase", timestamp: 0, weight: 2)
    }

    private func params(_ request: OneSignalRequest) -> [String: Any] {
        return request.parameters as! [String: Any]
    }

    func testBuildersCarryBothIdsWhenPresent() {
        for builder in builders {
            let request = builder.build(outcome(.DIRECT), "test-app-id", 0, "test-push-sub-id", "test-onesignal-id")
            let params = params(request)

            XCTAssertEqual(request.path, "outcomes/measure", builder.name)
            XCTAssertEqual(request.method, POST, builder.name)
            XCTAssertEqual(params["onesignal_id"] as? String, "test-onesignal-id", builder.name)
            let subscription = params["subscription"] as? [String: Any]
            XCTAssertEqual(subscription?["id"] as? String, "test-push-sub-id", builder.name)
            XCTAssertEqual(subscription?["type"] as? String, "iOSPush", builder.name)
            XCTAssertEqual(params["app_id"] as? String, "test-app-id", builder.name)
            XCTAssertEqual(params["device_type"] as? Int, 0, builder.name)
            XCTAssertEqual(params["id"] as? String, "purchase", builder.name)
            XCTAssertEqual((params["weight"] as? NSNumber)?.doubleValue, 2, builder.name)
        }
    }

    func testBuildersOmitBothIdsWhenNil() {
        for builder in builders {
            let params = params(builder.build(outcome(.DIRECT), "test-app-id", 0, nil, nil))

            XCTAssertNil(params["onesignal_id"], builder.name)
            XCTAssertNil(params["subscription"], builder.name)
            XCTAssertEqual(params["app_id"] as? String, "test-app-id", builder.name)
            XCTAssertEqual(params["id"] as? String, "purchase", builder.name)
        }
    }

    func testBuildersOmitBothIdsWhenEmpty() {
        for builder in builders {
            let params = params(builder.build(outcome(.DIRECT), "test-app-id", 0, "", ""))

            XCTAssertNil(params["onesignal_id"], builder.name)
            XCTAssertNil(params["subscription"], builder.name)
        }
    }

    func testBuildersCarryEachIdOnItsOwn() {
        for builder in builders {
            let onlySubscription = params(builder.build(outcome(.DIRECT), "test-app-id", 0, "test-push-sub-id", nil))
            XCTAssertNil(onlySubscription["onesignal_id"], builder.name)
            XCTAssertEqual((onlySubscription["subscription"] as? [String: Any])?["id"] as? String, "test-push-sub-id", builder.name)

            let onlyOnesignalId = params(builder.build(outcome(.DIRECT), "test-app-id", 0, nil, "test-onesignal-id"))
            XCTAssertEqual(onlyOnesignalId["onesignal_id"] as? String, "test-onesignal-id", builder.name)
            XCTAssertNil(onlyOnesignalId["subscription"], builder.name)
        }
    }

    func testDirectAndIndirectKeepTheirAttributionFields() {
        let direct = params(OSRequestSendOutcomesV1ToServer.direct(
            withOutcome: outcome(.DIRECT), appId: "test-app-id", deviceType: 0,
            pushSubscriptionId: "test-push-sub-id", onesignalId: "test-onesignal-id"
        ))
        XCTAssertEqual(direct["direct"] as? Bool, true)
        XCTAssertEqual(direct["notification_ids"] as? [String], ["notif-1"])

        let indirect = params(OSRequestSendOutcomesV1ToServer.indirect(
            withOutcome: outcome(.INDIRECT), appId: "test-app-id", deviceType: 0,
            pushSubscriptionId: "test-push-sub-id", onesignalId: "test-onesignal-id"
        ))
        XCTAssertEqual(indirect["direct"] as? Bool, false)
        XCTAssertEqual(indirect["notification_ids"] as? [String], ["notif-1"])

        let unattributed = params(OSRequestSendOutcomesV1ToServer.unattributed(
            withOutcome: outcome(.UNATTRIBUTED), appId: "test-app-id", deviceType: 0,
            pushSubscriptionId: "test-push-sub-id", onesignalId: "test-onesignal-id"
        ))
        XCTAssertNil(unattributed["direct"])
        XCTAssertNil(unattributed["notification_ids"])
    }
}

/// Hands the controller's one request back to the test and answers it with an empty body.
private class RecordingClient: NSObject, IOneSignalClient {
    var requests: [OneSignalRequest] = []

    func execute(
        _ request: OneSignalRequest,
        onSuccess successBlock: @escaping OSResultSuccessBlock,
        onFailure failureBlock: @escaping OSClientFailureBlock
    ) {
        requests.append(request)
        successBlock([:])
    }
}

/// `addOutcome` through the real controller, repository and builder, with the ids supplied by the providers.
class CustomOutcomesControllerTests: XCTestCase {

    private var client = RecordingClient()
    private var previousClient: IOneSignalClient?
    private var controller: OneSignalOutcomeEventsController!

    override func setUp() {
        super.setUp()
        let defaults = OneSignalUserDefaults.initShared()
        defaults.saveBool(forKey: OSUD_UNATTRIBUTED_SESSION_ENABLED, withValue: true)
        defaults.removeValue(forKey: OSUD_OUTCOMES_V2)
        defaults.removeValue(forKey: OSUD_CACHED_NOTIFICATION_INFLUENCE)
        defaults.removeValue(forKey: OSUD_CACHED_IAM_INFLUENCE)
        OSSessionManager.resetSharedSessionManager()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        previousClient = OneSignalCoreImpl.sharedClient()
        client = RecordingClient()
        OneSignalCoreImpl.setSharedClient(client)

        controller = OneSignalOutcomeEventsController(
            sessionManager: OSSessionManager.shared(),
            outcomeEventsFactory: OSOutcomeEventsFactory(cache: OSOutcomeEventsCache.shared())
        )
    }

    override func tearDown() {
        if let previousClient = previousClient {
            OneSignalCoreImpl.setSharedClient(previousClient)
        }
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_UNATTRIBUTED_SESSION_ENABLED)
        OSSessionManager.resetSharedSessionManager()
        super.tearDown()
    }

    private func sentParams() -> [String: Any]? {
        XCTAssertEqual(client.requests.count, 1)
        return client.requests.first?.parameters as? [String: Any]
    }

    func testCustomOutcomeCarriesTheIdsTheProvidersReturn() {
        controller.pushSubscriptionIdProvider = { "test-push-sub-id" }
        controller.onesignalIdProvider = { "test-onesignal-id" }

        controller.addOutcome("purchase")

        let params = sentParams()
        XCTAssertEqual(params?["id"] as? String, "purchase")
        XCTAssertEqual(params?["app_id"] as? String, "test-app-id")
        XCTAssertEqual(params?["onesignal_id"] as? String, "test-onesignal-id")
        XCTAssertEqual((params?["subscription"] as? [String: Any])?["id"] as? String, "test-push-sub-id")
        XCTAssertEqual((params?["subscription"] as? [String: Any])?["type"] as? String, "iOSPush")
    }

    func testCustomOutcomeStillSendsWhenTheProvidersReturnNil() {
        controller.pushSubscriptionIdProvider = { nil }
        controller.onesignalIdProvider = { nil }

        controller.addOutcome("purchase")

        let params = sentParams()
        XCTAssertEqual(params?["id"] as? String, "purchase")
        XCTAssertNil(params?["onesignal_id"])
        XCTAssertNil(params?["subscription"])
    }

    func testCustomOutcomeStillSendsWithoutProviders() {
        controller.addOutcome("purchase")

        let params = sentParams()
        XCTAssertEqual(params?["id"] as? String, "purchase")
        XCTAssertNil(params?["onesignal_id"])
        XCTAssertNil(params?["subscription"])
    }
}
