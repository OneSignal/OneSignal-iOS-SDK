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
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalUser

/// Values the app chooses reach a URL path once Identity Verification addresses users by `external_id`,
/// so a path built from one has to survive characters that would otherwise change which endpoint it names.
final class RequestPathEncodingTests: XCTestCase {
    private let appId = "test-app-id"
    private let onesignalId = "test-onesignal-id"
    private let externalId = "us er/a?b#c%d"
    private let encodedExternalId = "us%20er%2Fa%3Fb%23c%25d"

    private var newRecordsState = MockNewRecordsState()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = appId
        newRecordsState = MockNewRecordsState()
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
    }

    override func tearDownWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
    }

    private var auth: OSRequestAuthorizing {
        return OneSignalUserManagerImpl.sharedInstance.requestAuth
    }

    /// A user the auth layer can address by `external_id` and sign for.
    @discardableResult
    private func addIdentifiedUser() -> OSIdentityModel {
        let model = OSIdentityModel(
            aliases: [OS_ONESIGNAL_ID: onesignalId, OS_EXTERNAL_ID: externalId],
            changeNotifier: OSEventProducer()
        )
        model.jwtBearerToken = "token-a"
        OneSignalUserManagerImpl.sharedInstance.addIdentityModelToRepo(model)
        return model
    }

    func testFetchUserPercentEncodesTheExternalId() {
        let request = OSRequestFetchUser(
            identityModel: addIdentifiedUser(),
            aliasLabel: OS_ONESIGNAL_ID,
            aliasId: onesignalId,
            onNewSession: false
        )

        XCTAssertTrue(request.prepareForExecution(newRecordsState: newRecordsState, auth: auth))
        XCTAssertEqual(request.path, "apps/\(appId)/users/by/\(OS_EXTERNAL_ID)/\(encodedExternalId)")
    }

    func testUpdatePropertiesPercentEncodesTheExternalId() {
        let request = OSRequestUpdateProperties(
            params: ["properties": ["language": "en"]],
            identityModel: addIdentifiedUser(),
            ownerExternalId: externalId
        )

        XCTAssertTrue(request.prepareForExecution(newRecordsState: newRecordsState, auth: auth))
        XCTAssertEqual(request.path, "apps/\(appId)/users/by/\(OS_EXTERNAL_ID)/\(encodedExternalId)")
    }

    /// The label the app asks to remove is the other app-chosen value in a path.
    func testRemoveAliasPercentEncodesBothTheExternalIdAndTheLabel() {
        let request = OSRequestRemoveAlias(
            labelToRemove: "my label/x",
            identityModel: addIdentifiedUser(),
            ownerExternalId: externalId
        )

        XCTAssertTrue(request.prepareForExecution(newRecordsState: newRecordsState, auth: auth))
        XCTAssertEqual(
            request.path,
            "apps/\(appId)/users/by/\(OS_EXTERNAL_ID)/\(encodedExternalId)/identity/my%20label%2Fx"
        )
    }

    /// Server-assigned ids need no escaping, so the path an app without Identity Verification sends is byte
    /// for byte what it was.
    func testTheOnesignalIdPathIsUnchangedWhileIdentityVerificationIsOff() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: false)
        let request = OSRequestUpdateProperties(
            params: ["properties": ["language": "en"]],
            identityModel: addIdentifiedUser(),
            ownerExternalId: externalId
        )

        XCTAssertTrue(request.prepareForExecution(newRecordsState: newRecordsState, auth: auth))
        XCTAssertEqual(request.path, "apps/\(appId)/users/by/\(OS_ONESIGNAL_ID)/\(onesignalId)")
    }
}
