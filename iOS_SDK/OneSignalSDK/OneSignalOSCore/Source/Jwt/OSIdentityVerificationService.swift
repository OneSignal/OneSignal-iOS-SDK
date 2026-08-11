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

/// Who is waiting on hydration. Keyed so re-registering replaces rather than stacking a duplicate.
public enum OSJwtConfigHydratedObserver {
    case userExecutor
    case operationRepo
    case userManager
}

/**
 Decides Identity Verification gating from the rollout feature flag and the app's `jwt_required`
 setting.

 - `ivBehaviorActive`: whether IV behavior is in effect (JWT on requests, `external_id` alias, 401
   handling).
 - `newCodePathsRun`: whether IV code paths should run at all (feature flag, or always when the app
   requires auth).
 - `requirement`: use when you must tell `unknown` apart from `off` — both booleans are `false` while
   the requirement is unknown, which is fine for apps that do not require Identity Verification, but
   callers that must not send an unsigned request should wait until it is known.
 */
public final class OSIdentityVerificationService {
    private let featureManager: OSFeatureManagerProtocol
    private let jwtConfig: OSUserJwtConfig

    private let handlerLock = NSLock()
    // Ordered by registration: User executor's held Create User before Deltas that need its onesignal_id.
    private var jwtConfigHydratedHandlers: [(observer: OSJwtConfigHydratedObserver, handler: (OSRequiresUserAuth) -> Void)] = []

    /// The raw `jwt_required` value, including `unknown` before remote params arrive.
    public var requirement: OSRequiresUserAuth {
        return jwtConfig.requirement
    }

    /// Whether Identity Verification behavior applies: JWT on requests, `external_id` alias, 401 handling.
    public var ivBehaviorActive: Bool {
        return jwtConfig.requirement == .on
    }

    /// Whether the new Identity Verification code paths run at all. An app that requires auth is always in,
    /// no matter how the rollout flag is set.
    public var newCodePathsRun: Bool {
        return featureManager.isEnabled(.identityVerification) || ivBehaviorActive
    }

    public init(featureManager: OSFeatureManagerProtocol, jwtConfig: OSUserJwtConfig) {
        self.featureManager = featureManager
        self.jwtConfig = jwtConfig
        jwtConfig.setOnHydratedHandler { [weak self] requirement in
            self?.fireJwtConfigHydrated(requirement)
        }
    }

    /**
     Fires on every hydration, including an unchanged value — deferred work waits on that. A handler
     registered after `requirement` is already known runs immediately, since that hydration is not repeated.
     */
    public func addOnJwtConfigHydratedHandler(for observer: OSJwtConfigHydratedObserver, _ handler: @escaping (OSRequiresUserAuth) -> Void) {
        handlerLock.withLock {
            if let index = jwtConfigHydratedHandlers.firstIndex(where: { $0.observer == observer }) {
                jwtConfigHydratedHandlers[index] = (observer, handler)
            } else {
                jwtConfigHydratedHandlers.append((observer, handler))
            }
        }

        let alreadyKnown = jwtConfig.requirement
        guard alreadyKnown != .unknown else {
            return
        }
        handler(alreadyKnown)
    }

    public func removeOnJwtConfigHydratedHandler(for observer: OSJwtConfigHydratedObserver) {
        handlerLock.withLock {
            jwtConfigHydratedHandlers.removeAll { $0.observer == observer }
        }
    }

    private func fireJwtConfigHydrated(_ requirement: OSRequiresUserAuth) {
        // Snapshot: a handler can register another, and handlers take locks of their own.
        let handlers = handlerLock.withLock { jwtConfigHydratedHandlers }
        for entry in handlers {
            entry.handler(requirement)
        }
    }
}
