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
@testable import OneSignalOSCore

/// Covers `OSDelta` archive round trips, including the owning user's external ID.
final class OSDeltaTests: XCTestCase {

    private func makeDelta(externalId: String?) -> OSDelta {
        OSDelta(
            name: "test_delta",
            identityModelId: "identity-model-a",
            externalId: externalId,
            model: OSModel(changeNotifier: OSEventProducer()),
            property: "language",
            value: "en"
        )
    }

    private func archiveThenUnarchive(_ delta: OSDelta) throws -> OSDelta {
        let data = try NSKeyedArchiver.archivedData(withRootObject: delta, requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        defer { unarchiver.finishDecoding() }
        return try XCTUnwrap(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? OSDelta)
    }

    func testExternalIdSurvivesAnArchiveRoundTrip() throws {
        let delta = makeDelta(externalId: "user-a")

        let decoded = try archiveThenUnarchive(delta)

        XCTAssertEqual(decoded.externalId, "user-a")
        XCTAssertEqual(decoded.identityModelId, "identity-model-a")
        XCTAssertEqual(decoded.deltaId, delta.deltaId)
    }

    /// Decode must succeed when externalId is absent, or queued work is dropped on upgrade.
    func testADeltaWithoutAnExternalIdStillDecodes() throws {
        let delta = makeDelta(externalId: nil)

        let decoded = try archiveThenUnarchive(delta)

        XCTAssertNil(decoded.externalId)
        XCTAssertEqual(decoded.identityModelId, "identity-model-a")
        XCTAssertEqual(decoded.property, "language")
        XCTAssertEqual(decoded.value as? String, "en")
    }
}
