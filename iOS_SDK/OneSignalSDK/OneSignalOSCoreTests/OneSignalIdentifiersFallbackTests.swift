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

import Foundation
import XCTest
import OneSignalCore
@testable import OneSignalOSCore

/// Validates the UserDefaults-first → OSResilientStorage-fallback read paths.
/// During iOS prewarm before first unlock the shared UserDefaults file is encrypted and
/// returns nil/empty for these keys, so callers (LA executors, NSE) must transparently
/// recover the value from the unencrypted mirror.
final class OneSignalIdentifiersFallbackTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearUserDefaultsKey(OSUD_APP_ID)
        clearUserDefaultsKey(OSUD_PUSH_SUBSCRIPTION_ID)
        OSResilientStorage.setString(nil, forKey: OSResilientStorage.keyAppId)
        OSResilientStorage.setString(nil, forKey: OSResilientStorage.keySubscriptionId)
        // Force the async OSResilientStorage write queue to drain before the next test step.
        _ = OSResilientStorage.snapshot()
    }

    override func tearDown() {
        clearUserDefaultsKey(OSUD_APP_ID)
        clearUserDefaultsKey(OSUD_PUSH_SUBSCRIPTION_ID)
        OSResilientStorage.setString(nil, forKey: OSResilientStorage.keyAppId)
        OSResilientStorage.setString(nil, forKey: OSResilientStorage.keySubscriptionId)
        _ = OSResilientStorage.snapshot()
        super.tearDown()
    }

    private func clearUserDefaultsKey(_ key: String) {
        OneSignalUserDefaults.initShared().removeValue(forKey: key)
    }

    // MARK: - storedAppId

    func testStoredAppId_returnsUserDefaultsValue_whenUDPopulated() {
        OneSignalUserDefaults.initShared().saveString(forKey: OSUD_APP_ID, withValue: "app_id_ud")
        OSResilientStorage.setString("app_id_mirror", forKey: OSResilientStorage.keyAppId)
        _ = OSResilientStorage.snapshot()

        XCTAssertEqual(OneSignalIdentifiers.storedAppId, "app_id_ud",
                       "UD value should take precedence when present")
    }

    func testStoredAppId_fallsBackToMirror_whenUDAbsent() {
        OSResilientStorage.setString("app_id_mirror", forKey: OSResilientStorage.keyAppId)
        _ = OSResilientStorage.snapshot()

        XCTAssertEqual(OneSignalIdentifiers.storedAppId, "app_id_mirror",
                       "Mirror should be returned when UD is empty (locked-storage scenario)")
    }

    func testStoredAppId_returnsNil_whenBothEmpty() {
        XCTAssertNil(OneSignalIdentifiers.storedAppId)
    }

    // MARK: - subscriptionId

    func testSubscriptionId_returnsUserDefaultsValue_whenUDPopulated() {
        OneSignalUserDefaults.initShared().saveString(forKey: OSUD_PUSH_SUBSCRIPTION_ID, withValue: "sub_ud")
        OSResilientStorage.setString("sub_mirror", forKey: OSResilientStorage.keySubscriptionId)
        _ = OSResilientStorage.snapshot()

        XCTAssertEqual(OneSignalIdentifiers.subscriptionId, "sub_ud")
    }

    func testSubscriptionId_fallsBackToMirror_whenUDAbsent() {
        OSResilientStorage.setString("sub_mirror", forKey: OSResilientStorage.keySubscriptionId)
        _ = OSResilientStorage.snapshot()

        XCTAssertEqual(OneSignalIdentifiers.subscriptionId, "sub_mirror")
    }

    func testSubscriptionId_returnsNil_whenBothEmpty() {
        XCTAssertNil(OneSignalIdentifiers.subscriptionId)
    }
}
