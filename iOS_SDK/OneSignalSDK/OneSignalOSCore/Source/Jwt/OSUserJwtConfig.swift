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

/**
 Whether the app requires Identity Verification, mirroring the `jwt_required` remote param.
 `unknown` has to stay distinguishable from `off` so nothing is sent unsigned on behalf of an app
 that turns out to require auth.
 */
public enum OSRequiresUserAuth: Int {
    // Raw values are cached, and 0 is what UserDefaults returns for a missing integer, so `unknown` owns it.
    case on = 1
    case off = -1
    case unknown = 0
}

/**
 Holds the Identity Verification requirement and caches it across launches.
 Deliberately knows nothing about gating: `OSIdentityVerificationService` makes every such decision
 and is the only observer here.
 */
public final class OSUserJwtConfig {
    private let lock = NSLock()
    private var _requirement: OSRequiresUserAuth
    private var onHydrated: ((OSRequiresUserAuth) -> Void)?

    public var requirement: OSRequiresUserAuth {
        return lock.withLock { _requirement }
    }

    public init() {
        _requirement = OSUserJwtConfig.cachedRequirement()
    }

    /**
     Applies the requirement carried by a successful remote params response. A response that omits
     `jwt_required` means the app has Identity Verification off, so callers pass `false` for it rather
     than leaving the requirement unknown.
     */
    public func hydrate(requiresUserAuth: Bool) {
        let hydrated: OSRequiresUserAuth = requiresUserAuth ? .on : .off
        // Keep the log and the handler out of the lock; either can re-enter and read the requirement.
        let (previous, handler) = lock.withLock { () -> (OSRequiresUserAuth, ((OSRequiresUserAuth) -> Void)?) in
            let previous = _requirement
            if previous != hydrated {
                _requirement = hydrated
                OneSignalUserDefaults.initShared().saveInteger(forKey: OSUD_USE_IDENTITY_VERIFICATION, withValue: hydrated.rawValue)
            }
            return (previous, onHydrated)
        }
        if previous != hydrated {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSUserJwtConfig requirement changed from \(previous) to \(hydrated)")
        }
        // Fires even when the value is unchanged, because work deferred while the requirement was
        // unknown is waiting on this to run.
        handler?(hydrated)
    }

    /**
     Re-reads the cached requirement while it is still unknown. The read in `init` can land during an
     app prewarm, before first unlock, when UserDefaults silently returns nothing.
     */
    public func refreshIfUnknown() {
        lock.withLock {
            guard _requirement == .unknown else {
                return
            }
            _requirement = OSUserJwtConfig.cachedRequirement()
        }
    }

    /// The Identity Verification service is the sole observer, so a second registration replaces the first.
    func setOnHydratedHandler(_ handler: ((OSRequiresUserAuth) -> Void)?) {
        lock.withLock { onHydrated = handler }
    }

    private static func cachedRequirement() -> OSRequiresUserAuth {
        let rawValue = OneSignalUserDefaults.initShared().getSavedInteger(forKey: OSUD_USE_IDENTITY_VERIFICATION,
                                                                         defaultValue: OSRequiresUserAuth.unknown.rawValue)
        return OSRequiresUserAuth(rawValue: rawValue) ?? .unknown
    }
}
