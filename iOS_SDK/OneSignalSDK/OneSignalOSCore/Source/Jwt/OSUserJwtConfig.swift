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
import OneSignalCore

@objc
public enum OSRequiresUserAuth: Int {
    case on = 1
    case off = -1
    case unknown = 0
    // TODO: JWT 🔐 consider additional reasons such as detecting this by dev calling loginWithJWT / onViaRemoteParams

    func isRequired() -> Bool? {
        return switch self {
        case .on:
            true
        case .off:
            false
        default:
            nil
        }
    }
}

/**
 Internal listener.
 */
@objc public protocol OSUserJwtConfigListener {
    func onRequiresUserAuthChanged(from: OSRequiresUserAuth, to: OSRequiresUserAuth)
    func onJwtUpdated(externalId: String, token: String?)
}

public class OSUserJwtConfig {
    private let changeNotifier = OSEventProducer<OSUserJwtConfigListener>()

    private var requiresUserAuth: OSRequiresUserAuth {
        didSet {
            guard oldValue != requiresUserAuth else {
                return
            }

            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSUserJwtConfig.requiresUserAuth: changing from \(oldValue) to \(requiresUserAuth), firing listeners")
            // Persist new value
            OneSignalUserDefaults.initShared().saveInteger(forKey: OSUD_USE_IDENTITY_VERIFICATION, withValue: requiresUserAuth.rawValue)

            self.changeNotifier.fire { listener in
                listener.onRequiresUserAuthChanged(from: oldValue, to: requiresUserAuth)
            }
        }
    }

    public var isRequired: Bool? {
        get {
            return requiresUserAuth.isRequired()
        }
        set {
            requiresUserAuth = switch newValue {
            case true:
                OSRequiresUserAuth.on
            case false:
                OSRequiresUserAuth.off
            default:
                OSRequiresUserAuth.unknown
            }
        }
    }

    public init() {
        let rawValue = OneSignalUserDefaults.initShared().getSavedInteger(forKey: OSUD_USE_IDENTITY_VERIFICATION, defaultValue: OSRequiresUserAuth.unknown.rawValue)
        requiresUserAuth = OSRequiresUserAuth(rawValue: rawValue) ?? OSRequiresUserAuth.unknown
    }

    public func subscribe(_ listener: OSUserJwtConfigListener, key: String) {
        self.changeNotifier.subscribe(listener, key: key)
    }

    public func onJwtTokenChanged(externalId: String, token: String?) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OSUserJwtConfig.onJwtTokenChanged for \(externalId) with token \(token ?? "nil"), firing listeners")
        changeNotifier.fire { listener in
            listener.onJwtUpdated(externalId: externalId, token: token)
        }
    }
}
