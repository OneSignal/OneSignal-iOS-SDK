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

/**
 Internal listener.
 */
public protocol OSUserJwtConfigListener {
    func onUserAuthChanged(from: Bool?, to: Bool?)
    func onJwtInvalidated(externalId: String, error: String?)
    func onJwtUpdated(externalId: String, jwtToken: String)
    func onJwtTokenChanged(externalId: String, from: String?, to: String?)
}

public class OSUserJwtConfig {
    public var requiresUserAuth: OSRequiresUserAuth {
        didSet {
            let prevRequired = oldValue.isRequired()
            let newRequired = requiresUserAuth.isRequired()
            guard prevRequired != newRequired else {
                return
            }
            
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "💛 OSUserJwtConfig.requiresUserAuth: changing from \(oldValue) to \(requiresUserAuth)")
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "💛 OSUserJwtConfig firing \(changeNotifier)")

            // Persist
            OneSignalUserDefaults.initShared().saveString(forKey: OSUD_USE_IDENTITY_VERIFICATION, withValue: requiresUserAuth.rawValue)
            
            self.changeNotifier.fire { listener in
                listener.onUserAuthChanged(from: prevRequired, to: newRequired)
            }
        }
    }
    
    public let changeNotifier = OSEventProducer<OSUserJwtConfigListener>()
    
    public init() {
        let rawValue = OneSignalUserDefaults.initShared().getSavedString(forKey: OSUD_USE_IDENTITY_VERIFICATION, defaultValue: "unknown")
        print("❌ OSUserJwtConfig init rawValue \(rawValue)")
        print("❌ OSUserJwtConfig init OSRequiresUserAuth \(OSRequiresUserAuth(rawValue: rawValue!))")

        if let rawValue = OneSignalUserDefaults.initShared().getSavedString(forKey: OSUD_USE_IDENTITY_VERIFICATION, defaultValue: "unknown"),
           let requires = OSRequiresUserAuth(rawValue: rawValue)
        {
            requiresUserAuth = requires
        } else {
            requiresUserAuth = OSRequiresUserAuth.unknown
        }
    }
    
    public func isRequired() -> Bool? {
        return switch requiresUserAuth {
        case .onViaRemoteParams:
            true
        case .offViaRemoteParams:
            false
        default:
            nil
        }
    }
    
    public func onJwtTokenChanged(externalId: String, from: String?, to: String?) {
        if (to == "invalid") {
            changeNotifier.fire { listener in
                listener.onJwtInvalidated(externalId: externalId, error: nil)
            }
        }
    }
}
