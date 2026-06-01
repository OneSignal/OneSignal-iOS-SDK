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

/// SDK-level configuration / readiness predicates
@objc(OneSignalConfig)
public final class OneSignalConfig: NSObject {

    /// Optional readability check for device-protected storage.
    ///
    /// Set-once invariant: the main app assigns this exactly once during `OneSignal.init`,
    /// inside a `dispatch_once`. The assignment is the publishing side and `dispatch_once`
    /// is a memory barrier, so concurrent readers via `shouldAwait…` observe a stable closure.
    /// The closure itself must be cheap and thread-safe — the main app implements it as an
    /// atomic-BOOL load fed by `UIApplicationProtectedData{Did,Will}BecomeAvailable` so we
    /// never touch the main-thread-only `UIApplication` from arbitrary callers.
    ///
    /// Left nil in app-extension contexts (NSE) since `UIApplication` is unavailable there.
    /// When nil the predicate treats protected data as available — the right default for NSE,
    /// which reads identifiers through `OSResilientStorage` (file-backed, bypasses cfprefsd).
    @objc public static var isProtectedDataAvailableProvider: (() -> Bool)?

    /// Returns true when the SDK shouldn't perform an operation yet because:
    ///   * `app_id` hasn't been set via `OneSignal.initialize`, or
    ///   * the host app hasn't granted privacy consent, or
    ///   * device storage isn't readable yet (iOS prewarm before first unlock).
    @objc public static func shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod methodName: String?) -> Bool {
        var shouldAwait = false
        if OneSignalIdentifiers.currentAppId == nil {
            if let methodName {
                OneSignalLog.onesignalLog(.LL_WARN, message: "Your application has called \(methodName) before app ID has been set. Please call `initialize:appId withLaunchOptions:launchOptions` in order to set the app ID")
            }
            shouldAwait = true
        }
        if OSPrivacyConsentController.shouldLogMissingPrivacyConsentError(withMethodName: methodName) {
            shouldAwait = true
        }
        if let provider = isProtectedDataAvailableProvider, !provider() {
            if let methodName {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "\(methodName) deferred: device-protected storage is not yet available (iOS prewarm before first unlock).")
            }
            shouldAwait = true
        }
        return shouldAwait
    }
}
