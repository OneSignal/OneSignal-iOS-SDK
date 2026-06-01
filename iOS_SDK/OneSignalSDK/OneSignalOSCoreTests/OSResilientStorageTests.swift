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
@testable import OneSignalOSCore

final class OSResilientStorageTests: XCTestCase {

    /// Test keys. We avoid the real key constants so collisions with anything written by
    /// other tests / fixtures during the same simulator session can't bleed into assertions.
    private let keyA = "test_key_a"
    private let keyB = "test_key_b"

    override func setUp() {
        super.setUp()
        clearAllTestKeys()
    }

    override func tearDown() {
        clearAllTestKeys()
        super.tearDown()
    }

    private func clearAllTestKeys() {
        OSResilientStorage.setString(nil, forKey: keyA)
        OSResilientStorage.setString(nil, forKey: keyB)
        // Writes are queue.async; force ordering with a queue.sync read.
        _ = OSResilientStorage.snapshot()
    }

    // MARK: - setString / string(forKey:)

    func testSetThenGet_returnsTheStoredValue() {
        OSResilientStorage.setString("alpha", forKey: keyA)
        XCTAssertEqual(OSResilientStorage.string(forKey: keyA), "alpha")
    }

    func testGet_returnsNilWhenAbsent() {
        XCTAssertNil(OSResilientStorage.string(forKey: "never_written_\(UUID().uuidString)"))
    }

    func testSetWithNil_removesKey() {
        OSResilientStorage.setString("alpha", forKey: keyA)
        XCTAssertEqual(OSResilientStorage.string(forKey: keyA), "alpha")

        OSResilientStorage.setString(nil, forKey: keyA)
        XCTAssertNil(OSResilientStorage.string(forKey: keyA))
    }

    func testSetWithEmptyString_removesKey() {
        OSResilientStorage.setString("alpha", forKey: keyA)
        OSResilientStorage.setString("", forKey: keyA)
        XCTAssertNil(OSResilientStorage.string(forKey: keyA))
    }

    func testGet_returnsNilWhenStoredValueIsEmpty() {
        // Direct insert via setStrings to verify the read-side empty-guard, not just the write side.
        OSResilientStorage.setStrings([keyA: "alpha"])
        OSResilientStorage.setStrings([keyA: ""])
        XCTAssertNil(OSResilientStorage.string(forKey: keyA))
    }

    // MARK: - setStrings (batch)

    func testSetStrings_setsMultipleKeysAtomically() {
        OSResilientStorage.setStrings([keyA: "alpha", keyB: "beta"])
        XCTAssertEqual(OSResilientStorage.string(forKey: keyA), "alpha")
        XCTAssertEqual(OSResilientStorage.string(forKey: keyB), "beta")
    }

    func testSetStrings_emptyValueRemovesCorrespondingKey() {
        OSResilientStorage.setStrings([keyA: "alpha", keyB: "beta"])
        OSResilientStorage.setStrings([keyA: ""])
        XCTAssertNil(OSResilientStorage.string(forKey: keyA))
        XCTAssertEqual(OSResilientStorage.string(forKey: keyB), "beta")
    }

    func testSetStrings_preservesKeysNotInTheUpdateDict() {
        OSResilientStorage.setStrings([keyA: "alpha", keyB: "beta"])
        OSResilientStorage.setStrings([keyA: "alpha_updated"])
        XCTAssertEqual(OSResilientStorage.string(forKey: keyA), "alpha_updated")
        XCTAssertEqual(OSResilientStorage.string(forKey: keyB), "beta")
    }

    func testSetStrings_emptyDictIsNoOp() {
        OSResilientStorage.setStrings([keyA: "alpha"])
        OSResilientStorage.setStrings([:])
        XCTAssertEqual(OSResilientStorage.string(forKey: keyA), "alpha")
    }

    // MARK: - snapshot

    func testSnapshot_reflectsCurrentContents() {
        OSResilientStorage.setStrings([keyA: "alpha", keyB: "beta"])
        let snap = OSResilientStorage.snapshot()
        XCTAssertEqual(snap[keyA], "alpha")
        XCTAssertEqual(snap[keyB], "beta")
    }
}
