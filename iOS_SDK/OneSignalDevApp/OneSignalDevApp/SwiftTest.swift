/**
 * Modified MIT License
 *
 * Copyright 2022 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
import OneSignalFramework

class SwiftTest: NSObject, OSLogListener {
    func onLogEvent(_ event: OneSignalLogEvent) {
        print("Dev App onLogEvent: \(event.level) - \(event.entry)")
    }

    func testSwiftUserModel() {
        let token1 = OneSignal.User.pushSubscription.token
        let token = OneSignal.User.pushSubscription.token
        OneSignal.Debug.addLogListener(self)
        OneSignal.Debug.removeLogListener(self)
    }

    /**
     Track multiple events with different properties.
     Properties must pass `JSONSerialization.isValidJSONObject` to be accepted.
     */
    @objc
    static func trackCustomEvents() {
        print("Dev App: track an event with nil properties")
        OneSignal.User.trackEvent(name: "null properties", properties: nil)

        print("Dev App: track an event with empty properties")
        OneSignal.User.trackEvent(name: "empty properties", properties: [:])

        let formatter = DateFormatter()
        formatter.dateStyle = .short

        let mixedTypes = [
            "string": "somestring",
            "number": 5,
            "bool": false,
            "dateStr": formatter.string(from: Date())
        ] as [String: Any]

        let nestedDict = [
            "someDict": mixedTypes,
            "anotherDict": [
                "foo": "bar",
                "booleanVal": true,
                "float": Float("3.14")!
            ]
        ]
        let invalidProperties = ["date": Date()]

        print("Dev App: track an event with a valid nested dictionary")
        OneSignal.User.trackEvent(name: "nested dictionary", properties: nestedDict)

        print("Dev App: track an event with invalid dictionary types")
        OneSignal.User.trackEvent(name: "invalid dictionary", properties: invalidProperties)
    }
}
