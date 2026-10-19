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

/// Keys of the value an `OS_CREATE_SESSION_DELTA` or `OS_UPDATE_SESSION_DELTA` carries. The Delta's
/// `property` is the local session ID.
enum OSSessionDeltaKey {
    static let appId = "app_id"
    static let startTime = "start_time"
    static let directAttributionId = "direct_attribution_id"
    static let activeDuration = "active_duration"
    static let endTime = "end_time"
    static let onesignalId = "onesignal_id"
    static let subscriptionId = "subscription_id"
}

/// What a session's create sent and got back. Its updates must carry exactly these IDs.
struct OSCreatedSession {
    let serverSessionId: String
    let onesignalId: String
    let subscriptionId: String
}

/// RFC 3339 in UTC with milliseconds, e.g. `2023-11-14T22:13:20.000Z`.
enum OSSessionTimestamp {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

/// A sessions API Request, sent and retried by `OSSessionOperationExecutor`.
protocol OSSessionRequest: OSUserRequest {
    /// The app the session was recorded for. A Request for any other app is dropped.
    var appId: String { get }
    /// `OSSessionRecord.sessionId`, which stands in for the backend session ID until the create succeeds.
    var localSessionId: String { get }
    var identityModel: OSIdentityModel { get set }
}

/// `POST apps/{app_id}/sessions`
final class OSRequestCreateSession: OneSignalRequest, OSSessionRequest {
    var sentToClient = false
    let appId: String
    let localSessionId: String
    let startTime: Date
    let directAttributionId: String?
    var identityModel: OSIdentityModel
    /// See the ownership convention in `OSUserRequest.swift`.
    let ownerExternalId: String?
    /// Fixed by the first send, since the backend does not allow them to change.
    private(set) var onesignalId: String?
    private(set) var subscriptionId: String?
    var missingSessionIdAttempts = 0

    /// The sessions API takes no user JWT.
    var sendsUnsigned: Bool { true }

    override var description: String {
        "<OSRequestCreateSession for session \(localSessionId)>"
    }

    init(
        appId: String,
        localSessionId: String,
        startTime: Date,
        directAttributionId: String?,
        identityModel: OSIdentityModel,
        ownerExternalId: String?,
        onesignalId: String?,
        subscriptionId: String?
    ) {
        self.appId = appId
        self.localSessionId = localSessionId
        self.startTime = startTime
        self.directAttributionId = directAttributionId
        self.identityModel = identityModel
        self.ownerExternalId = ownerExternalId
        self.onesignalId = onesignalId
        self.subscriptionId = subscriptionId
        super.init()
        self.method = POST
    }

    /// Falls back to the user once the backend creates it. The push subscription is the same device
    /// subscription across logins, so it falls back to the current one.
    func prepareForExecution(newRecordsState: OSNewRecordsState, auth: OSRequestAuthorizing) -> Bool {
        guard let onesignalId = onesignalId ?? identityModel.onesignalId,
              let subscriptionId = subscriptionId ?? OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModel?.subscriptionId,
              newRecordsState.canAccess(onesignalId),
              newRecordsState.canAccess(subscriptionId),
              auth.authorize(self)
        else {
            return false
        }
        self.onesignalId = onesignalId
        self.subscriptionId = subscriptionId
        var parameters: [String: Any] = [
            "onesignal_id": onesignalId,
            "subscription_id": subscriptionId,
            "device_type": DEVICE_TYPE_PUSH,
            "start_time": OSSessionTimestamp.string(from: startTime),
            // The local session ID, so a create replayed from any process returns the same session.
            "idempotency_key": localSessionId
        ]
        parameters["direct_attribution_id"] = directAttributionId
        self.parameters = parameters
        self.path = "apps/\(appId)/sessions"
        return true
    }

