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
import OneSignalUser
import OneSignalCoreMocks
import OneSignalUserMocks

@testable import OneSignalLiveActivities

final class DefaultLiveActivityAttributesTests: XCTestCase {

    // This isn't exactly what iOS is doing, but the assumption is they are using JSONDecoder
    // to materialize a DefaultLiveActivityAttributes and DefaultLiveActivityAttributes.ContentState
    func testProperDecodingOfAttributePayload() throws {
        /* Setup */
        let json = """
        {
            "data": {
                "stringValue": "this is a string",
                "intValue": 6,
                "negIntValue": -6,
                "largeIntValue": 2147483648,
                "negLargeIntValue": -2147483648,
                "floatValue": 50.6,
                "negFloatValue": -50.6,
                "largeFloatValue": 1.0E+40,
                "negLargeFloatValue": -1.0E+40,
                "smallFloatValue": 1.0E-40,
                "negSmallFloatValue": -1.0E-40,
                "boolValue": true,
                "arrayStringValue": [ "this", "is", "a", "string" ],
                "arrayIntValue": [ 1, 2, 3, 4 ],
                "arrayBoolValue": [ true, false ],
                "arrayDictValue": [ { "key": "value" } ],
                "arrayArrayValue": [ ["value"] ],
                "dictValue": {
                    "stringValue": "value",
                    "arrayValue": ["value"],
                    "anotherDict": {
                        "intValue": 7
                    }
                }
            },
            "onesignal": {
                "activityId": "my-activity-id"
            }
        }
        """.data(using: .utf8)!
        
        /* When */
        let decoder = JSONDecoder()
        let sut = try decoder.decode(DefaultLiveActivityAttributes.self, from: json)

        /* Then */
        XCTAssertEqual(sut.data.count, 18)
        XCTAssertEqual(sut.data["stringValue"]?.asString(), "this is a string")
        XCTAssertEqual(sut.data["intValue"]?.asInt(), 6)
        XCTAssertEqual(sut.data["negIntValue"]?.asInt(), -6)
        XCTAssertEqual(sut.data["largeIntValue"]?.asInt(), 2147483648)
        XCTAssertEqual(sut.data["negLargeIntValue"]?.asInt(), -2147483648)
        XCTAssertEqual(sut.data["floatValue"]?.asDouble(), 50.6)
        XCTAssertEqual(sut.data["negFloatValue"]?.asDouble(), -50.6)
        XCTAssertEqual(sut.data["largeFloatValue"]?.asDouble(), 1.0E+40)
        XCTAssertEqual(sut.data["negLargeFloatValue"]?.asDouble(), -1.0E+40)
        XCTAssertEqual(sut.data["smallFloatValue"]?.asDouble(), 1.0E-40)
        XCTAssertEqual(sut.data["negSmallFloatValue"]?.asDouble(), -1.0E-40)
        XCTAssertEqual(sut.data["boolValue"]?.asBool(), true)
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?.count, 4)
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?[0].asString(), "this")
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?[1].asString(), "is")
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?[2].asString(), "a")
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?[3].asString(), "string")
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?.count, 4)
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?[0].asInt(), 1)
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?[1].asInt(), 2)
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?[2].asInt(), 3)
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?[3].asInt(), 4)
        XCTAssertEqual(sut.data["arrayBoolValue"]?.asArray()?.count, 2)
        XCTAssertEqual(sut.data["arrayBoolValue"]?.asArray()?[0].asBool(), true)
        XCTAssertEqual(sut.data["arrayBoolValue"]?.asArray()?[1].asBool(), false)
        XCTAssertEqual(sut.data["arrayDictValue"]?.asArray()?.count, 1)
        XCTAssertEqual(sut.data["arrayDictValue"]?.asArray()?[0].asDict()?["key"], "value")
        XCTAssertEqual(sut.data["arrayArrayValue"]?.asArray()?.count, 1)
        XCTAssertEqual(sut.data["arrayArrayValue"]?.asArray()?[0].asArray()?[0], "value")
        XCTAssertEqual(sut.data["dictValue"]?.asDict()?["stringValue"]?.asString(), "value")
        XCTAssertEqual(sut.data["dictValue"]?.asDict()?["arrayValue"]?.asArray()?[0], "value")
        XCTAssertEqual(sut.data["dictValue"]?.asDict()?["anotherDict"]?.asDict()?["intValue"]?.asInt(), 7)
        XCTAssertEqual(sut.onesignal.activityId, "my-activity-id")
    }
    
    func testProperDecodingOfAttributesWithExtraOneSignalParameters() throws {
        /* Setup */
        let json = """
        {
            "data": {
            },
            "onesignal": {
                "activityId": "my-activity-id",
                "newAttribute": "newValue",
            }
        }
        """.data(using: .utf8)!
        
        /* When */
        let decoder = JSONDecoder()
        _ = try decoder.decode(DefaultLiveActivityAttributes.self, from: json)

        /* Then */
        // not blowing up is a passed test
    }
    
    func testEmptyAttributesPayloadThrowsError() {
        /* Setup */
        let json = """
        {
        }
        """.data(using: .utf8)!
        
        /* When/Then */
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(DefaultLiveActivityAttributes.self, from: json))
    }
    
    func testMissingDataInAttributesPayloadThrowsError() {
        /* Setup */
        let json = """
        {
            "notData": {}
        }
        """.data(using: .utf8)!
        
        /* When/Then */
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(DefaultLiveActivityAttributes.self, from: json))
    }
    
    func testProperDecodingOfContentStatePayload() throws {
        /* Setup */
        let json = """
        {
            "data": {
                "stringValue": "this is a string",
                "intValue": 6,
                "negIntValue": -6,
                "largeIntValue": 2147483648,
                "negLargeIntValue": -2147483648,
                "floatValue": 50.6,
                "negFloatValue": -50.6,
                "largeFloatValue": 1.0E+40,
                "negLargeFloatValue": -1.0E+40,
                "smallFloatValue": 1.0E-40,
                "negSmallFloatValue": -1.0E-40,
                "boolValue": true,
                "arrayStringValue": [ "this", "is", "a", "string" ],
                "arrayIntValue": [ 1, 2, 3, 4 ],
                "arrayBoolValue": [ true, false ],
                "arrayDictValue": [ { "key": "value" } ],
                "arrayArrayValue": [ ["value"] ],
                "dictValue": {
                    "stringValue": "value",
                    "arrayValue": ["value"],
                    "anotherDict": {
                        "intValue": 7
                    }
                }
            }
        }
        """.data(using: .utf8)!
        
        /* When */
        let decoder = JSONDecoder()
        let sut = try decoder.decode(DefaultLiveActivityAttributes.ContentState.self, from: json)

        /* Then */
        XCTAssertEqual(sut.data.count, 18)
        XCTAssertEqual(sut.data["stringValue"]?.asString(), "this is a string")
        XCTAssertEqual(sut.data["intValue"]?.asInt(), 6)
        XCTAssertEqual(sut.data["negIntValue"]?.asInt(), -6)
        XCTAssertEqual(sut.data["largeIntValue"]?.asInt(), 2147483648)
        XCTAssertEqual(sut.data["negLargeIntValue"]?.asInt(), -2147483648)
        XCTAssertEqual(sut.data["floatValue"]?.asDouble(), 50.6)
        XCTAssertEqual(sut.data["negFloatValue"]?.asDouble(), -50.6)
        XCTAssertEqual(sut.data["largeFloatValue"]?.asDouble(), 1.0E+40)
        XCTAssertEqual(sut.data["negLargeFloatValue"]?.asDouble(), -1.0E+40)
        XCTAssertEqual(sut.data["smallFloatValue"]?.asDouble(), 1.0E-40)
        XCTAssertEqual(sut.data["negSmallFloatValue"]?.asDouble(), -1.0E-40)
        XCTAssertEqual(sut.data["boolValue"]?.asBool(), true)
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?.count, 4)
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?[0].asString(), "this")
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?[1].asString(), "is")
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?[2].asString(), "a")
        XCTAssertEqual(sut.data["arrayStringValue"]?.asArray()?[3].asString(), "string")
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?.count, 4)
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?[0].asInt(), 1)
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?[1].asInt(), 2)
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?[2].asInt(), 3)
        XCTAssertEqual(sut.data["arrayIntValue"]?.asArray()?[3].asInt(), 4)
        XCTAssertEqual(sut.data["arrayBoolValue"]?.asArray()?.count, 2)
        XCTAssertEqual(sut.data["arrayBoolValue"]?.asArray()?[0].asBool(), true)
        XCTAssertEqual(sut.data["arrayBoolValue"]?.asArray()?[1].asBool(), false)
        XCTAssertEqual(sut.data["arrayDictValue"]?.asArray()?.count, 1)
        XCTAssertEqual(sut.data["arrayDictValue"]?.asArray()?[0].asDict()?["key"], "value")
        XCTAssertEqual(sut.data["arrayArrayValue"]?.asArray()?.count, 1)
        XCTAssertEqual(sut.data["arrayArrayValue"]?.asArray()?[0].asArray()?[0], "value")
        XCTAssertEqual(sut.data["dictValue"]?.asDict()?["stringValue"]?.asString(), "value")
        XCTAssertEqual(sut.data["dictValue"]?.asDict()?["arrayValue"]?.asArray()?[0], "value")
        XCTAssertEqual(sut.data["dictValue"]?.asDict()?["anotherDict"]?.asDict()?["intValue"]?.asInt(), 7)
        XCTAssertNil(sut.onesignal)
    }
    
    func testProperDecodingOfContentStateWithOneSignalPayload() throws {
        /* Setup */
        let json = """
        {
            "data": {
            },
            "onesignal": {
                "notificationId": "my-notification-id"
            }
        }
        """.data(using: .utf8)!
        
        /* When */
        let decoder = JSONDecoder()
        let sut = try decoder.decode(DefaultLiveActivityAttributes.ContentState.self, from: json)

        /* Then */
        XCTAssertEqual(sut.onesignal?.notificationId, "my-notification-id")
    }
    
    func testProperDecodingOfContentStateWithExtraOneSignalParameters() throws {
        /* Setup */
        let json = """
        {
            "data": {
            },
            "onesignal": {
                "notificationId": "my-notification-id",
                "newAttribute": "newValue",
            }
        }
        """.data(using: .utf8)!
        
        /* When */
        let decoder = JSONDecoder()
        _ = try decoder.decode(DefaultLiveActivityAttributes.ContentState.self, from: json)

        /* Then */
        // not blowing up is a passed test
    }
    
    func testEmptyContentStatePayloadThrowsError() {
        /* Setup */
        let json = """
        {
        }
        """.data(using: .utf8)!
        
        /* When/Then */
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(DefaultLiveActivityAttributes.ContentState.self, from: json))
    }
    
    func testMissingDataInContentStatePayloadThrowsError() {
        /* Setup */
        let json = """
        {
            "notData": {}
        }
        """.data(using: .utf8)!
        
        /* When/Then */
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(DefaultLiveActivityAttributes.ContentState.self, from: json))
    }
}
