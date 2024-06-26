import XCTest
import OneSignalCore
import OneSignalCoreMocks
import OneSignalUserMocks
@testable import OneSignalOSCore
@testable import OneSignalUser

final class SwitchUserIntegrationTests: XCTestCase {

    override func setUpWithError() throws {
        // TODO: Something like the existing [UnitTestCommonMethods beforeEachTest:self];
        // TODO: Need to clear all data between tests for client, user manager, models, etc.
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        // App ID is set because User Manager has guards against nil App ID
        OneSignalConfigManager.setAppId("test-app-id")
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws { }

    func testIdentifyUserSuccessfully_thenLogin_sendsCorrectTags💛() throws {
        /* Setup */

        let client = MockOneSignalClient()

        // 1. Set up mock responses for the anonymous user
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)

        // 2. Set up mock responses for User A
        let tagsUserA = ["tag_a": "value_a"]
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userA_EUID)
        MockUserRequests.setAddTagsResponse(with: client, tags: tagsUserA)

        // 3. Set up mock responses for User B
        let tagsUserB = ["tag_b": "value_b"]
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userB_EUID)
        MockUserRequests.setAddTagsResponse(with: client, tags: tagsUserB)

        OneSignalCoreImpl.setSharedClient(client)

        /* When */

        // 1. Login to user A and add tag
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_a", value: "value_a")

        // 2. Login to user B and add tag
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_b", value: "value_b")

        // 3. Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 0.5)

        /* Then */

        // Assert that every request SDK makes has a response set, and is handled
        XCTAssertTrue(client.allRequestsHandled)

        // Assert there is only one request containing these tags and they are sent to the Anon User
        // This is because the Identify User request succeeded, so the user remains the same
        XCTAssertTrue(client.onlyOneRequest(
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)",
            contains: ["properties": ["tags": tagsUserA]])
        )
        // Assert there is only one request containing these tags and they are sent to userB
        XCTAssertTrue(client.onlyOneRequest(
            contains: "apps/test-app-id/users/by/onesignal_id/\(userB_OSID)",
            contains: ["properties": ["tags": tagsUserB]])
        )
    }

    /*
     This test simulates this these calls:
     
     // Start with Anonymous User
     OneSignal.User.addTag(key: "tag_anon", value: "value_anon")
     OneSignal.User.setLanguage("lang_anon")
     OneSignal.User.addAlias(label: "alias_anon", id: "id_anon")
     OneSignal.User.addEmail("email_anon@example.com")

     OneSignal.login(<EXISTING_USER>)
     OneSignal.User.addTag(key: "tag_a", value: "value_a")
     OneSignal.User.setLanguage("lang_a")
     OneSignal.User.addAlias(label: "alias_a", id: "id_a")
     OneSignal.User.addEmail("email_a@example.com")
     */
    func testAnonUser_thenIdentifyUserWithConflict_sendsCorrectUpdatesAndFetchesUser💛() throws {
        /* Setup */

        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)

        // 1. Set up mock responses for the first anonymous user
        let tagsUserAnon = ["tag_anon": "value_anon"]
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setAddTagsAndLanguageResponse(with: client, tags: tagsUserAnon, language: "lang_anon")
        MockUserRequests.setAddAliasesResponse(with: client, aliases: ["alias_anon": "id_anon"])
        MockUserRequests.setAddEmailResponse(with: client, email: "email_anon@example.com")

        // 2. Set up mock responses for User A with 409 conflict response
        let tagsUserA = ["tag_a": "value_a"]
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userA_EUID, conflicted: true)
        MockUserRequests.setAddTagsAndLanguageResponse(with: client, tags: tagsUserA, language: "lang_a")
        MockUserRequests.setAddAliasesResponse(with: client, aliases: ["alias_a": "id_a"])
        MockUserRequests.setAddEmailResponse(with: client, email: "email_a@example.com")
        MockUserRequests.setTransferSubscriptionResponse(with: client, externalId: userA_EUID)
        // Returns mocked user data to test hydration
        MockUserRequests.setDefaultFetchUserResponseForHydration(with: client, externalId: userA_EUID)

        /* When */

        // 1. Anonymous user
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_anon", value: "value_anon")
        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_anon")
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "alias_anon", id: "id_anon")
        OneSignalUserManagerImpl.sharedInstance.addEmail("email_anon@example.com")

        // 2. Login to user A (will result in 409 conflict) and add data
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_a", value: "value_a")
        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_a")
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "alias_a", id: "id_a")
        OneSignalUserManagerImpl.sharedInstance.addEmail("email_a@example.com")

        // 3. Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 1)

        /* Then */

        // 0. Assert that every request SDK makes has a response set, and is handled
        XCTAssertTrue(client.allRequestsHandled)
        XCTAssertEqual(client.executedRequests.count, 10)

        // 1. Asserts for first Anonymous User
        XCTAssertTrue(client.onlyOneRequest( // Tag + Language
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)",
            contains: ["properties": ["language": "lang_anon", "tags": tagsUserAnon]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Alias
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)/identity",
            contains: ["identity": ["alias_anon": "id_anon"]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Email
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)/subscriptions",
            contains: ["subscription": ["token": "email_anon@example.com"]])
        )

        // 2. Asserts for User A - expected requests are sent
        XCTAssertTrue(client.onlyOneRequest( // Tag + Language
            contains: "apps/test-app-id/users/by/onesignal_id/\(userA_OSID)",
            contains: ["properties": ["language": "lang_a", "tags": tagsUserA]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Alias
            contains: "apps/test-app-id/users/by/onesignal_id/\(userA_OSID)/identity",
            contains: ["identity": ["alias_a": "id_a"]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Email
            contains: "apps/test-app-id/users/by/onesignal_id/\(userA_OSID)/subscriptions",
            contains: ["subscription": ["token": "email_a@example.com"]])
        )
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestFetchUser.self))
        XCTAssertTrue(client.hasExecutedRequestOfType(OSRequestTransferSubscription.self))

        // 3. Asserts for User A - local data is updated via hydration
        XCTAssertEqual("remote_language", OneSignalUserManagerImpl.sharedInstance.user.propertiesModel.language)
        XCTAssertNotNil(OneSignalUserManagerImpl.sharedInstance.getTags()["remote_tag"])
        XCTAssertNotNil(OneSignalUserManagerImpl.sharedInstance.user.identityModel.aliases["remote_alias"])
        XCTAssertNotNil(OneSignalUserManagerImpl.sharedInstance.subscriptionModelStore.getModel(key: "remote_email@example.com"))
    }

    /*
     This test simulates  these calls:
     
     // Start with Anonymous User
     OneSignal.User.addTag(key: "tag_anon", value: "value_anon")
     OneSignal.User.setLanguage("lang_anon")
     OneSignal.User.addAlias(label: "alias_anon", id: "id_anon")
     OneSignal.User.addEmail("email_anon@example.com")

     OneSignal.login(<EXISTING_USER>)
     OneSignal.User.addTag(key: "tag_a", value: "value_a")
     OneSignal.User.setLanguage("lang_a")
     OneSignal.User.addAlias(label: "alias_a", id: "id_a")
     OneSignal.User.addEmail("email_a@example.com")

     OneSignal.logout()
     OneSignal.User.addTag(key: "tag_b", value: "value_b")
     OneSignal.User.setLanguage("lang_b")
     OneSignal.User.addAlias(label: "alias_b", id: "id_b")
     OneSignal.User.addEmail("email_b@example.com")
     */
    func testAnonUser_thenIdentifyUserWithConflict_thenLogout_sendsCorrectUpdatesWithNoFetch💛() throws {
        /* Setup */

        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)

        // 1. Set up mock responses for the first anonymous user
        let tagsUserAnon = ["tag_anon": "value_anon"]
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setAddTagsAndLanguageResponse(with: client, tags: tagsUserAnon, language: "lang_anon")
        MockUserRequests.setAddAliasesResponse(with: client, aliases: ["alias_anon": "id_anon"])
        MockUserRequests.setAddEmailResponse(with: client, email: "email_anon@example.com")

        // 2. Set up mock responses for User A with 409 conflict response
        let tagsUserA = ["tag_a": "value_a"]
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userA_EUID, conflicted: true)
        MockUserRequests.setAddTagsAndLanguageResponse(with: client, tags: tagsUserA, language: "lang_a")
        MockUserRequests.setAddAliasesResponse(with: client, aliases: ["alias_a": "id_a"])
        MockUserRequests.setAddEmailResponse(with: client, email: "email_a@example.com")

        // 3. Set up mock responses for second Anonymous User
        let tagsUserB = ["tag_b": "value_b"]
        MockUserRequests.setAddTagsAndLanguageResponse(with: client, tags: tagsUserB, language: "lang_b")
        MockUserRequests.setAddAliasesResponse(with: client, aliases: ["alias_b": "id_b"])
        MockUserRequests.setAddEmailResponse(with: client, email: "email_b@example.com")

        /* When */

        // 1. Anonymous user starts
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_anon", value: "value_anon")
        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_anon")
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "alias_anon", id: "id_anon")
        OneSignalUserManagerImpl.sharedInstance.addEmail("email_anon@example.com")

        // 2. Login to user A (will result in 409 conflict) and add data
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_a", value: "value_a")
        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_a")
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "alias_a", id: "id_a")
        OneSignalUserManagerImpl.sharedInstance.addEmail("email_a@example.com")

        // 3. Logout and add data
        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_b", value: "value_b")
        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_b")
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "alias_b", id: "id_b")
        OneSignalUserManagerImpl.sharedInstance.addEmail("email_b@example.com")

        // 4. Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 1)

        /* Then */

        // 0. Assert that every request SDK makes has a response set, and is handled
        XCTAssertTrue(client.allRequestsHandled)

        // 1. Asserts for first Anonymous User
        XCTAssertTrue(client.onlyOneRequest( // Tag + Language
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)",
            contains: ["properties": ["language": "lang_anon", "tags": tagsUserAnon]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Alias
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)/identity",
            contains: ["identity": ["alias_anon": "id_anon"]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Email
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)/subscriptions",
            contains: ["subscription": ["token": "email_anon@example.com"]])
        )

        // 2. Asserts for User A
        XCTAssertTrue(client.onlyOneRequest( // Tag + Language
            contains: "apps/test-app-id/users/by/external_id/\(userA_EUID)",
            contains: ["properties": ["language": "lang_a", "tags": tagsUserA]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Alias
            contains: "apps/test-app-id/users/by/external_id/\(userA_EUID)/identity",
            contains: ["identity": ["alias_a": "id_a"]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Email
            contains: "apps/test-app-id/users/by/external_id/\(userA_EUID)/subscriptions",
            contains: ["subscription": ["token": "email_a@example.com"]])
        )

        // 3. Asserts for the second Anonymous User
        XCTAssertTrue(client.onlyOneRequest( // Tag + Language
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)",
            contains: ["properties": ["language": "lang_b", "tags": tagsUserB]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Alias
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)/identity",
            contains: ["identity": ["alias_b": "id_b"]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Email
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)/subscriptions",
            contains: ["subscription": ["token": "email_b@example.com"]])
        )

        // 4. In this flow with anon users, no Fetch User calls should have happened
        XCTAssertFalse(client.hasExecutedRequestOfType(OSRequestFetchUser.self))
    }

    /*
     This test simulates this these calls:
     
     // Start with Anonymous User
     OneSignal.User.addTag(key: "tag_anon", value: "value_anon")
     OneSignal.User.setLanguage("lang_anon")
     OneSignal.User.addAlias(label: "alias_anon", id: "id_anon")
     OneSignal.User.addEmail("email_anon@example.com")

     OneSignal.login(<EXISTING_USER>)
     OneSignal.User.addTag(key: "tag_a", value: "value_a")
     OneSignal.User.setLanguage("lang_a")
     OneSignal.User.addAlias(label: "alias_a", id: "id_a")
     OneSignal.User.addEmail("email_a@example.com")

     OneSignal.login(userB_EUID)
     OneSignal.User.addTag(key: "tag_b", value: "value_b")
     OneSignal.User.setLanguage("lang_b")
     OneSignal.User.addAlias(label: "alias_b", id: "id_b")
     OneSignal.User.addEmail("email_b@example.com")
     */
    func testAnonUser_thenIdentifyUserWithConflict_thenLogin_sendsCorrectUpdatesAndFetchesUser💛() throws {
        /* Setup */

        let client = MockOneSignalClient()
        OneSignalCoreImpl.setSharedClient(client)

        // Increase flush interval to allow all the updates to batch
        OSOperationRepo.sharedInstance.pollIntervalMilliseconds = 300

        // 1. Set up mock responses for the first anonymous user
        let tagsUserAnon = ["tag_anon": "value_anon"]
        MockUserRequests.setDefaultCreateAnonUserResponses(with: client)
        MockUserRequests.setAddTagsAndLanguageResponse(with: client, tags: tagsUserAnon, language: "lang_anon")
        MockUserRequests.setAddAliasesResponse(with: client, aliases: ["alias_anon": "id_anon"])
        MockUserRequests.setAddEmailResponse(with: client, email: "email_anon@example.com")

        // 2. Set up mock responses for User A with 409 conflict response
        let tagsUserA = ["tag_a": "value_a"]
        MockUserRequests.setDefaultIdentifyUserResponses(with: client, externalId: userA_EUID, conflicted: true)
        MockUserRequests.setAddTagsAndLanguageResponse(with: client, tags: tagsUserA, language: "lang_a")
        MockUserRequests.setAddAliasesResponse(with: client, aliases: ["alias_a": "id_a"])
        MockUserRequests.setAddEmailResponse(with: client, email: "email_a@example.com")

        // 3. Set up mock responses for for User B
        let tagsUserB = ["tag_b": "value_b"]
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userB_EUID)
        MockUserRequests.setAddTagsAndLanguageResponse(with: client, tags: tagsUserB, language: "lang_b")
        MockUserRequests.setAddAliasesResponse(with: client, aliases: ["alias_b": "id_b"])
        MockUserRequests.setAddEmailResponse(with: client, email: "email_b@example.com")
        // Returns mocked user data to test hydration
        MockUserRequests.setDefaultFetchUserResponseForHydration(with: client, externalId: userB_EUID)

        /* When */

        // 1. Anonymous user
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_anon", value: "value_anon")
        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_anon")
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "alias_anon", id: "id_anon")
        OneSignalUserManagerImpl.sharedInstance.addEmail("email_anon@example.com")

        // 1. Login to user A (will result in 409 conflict) and add data
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_a", value: "value_a")
        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_a")
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "alias_a", id: "id_a")
        OneSignalUserManagerImpl.sharedInstance.addEmail("email_a@example.com")

        // 2. Login and add data
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userB_EUID, token: nil)
        OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag_b", value: "value_b")
        OneSignalUserManagerImpl.sharedInstance.setLanguage("lang_b")
        OneSignalUserManagerImpl.sharedInstance.addAlias(label: "alias_b", id: "id_b")
        OneSignalUserManagerImpl.sharedInstance.addEmail("email_b@example.com")

        // 3. Run background threads
        OneSignalCoreMocks.waitForBackgroundThreads(seconds: 1)

        /* Then */

        // 0. Assert that every request SDK makes has a response set, and is handled
        XCTAssertTrue(client.allRequestsHandled)
        XCTAssertEqual(client.executedRequests.count, 13)

        // 1. Asserts for first Anonymous User
        XCTAssertTrue(client.onlyOneRequest( // Tag + Language
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)",
            contains: ["properties": ["language": "lang_anon", "tags": tagsUserAnon]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Alias
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)/identity",
            contains: ["identity": ["alias_anon": "id_anon"]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Email
            contains: "apps/test-app-id/users/by/onesignal_id/\(anonUserOSID)/subscriptions",
            contains: ["subscription": ["token": "email_anon@example.com"]])
        )

        // 2. Asserts for User A
        XCTAssertTrue(client.onlyOneRequest( // Tag + Language
            contains: "apps/test-app-id/users/by/external_id/\(userA_EUID)",
            contains: ["properties": ["language": "lang_a", "tags": tagsUserA]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Alias
            contains: "apps/test-app-id/users/by/external_id/\(userA_EUID)/identity",
            contains: ["identity": ["alias_a": "id_a"]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Email
            contains: "apps/test-app-id/users/by/external_id/\(userA_EUID)/subscriptions",
            contains: ["subscription": ["token": "email_a@example.com"]])
        )

        // 3. Asserts for User B - expected requests sent
        XCTAssertTrue(client.onlyOneRequest( // Tag + Language
            contains: "apps/test-app-id/users/by/onesignal_id/\(userB_OSID)",
            contains: ["properties": ["language": "lang_b", "tags": tagsUserB]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Alias
            contains: "apps/test-app-id/users/by/onesignal_id/\(userB_OSID)/identity",
            contains: ["identity": ["alias_b": "id_b"]])
        )
        XCTAssertTrue(client.onlyOneRequest( // Email
            contains: "apps/test-app-id/users/by/onesignal_id/\(userB_OSID)/subscriptions",
            contains: ["subscription": ["token": "email_b@example.com"]])
        )

        // 4. Asserts for User B - local data is updated via hydration
        XCTAssertEqual("remote_language", OneSignalUserManagerImpl.sharedInstance.user.propertiesModel.language)
        XCTAssertNotNil(OneSignalUserManagerImpl.sharedInstance.getTags()["remote_tag"])
        XCTAssertNotNil(OneSignalUserManagerImpl.sharedInstance.user.identityModel.aliases["remote_alias"])
        XCTAssertNotNil(OneSignalUserManagerImpl.sharedInstance.subscriptionModelStore.getModel(key: "remote_email@example.com"))
    }
}
