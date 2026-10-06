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
import OneSignalCore

@objc(OSInputGuard)
public final class OSInputGuard: NSObject {
    @objc(isMissing:api:)
    public static func isMissing(_ value: String?, _ api: String) -> Bool {
        // A NUL cannot be stored in a text column, so it is never a usable value.
        if let value, value.contains("\u{0000}") {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "\(api) contains a null byte")
            return true
        }
        if let value, !value.isEmpty {
            return false
        }
        OneSignalLog.onesignalLog(.LL_ERROR, message: "\(api) is required")
        return true
    }

    @objc(isMissingAny:api:)
    public static func isMissingAny(_ values: NSArray?, _ api: String) -> Bool {
        guard let values else {
            return isMissing(nil, api)
        }
        for item in values where isMissing(item as? String, api) {
            return true
        }
        return false
    }

    /// `allowEmptyValue` keeps "" and a value containing a null byte. A null value is still rejected.
    @objc(hasMissingEntries:api:allowEmptyValue:)
    public static func hasMissingEntries(
        _ values: NSDictionary?,
        _ api: String,
        allowEmptyValue: Bool
    ) -> Bool {
        guard let values else {
            return isMissing(nil, api)
        }
        for (key, item) in values {
            if isMissing(key as? String, "\(api): key") {
                return true
            }
            if allowEmptyValue {
                if item is NSNull {
                    return isMissing(nil, "\(api): value")
                }
                continue
            }
            if isMissing(item as? String, "\(api): value") {
                return true
            }
        }
        return false
    }

    @nonobjc
    public static func isMissingAny(_ values: [String]?, _ api: String) -> Bool {
        isMissingAny(values as NSArray?, api)
    }

    @nonobjc
    public static func hasMissingEntries(
        _ values: [String: String]?,
        _ api: String,
        allowEmptyValue: Bool
    ) -> Bool {
        hasMissingEntries(values as NSDictionary?, api, allowEmptyValue: allowEmptyValue)
    }
}
