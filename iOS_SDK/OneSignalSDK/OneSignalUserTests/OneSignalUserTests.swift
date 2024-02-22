/*
 Modified MIT License
 
 Copyright 2024 OneSignal
 
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
import OneSignalCoreMocks
import OneSignalUserMocks
import OneSignalOSCore
@testable import OneSignalUser

final class OneSignalUserTests: XCTestCase {

    override func setUpWithError() throws {
        // TODO: Something like the existing [UnitTestCommonMethods beforeEachTest:self];
        // App ID is set because User Manager has guards against nil App ID
        OneSignalConfigManager.setAppId("test-app-id")
        // Temp. logging to help debug during testing
        OneSignalLog.setLogLevel(.LL_VERBOSE)
    }

    override func tearDownWithError() throws {
        // TODO: Need to clear all data between tests for user manager, models, etc.
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
    }

    // Comparable to Android test: "externalId is backed by the identity model"
    func testLoginSetsExternalId() throws {
        /* Setup */
        OneSignalCore.setSharedClient(MockOneSignalClient())

        /* When */
        OneSignalUserManagerImpl.sharedInstance.login(externalId: "my-external-id", token: nil)

        /* Then */
        let identityModelStoreExternalId = OneSignalUserManagerImpl.sharedInstance.identityModelStore.getModel(key: OS_IDENTITY_MODEL_KEY)?.externalId
        let userInstanceExternalId = OneSignalUserManagerImpl.sharedInstance.user.identityModel.externalId

        XCTAssertEqual(identityModelStoreExternalId, "my-external-id")
        XCTAssertEqual(userInstanceExternalId, "my-external-id")
    }

    /**
     This test reproduces a crash in the Operation Repo's flushing delta queue.
     It is possible for two threads to flush concurrently.
     However, this test does not crash 100% of the time.
     */
    func testOperationRepoFlushingConcurrency() throws {
        /* Setup */
        OneSignalCore.setSharedClient(MockOneSignalClient())

        /* When */

        // 1. Enqueue 10 Deltas to the Operation Repo
        for num in 0...9 {
            OneSignalUserManagerImpl.sharedInstance.addTag(key: "tag\(num)", value: "value")
        }

        // 2. Flush the delta queue from 4 multiple threads
        for _ in 1...4 {
            DispatchQueue.global().async {
                print("🧪 flushDeltaQueue on thread \(Thread.current)")
                OSOperationRepo.sharedInstance.flushDeltaQueue()
            }
        }

        /* Then */
        // There are two places that can crash, as multiple threads are manipulating arrays:
        // 1. OpRepo: `deltaQueue.remove(at: index)` index out of bounds
        // 2. OSPropertyOperationExecutor: `deltaQueue.append(delta)` EXC_BAD_ACCESS
    }
}
