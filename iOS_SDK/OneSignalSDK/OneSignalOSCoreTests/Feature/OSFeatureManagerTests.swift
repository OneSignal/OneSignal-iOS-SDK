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

final class OSFeatureManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearCachedKeys()
    }

    override func tearDown() {
        clearCachedKeys()
        super.tearDown()
    }

    private func clearCachedKeys() {
        OneSignalUserDefaults.initShared().removeValue(forKey: OSUD_SDK_FEATURE_FLAGS)
    }

    func testFlagsAreOffWithoutRemoteConfig() {
        XCTAssertFalse(OSFeatureManager().isEnabled(.identityVerification))
    }

    func testSettingTheKeyEnablesTheFlag() {
        let featureManager = OSFeatureManager()
        featureManager.setEnabledFeatureKeys([OSFeatureFlag.identityVerification.rawValue])

        XCTAssertTrue(featureManager.isEnabled(.identityVerification))
    }

    func testEnabledKeysAreReadBackOnTheNextLaunch() {
        OSFeatureManager().setEnabledFeatureKeys([OSFeatureFlag.identityVerification.rawValue])

        XCTAssertTrue(OSFeatureManager().isEnabled(.identityVerification))
    }

    func testUnrecognizedKeysDontEnableAnything() {
        let featureManager = OSFeatureManager()
        featureManager.setEnabledFeatureKeys(["sdk_some_future_feature"])

        XCTAssertFalse(featureManager.isEnabled(.identityVerification))
    }

    func testKeysMatchRegardlessOfCase() {
        let featureManager = OSFeatureManager()
        featureManager.setEnabledFeatureKeys(["SDK_Identity_Verification"])

        XCTAssertTrue(featureManager.isEnabled(.identityVerification))
    }

    func testDroppingTheKeyTurnsTheFlagOffWithoutARelaunch() {
        let featureManager = OSFeatureManager()
        featureManager.setEnabledFeatureKeys([OSFeatureFlag.identityVerification.rawValue])

        featureManager.setEnabledFeatureKeys([])

        // The kill switch has to land in the current run, and it can't come back on the next one
        XCTAssertFalse(featureManager.isEnabled(.identityVerification))
        XCTAssertFalse(OSFeatureManager().isEnabled(.identityVerification))
    }

    func testKeysPassedToTheInitializerBypassTheCache() {
        OSFeatureManager().setEnabledFeatureKeys([])

        let featureManager = OSFeatureManager(enabledKeys: [OSFeatureFlag.identityVerification.rawValue])

        XCTAssertTrue(featureManager.isEnabled(.identityVerification))
    }
}
