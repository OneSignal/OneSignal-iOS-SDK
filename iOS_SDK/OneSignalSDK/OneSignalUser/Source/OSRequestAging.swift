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
import OneSignalOSCore

/// Age limits for queued user Requests. Each executor applies them at uncache and at the start of a
/// flush pass, before `prepareForExecution`, so a stale Request is dropped even if it could send by then.
enum OSRequestAging {
    static let propertyRequestMaxAge: TimeInterval = 60 * 60 * 24 * 90 // 90 days
    static let nonCurrentUserRequestMaxAge: TimeInterval = 60 * 60 * 24 * 30 // 30 days
    static let customEventRequestMaxAge: TimeInterval = 60 * 60 * 24 * 30 // 30 days

    /// The `external_id` of the current user, nil while there is none. Reads `_user`, since `user` calls
    /// `start()` and would deadlock at uncache.
    static var currentExternalId: String? {
        return OneSignalUserManagerImpl.sharedInstance._user?.identityModel.externalId
    }

    /// The limit for work owned by `owner`, nil when it never ages out.
    static func maxAge(owner: String?, typeLimit: TimeInterval?, currentExternalId: String?) -> TimeInterval? {
        var limit = typeLimit
        if let owner = owner, owner != currentExternalId {
            limit = min(limit ?? .infinity, nonCurrentUserRequestMaxAge)
        }
        return limit
    }

    /// The age at which work with `timestamp` is dropped, nil to keep it. A timestamp ahead of the clock has no age.
    static func staleAge(timestamp: Date, owner: String?, typeLimit: TimeInterval?, now: Date, currentExternalId: String?) -> TimeInterval? {
        guard let limit = maxAge(owner: owner, typeLimit: typeLimit, currentExternalId: currentExternalId) else {
            return nil
        }
        let age = now.timeIntervalSince(timestamp)
        return age > limit ? age : nil
    }

    static func logDrop(of item: String, owner: String?, age: TimeInterval, executor: String) {
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "\(executor) dropped \(item) owned by \(owner ?? "nil"), \(Int(age / 86_400)) days old")
    }
}

extension Array where Element: OSUserRequest {
    /// Removes every Request past its age limit. Returns whether any were dropped, so the caller can rewrite its cache entry.
    mutating func removeStaleRequests(typeLimit: TimeInterval?, now: Date, currentExternalId: String?, executor: String) -> Bool {
        let countBefore = count
        removeAll { request in
            guard let age = OSRequestAging.staleAge(timestamp: request.timestamp, owner: request.ownerExternalId, typeLimit: typeLimit, now: now, currentExternalId: currentExternalId) else {
                return false
            }
            OSRequestAging.logDrop(of: "\(type(of: request))", owner: request.ownerExternalId, age: age, executor: executor)
            return true
        }
        return count != countBefore
    }
}

extension Array where Element == OSDelta {
    /// The same for Deltas, which the custom events executor holds until their user has an `onesignal_id`.
    mutating func removeStaleDeltas(typeLimit: TimeInterval?, now: Date, currentExternalId: String?, executor: String) -> Bool {
        let countBefore = count
        removeAll { delta in
            guard let age = OSRequestAging.staleAge(timestamp: delta.timestamp, owner: delta.externalId, typeLimit: typeLimit, now: now, currentExternalId: currentExternalId) else {
                return false
            }
            OSRequestAging.logDrop(of: "\(delta.name) Delta", owner: delta.externalId, age: age, executor: executor)
            return true
        }
        return count != countBefore
    }
}
