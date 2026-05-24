/**
 * Modified MIT License
 *
 * Copyright 2024 OneSignal
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

/// Single source of truth for the demo's OneSignal credentials. Mirrors the
/// Capacitor demo's `.env` (`ONESIGNAL_APP_ID`, `ONESIGNAL_API_KEY`) but reads
/// values from `Secrets.plist` bundled with the app — the iOS-idiomatic
/// equivalent. Both keys are optional; consumers fall back to platform defaults
/// when missing.
enum SecretsConfig {

    /// Hard-coded fallback when `ONESIGNAL_APP_ID` is missing or empty in
    /// `Secrets.plist`. Matches the default in `sdk-shared/demo/build.md`.
    static let defaultAppId = "77e32082-ea27-42e3-a898-c72e141824ef"

    /// Resolved OneSignal App ID. Reads `ONESIGNAL_APP_ID` from `Secrets.plist`
    /// and falls back to `defaultAppId` when missing or empty.
    static var appId: String {
        string(forKey: "ONESIGNAL_APP_ID") ?? defaultAppId
    }

    /// Resolved REST API key, if any. Required for Live Activity update/end.
    static var apiKey: String? { string(forKey: "ONESIGNAL_API_KEY") }

    /// Convenience used by the Live Activity section to disable update/end
    /// buttons when no key is configured.
    static var hasApiKey: Bool { apiKey != nil }

    private static let cache: [String: Any] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil
            ) as? [String: Any]
        else {
            return [:]
        }
        return plist
    }()

    private static func string(forKey key: String) -> String? {
        guard let value = cache[key] as? String, !value.isEmpty else { return nil }
        return value
    }
}
