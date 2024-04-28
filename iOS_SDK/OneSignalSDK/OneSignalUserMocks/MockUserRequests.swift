import OneSignalCore

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
}
