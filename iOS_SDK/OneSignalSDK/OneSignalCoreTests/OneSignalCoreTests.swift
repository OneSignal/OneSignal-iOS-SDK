/*
 Modified MIT License
 
 Copyright 2023 OneSignal
 
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

final class OneSignalCoreTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /**
     Pre-existing test on player model.
     This test was moved here to set up and test this Core Test module.
     */
    func testNotificationJson() throws {
        let aps = [
            "aps": [
                "content-available": 1,
                "mutable-content": 1,
                "alert": "Message Body",
                "relevance-score": 0.15,
                "interruption-level": "time-sensitive"
            ],
            "os_data": [
                "i": "notif id",
                "ti": "templateId123",
                "tn": "Template name"
            ]]
        let notification: OSNotification = try XCTUnwrap(OSNotification.parse(withApns: aps))
        let json = notification.jsonRepresentation()

        let notificationId: String = try XCTUnwrap(json["notificationId"]) as! String
        let contentAvailable: Bool = try XCTUnwrap(json["contentAvailable"]) as! Bool
        let mutableContent: Bool = try XCTUnwrap(json["mutableContent"]) as! Bool
        let body: String = try XCTUnwrap(json["body"]) as! String
        let templateId: String = try XCTUnwrap(json["templateId"]) as! String
        let templateName: String = try XCTUnwrap(json["templateName"]) as! String

        XCTAssertEqual(notificationId, "notif id")
        XCTAssertEqual(contentAvailable, true)
        XCTAssertEqual(mutableContent, true)
        XCTAssertEqual(body, "Message Body")
        XCTAssertEqual(templateId, "templateId123")
        XCTAssertEqual(templateName, "Template name")
    }
}
