import OneSignalCore
import OneSignalCoreMocks

public class MockUserRequests {

    public static func testIdentityPayload(onesignalId: String, externalId: String?) -> [String: [String: String]] {
        var aliases = [OS_ONESIGNAL_ID: onesignalId]
        aliases[OS_EXTERNAL_ID] = externalId // only add if non-nil
        return [
            "identity": aliases
        ]
    }

    public static func testPropertiesPayload(properties: [String: Any]) -> [String: Any] {
        return [
            "properties": properties
        ]
    }

    public static func testDefaultPushSubPayload(id: String) -> [String: Any] {
        return [
            "id": testPushSubId,
            "app_id": "test-app-id",
            "type": "iOSPush",
            "token": "",
            "enabled": true,
            "notification_types": 80,
            "session_time": 0,
            "session_count": 1,
            "sdk": "test_sdk_version",
            "device_model": "iPhone14,3",
            "device_os": "17.4.1",
            "rooted": false,
            "test_type": 1,
            "app_version": "1.4.4",
            "net_type": 0,
            "carrier": "",
            "web_auth": "",
            "web_p256": ""
        ]
    }

    public static func testDefaultFullCreateUserResponse(onesignalId: String, externalId: String?, subscriptionId: String?) -> [String: Any] {
        let identity = testIdentityPayload(onesignalId: onesignalId, externalId: externalId)
        let subscription = testDefaultPushSubPayload(id: testPushSubId)
        let properties = [
            "language": "en",
            "timezone_id": "America/Los_Angeles",
            "country": "US",
            "first_active": 1714860182,
            "last_active": 1714860182,
            "ip": "xxx.xx.xxx.xxx"
        ] as [String: Any]

        return [
            "subscriptions": [subscription],
            "identity": identity["identity"]!,
            "properties": properties
        ]
    }
}

// MARK: - Set Up Default Client Responses

extension MockUserRequests {
    private static func getOneSignalId(for externalId: String) -> String {
        switch externalId {
        case userA_EUID:
            return userA_OSID
        case userB_EUID:
            return userB_OSID
        default:
            return UUID().uuidString
        }
    }

    public static func setDefaultCreateAnonUserResponses(with client: MockOneSignalClient) {
        let anonCreateResponse = testDefaultFullCreateUserResponse(onesignalId: anonUserOSID, externalId: nil, subscriptionId: testPushSubId)

        client.setMockResponseForRequest(
            request: "<OSRequestCreateUser with externalId: nil>",
            response: anonCreateResponse)
    }

    public static func setDefaultCreateUserResponses(with client: MockOneSignalClient, externalId: String) {
        let osid = getOneSignalId(for: externalId)

        let userResponse = MockUserRequests.testIdentityPayload(onesignalId: osid, externalId: externalId)

        client.setMockResponseForRequest(
            request: "<OSRequestCreateUser with externalId: \(externalId)>",
            response: userResponse
        )
        client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with external_id: \(externalId)>",
            response: userResponse
        )
    }

    public static func setDefaultIdentifyUserResponses(with client: MockOneSignalClient, externalId: String, conflicted: Bool = false) {
        var osid: String
        var fetchResponse: [String: [String: String]]

        // 1. Set the response for the Identify User request
        if conflicted {
            osid = getOneSignalId(for: externalId)
            fetchResponse = MockUserRequests.testIdentityPayload(onesignalId: osid, externalId: externalId)
            client.setMockFailureResponseForRequest(
                request: "<OSRequestIdentifyUser with external_id: \(externalId)>",
                error: NSError(domain: "not-important", code: 409)
            )
        } else {
            // The Identify User is successful, the OSID is unchanged
            osid = anonUserOSID
            fetchResponse = MockUserRequests.testIdentityPayload(onesignalId: osid, externalId: externalId)
            client.setMockResponseForRequest(
                request: "<OSRequestIdentifyUser with external_id: \(externalId)>",
                response: fetchResponse
            )
        }
        // 2. Set the response for the subsequent Fetch User request
        client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with external_id: \(externalId)>",
            response: fetchResponse
        )
    }

    public static func setAddTagsResponse(with client: MockOneSignalClient, tags: [String: String]) {
        let tagsResponse = MockUserRequests.testPropertiesPayload(properties: ["tags": tags])

        client.setMockResponseForRequest(
            request: "<OSRequestUpdateProperties with properties: [\"tags\": \(tags)] deltas: nil refreshDeviceMetadata: false>",
            response: tagsResponse
        )
    }
}