    func encode(with coder: NSCoder) {
        coder.encode(appId, forKey: "appId")
        coder.encode(localSessionId, forKey: "localSessionId")
        coder.encode(startTime, forKey: "startTime")
        coder.encode(directAttributionId, forKey: "directAttributionId")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(ownerExternalId, forKey: "ownerExternalId")
        coder.encode(onesignalId, forKey: "onesignalId")
        coder.encode(subscriptionId, forKey: "subscriptionId")
        coder.encode(missingSessionIdAttempts, forKey: "missingSessionIdAttempts")
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard let appId = coder.decodeObject(forKey: "appId") as? String,
              let localSessionId = coder.decodeObject(forKey: "localSessionId") as? String,
              let startTime = coder.decodeObject(forKey: "startTime") as? Date,
              let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
              let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            return nil
        }
        self.appId = appId
        self.localSessionId = localSessionId
        self.startTime = startTime
        self.directAttributionId = coder.decodeObject(forKey: "directAttributionId") as? String
        self.identityModel = identityModel
        self.ownerExternalId = coder.decodeObject(forKey: "ownerExternalId") as? String
        self.onesignalId = coder.decodeObject(forKey: "onesignalId") as? String
        self.subscriptionId = coder.decodeObject(forKey: "subscriptionId") as? String
        self.missingSessionIdAttempts = coder.decodeInteger(forKey: "missingSessionIdAttempts")
        super.init()
        self.method = POST
        self.timestamp = timestamp
    }
}

/// `PATCH apps/{app_id}/sessions/{session_id}`
final class OSRequestUpdateSession: OneSignalRequest, OSSessionRequest {
    var sentToClient = false
    let appId: String
    let localSessionId: String
    /// Set by the executor from its session state before each send, so it is not persisted.
    var createdSession: OSCreatedSession?
    /// Cumulative for the whole session, so a retried or reordered update cannot double count.
    var activeDuration: TimeInterval
    /// Set only on the update that ends the session.
    let endTime: Date?
    var identityModel: OSIdentityModel
    /// See the ownership convention in `OSUserRequest.swift`.
    let ownerExternalId: String?
    /// Generated once and persisted, so every retry, including after a restart, is deduplicated by the backend.
    let idempotencyKey: String

    /// The sessions API takes no user JWT.
    var sendsUnsigned: Bool { true }

    var isEnd: Bool { endTime != nil }

    override var description: String {
        "<OSRequestUpdateSession \(isEnd ? "ending" : "for") session \(localSessionId)>"
    }

    init(
        appId: String,
        localSessionId: String,
        activeDuration: TimeInterval,
        endTime: Date?,
        identityModel: OSIdentityModel,
        ownerExternalId: String?
    ) {
        self.appId = appId
        self.localSessionId = localSessionId
        self.activeDuration = activeDuration
        self.endTime = endTime
        self.identityModel = identityModel
        self.ownerExternalId = ownerExternalId
        self.idempotencyKey = UUID().uuidString
        super.init()
        self.method = PATCH
    }

    /// Waits out the post-create delay on the server session ID, so the backend has the session first.
    func prepareForExecution(newRecordsState: OSNewRecordsState, auth: OSRequestAuthorizing) -> Bool {
        guard let createdSession,
              let sessionIdSegment = OSUrlPath.segment(createdSession.serverSessionId),
              newRecordsState.canAccess(createdSession.serverSessionId),
              auth.authorize(self)
        else {
            return false
        }
        var parameters: [String: Any] = [
            "onesignal_id": createdSession.onesignalId,
            "subscription_id": createdSession.subscriptionId,
            "duration_seconds": Int64(activeDuration),
            "idempotency_key": idempotencyKey
        ]
        if let endTime {
            parameters["end_time"] = OSSessionTimestamp.string(from: endTime)
        }
        self.parameters = parameters
        self.path = "apps/\(appId)/sessions/\(sessionIdSegment)"
        return true
    }

    func encode(with coder: NSCoder) {
        coder.encode(appId, forKey: "appId")
        coder.encode(localSessionId, forKey: "localSessionId")
        coder.encode(activeDuration, forKey: "activeDuration")
        coder.encode(endTime, forKey: "endTime")
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(ownerExternalId, forKey: "ownerExternalId")
        coder.encode(idempotencyKey, forKey: "idempotencyKey")
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard let appId = coder.decodeObject(forKey: "appId") as? String,
              let localSessionId = coder.decodeObject(forKey: "localSessionId") as? String,
              let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
              let idempotencyKey = coder.decodeObject(forKey: "idempotencyKey") as? String,
              let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            return nil
        }
        self.appId = appId
        self.localSessionId = localSessionId
        self.activeDuration = coder.decodeDouble(forKey: "activeDuration")
        self.endTime = coder.decodeObject(forKey: "endTime") as? Date
        self.identityModel = identityModel
        self.ownerExternalId = coder.decodeObject(forKey: "ownerExternalId") as? String
        self.idempotencyKey = idempotencyKey
        super.init()
        self.method = PATCH
        self.timestamp = timestamp
    }
}
