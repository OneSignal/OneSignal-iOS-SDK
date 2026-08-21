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

/// Shared path-segment encoding for Swift and ObjC request builders.
@objc(OSUrlPath)
public final class OSUrlPath: NSObject {
    /**
     Returns `value` percent-encoded for use as one path segment, or nil if it cannot be encoded.

     `urlUserAllowed` rather than `urlPathAllowed`, which leaves `/` alone: the values the SDK
     interpolates into a path — `external_id`, alias labels, Live Activity types — come from the app,
     and one containing a slash, `?`, `#` or `%` would otherwise reach a different endpoint than intended.

     Encode once, where the path is built. A value that has already been through this comes back with its
     `%` escaped again.
     */
    @objc(segment:)
    public static func segment(_ value: String) -> String? {
        return value.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed)
    }
}
