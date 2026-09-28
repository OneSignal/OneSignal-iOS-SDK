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

/// Age limits for queued user Requests. Each executor applies them at uncache and at the start of a
/// flush pass, before `prepareForExecution`, so a stale Request goes even if it could send by then.
enum OSRequestAging {
    static let propertyRequestMaxAge: TimeInterval = 60 * 60 * 24 * 90 // 90 days
    static let nonCurrentUserRequestMaxAge: TimeInterval = 60 * 60 * 24 * 30 // 30 days
    static let customEventRequestMaxAge: TimeInterval = 60 * 60 * 24 * 30 // 30 days

    /// The limit for `request`, nil when it never ages out.
    static func maxAge(of request: OSUserRequest, typeLimit: TimeInterval?, currentExternalId: String?) -> TimeInterval? {
        var limit = typeLimit
        if let owner = request.ownerExternalId, owner != currentExternalId {
            limit = min(limit ?? .infinity, nonCurrentUserRequestMaxAge)
        }
        return limit
    }

    /// A timestamp ahead of the clock reads as age zero, so a clock set back does not empty the queues.
    static func age(of request: OneSignalRequest, now: Date) -> TimeInterval {
        return max(0, now.timeIntervalSince(request.timestamp))
    }

    /// The `external_id` of the user manager's current user, nil while there is none.
    static var currentExternalId: String? {
        return OneSignalUserManagerImpl.sharedInstance._user?.identityModel.externalId
    }
}

extension Array where Element: OSUserRequest {
    /// Removes every Request past its age limit. Returns whether any went, so the caller can rewrite its cache key.
    mutating func removeStaleRequests(typeLimit: TimeInterval?, now: Date, currentExternalId: String?, executor: String) -> Bool {
        let countBefore = count
        removeAll { request in
            guard let limit = OSRequestAging.maxAge(of: request, typeLimit: typeLimit, currentExternalId: currentExternalId) else {
                return false
            }
            let age = OSRequestAging.age(of: request, now: now)
            guard age > limit else {
                return false
            }
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "\(executor) dropped \(type(of: request)) owned by \(request.ownerExternalId ?? "nobody"), \(Int(age / 86_400)) days old")
            return true
        }
        return count != countBefore
    }
}
