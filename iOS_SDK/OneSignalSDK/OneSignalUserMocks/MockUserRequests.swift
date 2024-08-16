import OneSignalCore
import OneSignalCoreMocks

@objc
public class MockUserRequests: NSObject {

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
            "id": id,
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
        let subscription = testDefaultPushSubPayload(id: subscriptionId ?? testPushSubId)
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

    @objc
    public static func setDefaultCreateAnonUserResponses(with client: MockOneSignalClient) {
        let anonCreateResponse = testDefaultFullCreateUserResponse(onesignalId: anonUserOSID, externalId: nil, subscriptionId: testPushSubId)

        client.setMockResponseForRequest(
            request: "<OSRequestCreateUser with external_id: nil>",
            response: anonCreateResponse)
    }

    public static func setDefaultCreateUserResponses(with client: MockOneSignalClient, externalId: String, subscriptionId: String? = nil) {
        let osid = getOneSignalId(for: externalId)

        let userResponse = testDefaultFullCreateUserResponse(onesignalId: osid, externalId: externalId, subscriptionId: subscriptionId)
        client.setMockResponseForRequest(
            request: "<OSRequestCreateUser with external_id: \(externalId)>",
            response: userResponse
        )
        client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with onesignal_id: \(osid)>",
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
            // 2. Set the response for the subsequent Create User request
            let userResponse = MockUserRequests.testIdentityPayload(onesignalId: osid, externalId: externalId)
            client.setMockResponseForRequest(
                request: "<OSRequestCreateUser with external_id: \(externalId)>",
                response: userResponse)
            // 3. Set the response for the subsequent Fetch User request
            client.setMockResponseForRequest(
                request: "<OSRequestFetchUser with onesignal_id: \(osid)>",
                response: fetchResponse
            )
        } else {
            // The Identify User is successful, the OSID is unchanged
            osid = anonUserOSID
            fetchResponse = MockUserRequests.testIdentityPayload(onesignalId: osid, externalId: externalId)
            client.setMockResponseForRequest(
                request: "<OSRequestIdentifyUser with external_id: \(externalId)>",
                response: fetchResponse
            )
            // 2. Set the response for the subsequent Fetch User request
            client.setMockResponseForRequest(
                request: "<OSRequestFetchUser with onesignalId: \(osid)>",
                response: fetchResponse
            )
        }
    }

    /**
     Returns many user data to mimic pulling remote data. Used to test for hydration.
     */
    public static func setDefaultFetchUserResponseForHydration(with client: MockOneSignalClient, externalId: String) {
        let osid = getOneSignalId(for: externalId)

        var fetchResponse: [String: Any] = [
            "identity": ["onesignal_id": osid, "external_id": externalId, "remote_alias": "remote_id"],
            "properties": [
                "tags": ["remote_tag": "remote_value"],
                "language": "remote_language"
            ],
            "subscriptions": [
                ["type": "Email",
                 "id": "remote_email_id",
                 "token": "remote_email@example.com"
                ]
            ]
        ]
        client.setMockResponseForRequest(
            request: "<OSRequestFetchUser with onesignal_id: \(osid)>",
            response: fetchResponse
        )
    }

    public static func setAddTagsResponse(with client: MockOneSignalClient, tags: [String: String]) {
        let params: NSDictionary = [
            "properties": [
                "tags": tags
            ],
            "refresh_device_metadata": false
        ]

        let tagsResponse = MockUserRequests.testPropertiesPayload(properties: ["tags": tags])

        client.setMockResponseForRequest(
            request: "<OSRequestUpdateProperties with parameters: \(params.toSortedString())>",
            response: tagsResponse
        )
    }

    /// Sets the mock response when tags and language are added, which will be sent in one request
    public static func setAddTagsAndLanguageResponse(with client: MockOneSignalClient, tags: [String: String], language: String) {
        let params: NSDictionary = [
            "properties": [
                "language": Optional(language), // to match the stringify of the actual request
                "tags": tags
            ],
            "refresh_device_metadata": false
        ]

        let tagsResponse = testPropertiesPayload(properties: ["tags": tags])

        client.setMockResponseForRequest(
            request: "<OSRequestUpdateProperties with parameters: \(params.toSortedString())>",
            response: tagsResponse
        )
    }

    public static func setAddAliasesResponse(with client: MockOneSignalClient, aliases: [String: String]) {
        client.setMockResponseForRequest(
            request: "<OSRequestAddAliases with aliases: \(aliases)>",
            response: [:] // The SDK does not use the response in any way
        )
    }

    /** The real response will either contain a subscription payload or be empty (if already exists on user) */
    public static func setAddEmailResponse(with client: MockOneSignalClient, email: String) {
        let response = [
            "subscription": [
                "id": "\(email)_id",
                "type": "Email",
                "token": email
            ]
        ]
        client.setMockResponseForRequest(
            request: "<OSRequestCreateSubscription with token: \(email)>",
            response: response
        )
    }
}
