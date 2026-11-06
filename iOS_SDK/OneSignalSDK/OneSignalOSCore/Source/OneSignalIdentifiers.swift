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

/// Durable accessors for OneSignal identifiers persisted to shared UserDefaults.
/// Useful when the in-memory source isn't available, notably the NSE process
///
/// Callers with access to the in-memory current value (main-app SDK code)
/// should continue to use that source
@objc(OneSignalIdentifiers)
public final class OneSignalIdentifiers: NSObject {

    private static let lock = NSLock()
    private static var _currentAppId: String?

    /// The current in-memory `app_id`, set by `OneSignal.initialize`.
    /// nil before `initialize` has been called (or in a process like the NSE that
    /// never calls `initialize` — use `storedAppId` there).
    @objc public static var currentAppId: String? {
        get { lock.withLock { _currentAppId } }
        set { lock.withLock { _currentAppId = newValue } }
    }

    /// Persisted `app_id` from shared UserDefaults first, then the unencrypted `OSResilientStorage` mirror,
    /// covering the prewarm-before-first-unlock window where UserDefaults is locked and silently returns nil.
    @objc public static var storedAppId: String? {
        if let fromUD = OneSignalUserDefaults.initShared().getSavedString(forKey: OSUD_APP_ID, defaultValue: nil),
           !fromUD.isEmpty {
            return fromUD
        }
        return OSResilientStorage.string(forKey: OSResilientStorage.keyAppId)
    }

    /// Persisted push `subscription_id` from shared UserDefaults first, then the unencrypted `OSResilientStorage` mirror.
    @objc public static var subscriptionId: String? {
        if let fromUD = OneSignalUserDefaults.initShared().getSavedString(forKey: OSUD_PUSH_SUBSCRIPTION_ID, defaultValue: nil),
           !fromUD.isEmpty {
            return fromUD
        }
        return OSResilientStorage.string(forKey: OSResilientStorage.keySubscriptionId)
    }

    /// Persisted `onesignal_id` of the current user from shared UserDefaults, written by the user module on hydration.
    /// After an ordinary `login` or `logout` it keeps the previous user's id until the new Create User response lands,
    /// with no time limit while an Identity Verification login waits for a JWT. `logout` under Identity Verification
    /// clears it at once. No `OSResilientStorage` mirror, so nil while UserDefaults is locked.
    @objc public static var onesignalId: String? {
        guard let fromUD = OneSignalUserDefaults.initShared().getSavedString(forKey: OS_SNAPSHOT_ONESIGNAL_ID, defaultValue: nil),
              !fromUD.isEmpty else {
            return nil
        }
        return fromUD
    }
}
