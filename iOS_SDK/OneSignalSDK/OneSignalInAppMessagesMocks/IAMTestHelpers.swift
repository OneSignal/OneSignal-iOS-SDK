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

import Foundation
import OneSignalInAppMessages

let OS_TEST_MESSAGE_ID = "a4b3gj7f-d8cc-11e4-bed1-df8f05be55ba"
let OS_TEST_MESSAGE_VARIANT_ID = "m8dh7234f-d8cc-11e4-bed1-df8f05be55ba"
let OS_TEST_ENGLISH_VARIANT_ID = "11e4-bed1-df8f05be55ba-m8dh7234f-d8cc"

let OS_DUMMY_HTML = "<html><h1>Hello World</h1></html>"

@objc
public class IAMTestHelpers: NSObject {
    
    static var messageIdIncrementer = 0

    /// Convert OSTriggerOperatorType enum to string
    private static func OS_OPERATOR_TO_STRING(_ type: Int32) -> String {
        // Trigger operator strings
        let OS_OPERATOR_STRINGS: [String] = [
            "greater",
            "less",
            "equal",
            "not_equal",
            "less_or_equal",
            "greater_or_equal",
            "exists",
            "not_exists",
            "in"
        ]

        return OS_OPERATOR_STRINGS[Int(type)]
    }

    /// Returns the JSON of a minimal in-app message that can be used as a building block.
    @objc
    public static func defaultMessageJson() -> [String: Any] {
        messageIdIncrementer += 1
        return [
            "id": String(format: "%@_%i", OS_TEST_MESSAGE_ID, messageIdIncrementer),
            "variants": [
                "ios": [
                    "default": OS_TEST_MESSAGE_VARIANT_ID,
                    "en": OS_TEST_ENGLISH_VARIANT_ID
                ],
                "all": [
                    "default": "should_never_be_used_by_any_test"
                ]
            ],
            "triggers": []
        ]
    }

    /// Returns the JSON of an in-app message with trigger.
    @objc
    public static func messageWithTriggerJson(property: String, triggerId: String, type: Int32, value: Any) -> [String: Any] {
        var testMessage = self.defaultMessageJson()

        testMessage["triggers"] = [
            [
                [
                    "kind": property,
                    "property": property,
                    "operator": OS_OPERATOR_TO_STRING(type),
                    "value": value,
                    "id": triggerId
                ]
            ]
        ]
        return testMessage
    }

    @objc
    public static func fetchMessagesResponse(messages: [[String: Any]]) -> [String: Any] {
        return [
            "in_app_messages": messages
        ]
    }
    
    /// Returns the JSON of a preview or test in-app message.
    @objc
    public static func testMessagePreviewJson() -> [String: Any] {
        var message = self.defaultMessageJson()
        message["is_preview"] = true
        return message
    }
}
