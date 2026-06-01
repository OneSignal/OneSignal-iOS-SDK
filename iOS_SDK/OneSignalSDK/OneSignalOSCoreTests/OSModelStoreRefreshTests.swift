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

/// Validates `OSModelStore.refresh()` — the post-unlock recovery path that the SDK's
/// `start()` relies on so model stores that loaded empty during iOS prewarm re-hydrate
/// from disk before Path 1 runs.
final class OSModelStoreRefreshTests: XCTestCase {

    private let storeKey = "OSModelStoreRefreshTests_storeKey"

    override func setUp() {
        super.setUp()
        OneSignalUserDefaults.initShared().removeValue(forKey: storeKey)
    }

    override func tearDown() {
        OneSignalUserDefaults.initShared().removeValue(forKey: storeKey)
        super.tearDown()
    }

    /// Seed UserDefaults with a serialized models dict, the same way `OSModelStore.add`
    /// persists. Mimics "prior session wrote models to disk".
    private func seedUserDefaults(with models: [String: OSModel]) {
        OneSignalUserDefaults.initShared().saveCodeableData(forKey: storeKey, withValue: models)
    }

    private func makeStore() -> OSModelStore<OSModel> {
        return OSModelStore<OSModel>(changeSubscription: OSEventProducer(), storeKey: storeKey)
    }

    /// Simulates the prewarm case: at OSModelStore.init time UserDefaults returned nil,
    /// then disk became readable. refresh() must pick up what's on disk.
    func testRefresh_hydratesFromUserDefaults_whenStoreLoadedEmpty() {
        // 1. Store inits empty (UD has no entry for storeKey).
        let store = makeStore()
        XCTAssertTrue(store.getModels().isEmpty, "Precondition: store should load empty")

        // 2. Disk gets populated after the fact (simulates the prior session's persisted state).
        let model = OSModel(changeNotifier: OSEventProducer())
        seedUserDefaults(with: ["key_x": model])

        // 3. refresh() should hydrate.
        store.refresh()

        XCTAssertEqual(store.getModels().count, 1, "refresh should hydrate the in-memory dict")
        XCTAssertNotNil(store.getModel(key: "key_x"))
    }

    /// refresh() must be a no-op when the store is already populated — never clobber
    /// in-memory state that may have diverged from disk via writes that haven't flushed.
    func testRefresh_isNoOp_whenStoreAlreadyPopulated() {
        // 1. Seed disk with model A; store init() will load it.
        let modelA = OSModel(changeNotifier: OSEventProducer())
        seedUserDefaults(with: ["key_x": modelA])
        let store = makeStore()
        XCTAssertEqual(store.getModels().count, 1)
        let loadedAId = store.getModel(key: "key_x")?.modelId

        // 2. Disk gets a different model B for the same key.
        let modelB = OSModel(changeNotifier: OSEventProducer())
        seedUserDefaults(with: ["key_x": modelB])

        // 3. refresh() must NOT replace the existing in-memory entry.
        store.refresh()

        XCTAssertEqual(store.getModel(key: "key_x")?.modelId, loadedAId,
                       "refresh must not replace already-loaded model")
    }

    /// refresh() should subscribe the store to each hydrated model's change notifier so
    /// downstream mutations persist via the normal onModelUpdated path.
    func testRefresh_subscribesStoreToHydratedModelNotifiers() {
        let store = makeStore()
        XCTAssertTrue(store.getModels().isEmpty)

        let model = OSModel(changeNotifier: OSEventProducer())
        seedUserDefaults(with: ["key_x": model])

        store.refresh()

        guard let loaded = store.getModel(key: "key_x") else {
            XCTFail("Expected model to be loaded by refresh")
            return
        }

        // Mutate via set(property:) — triggers fire() on changeNotifier. If refresh() wired
        // the subscription, the store's onModelUpdated will receive it and persist the
        // dict back to UserDefaults.
        OneSignalUserDefaults.initShared().removeValue(forKey: storeKey)
        loaded.set(property: "test_prop", newValue: "test_value")

        // After the mutation, UD should be repopulated by onModelUpdated.
        let written = OneSignalUserDefaults.initShared().getSavedCodeableData(forKey: storeKey, defaultValue: nil)
        XCTAssertNotNil(written, "Mutating a refresh()-hydrated model should persist via the store's onModelUpdated handler")
    }

    /// Sanity: when there's nothing on disk, refresh() leaves an empty store empty.
    func testRefresh_doesNothing_whenDiskIsEmpty() {
        let store = makeStore()
        XCTAssertTrue(store.getModels().isEmpty)

        store.refresh()

        XCTAssertTrue(store.getModels().isEmpty)
    }
}
