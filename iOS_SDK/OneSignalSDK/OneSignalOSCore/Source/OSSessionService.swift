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
@_implementationOnly import OneSignalKMP

public struct OSSessionUser {
    /// Local ID of the user's identity model. It survives that user being created on the
    /// backend, and every login gets a new one.
    public let identityModelId: String?
    public let onesignalId: String?
    public let pushSubscriptionId: String?

    public init(identityModelId: String?, onesignalId: String?, pushSubscriptionId: String?) {
        self.identityModelId = identityModelId
        self.onesignalId = onesignalId
        self.pushSubscriptionId = pushSubscriptionId
    }
}

/// The user a session belongs to, supplied by the User module.
public protocol OSSessionUserProvider: AnyObject {
    /// Taken from one read of the current user, so a concurrent login cannot mix two users.
    var sessionCurrentUser: OSSessionUser { get }
    func sessionOnesignalId(identityModelId: String) -> String?
}

/// New fields must be Optional. A record stored by an earlier version lacks them, and synthesized
/// decoding fails on a missing non-Optional field even when it has a default value.
public struct OSSessionRecord: Codable, Equatable {
    public let sessionId: String
    /// Seconds since 1970.
    public let startTime: TimeInterval
    /// Foreground time, measured with a monotonic clock so a wall-clock change cannot skew it.
    public internal(set) var activeDuration: TimeInterval
    /// Fixed for the whole session so it never mixes paths. Read this rather than the feature
    /// manager, whose value can change mid-session.
    public let usesSessionsApi: Bool
    public let identityModelId: String?
    /// Pinned at session start, so it stays the same after a login or user switch.
    public internal(set) var onesignalId: String?
    public internal(set) var subscriptionId: String?
    /// Seconds since 1970 when the app last left the foreground. Nil until then.
    public internal(set) var lastUnfocusTime: TimeInterval?
    /// Seconds since 1970 when the app last entered the foreground during this session.
    public internal(set) var lastFocusTime: TimeInterval?

    /// Seconds since 1970. A session killed in the foreground never unfocused, so it ends at its
    /// last focus. The visit the kill cut short is not in the duration either.
    public var endTime: TimeInterval {
        max(startTime, lastUnfocusTime ?? startTime, lastFocusTime ?? startTime)
    }
}

public struct OSSessionStart {
    public let started: OSSessionRecord
    /// The session the new one replaced, which has now ended.
    public let ended: OSSessionRecord?
}

/// Owns the persisted record of the current session. Nothing reads the record while
/// `usesSessionsApi` is false, so with the flag off session behavior is unchanged.
@objc(OSSessionService)
public final class OSSessionService: NSObject {
    private static let lock = NSLock()
    private static var _shared: OSSessionService?

    public static var shared: OSSessionService {
        lock.withLock {
            if let existing = _shared {
                return existing
            }
            let created = OSSessionService()
            _shared = created
            return created
        }
    }

    private let storage: OneSignalUserDefaults
    private let featureManager: () -> OSFeatureManager
    private let monotonicNow: () -> TimeInterval
    private let wallNow: () -> TimeInterval

    private let stateLock = NSLock()
    private weak var userProvider: OSSessionUserProvider?
    private var loaded = false
    private var record: OSSessionRecord?
    /// In memory only: a stamp from another process may predate a reboot.
    private var focusedAt: TimeInterval?
    /// Wall-clock time of the open visit's focus. A visit open when a session starts belongs to it.
    private var openFocusTime: TimeInterval?
    /// A record loaded from disk belongs to an earlier process, so the next focus always replaces it.
    private var recordStartedInThisProcess = false

    init(
        storage: OneSignalUserDefaults = .initStandard(),
        featureManager: @escaping () -> OSFeatureManager = { .shared },
        monotonicNow: @escaping () -> TimeInterval = {
            TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / TimeInterval(NSEC_PER_SEC)
        },
        wallNow: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.storage = storage
        self.featureManager = featureManager
        self.monotonicNow = monotonicNow
        self.wallNow = wallNow
        super.init()
    }

    @objc public static func onFocus() {
        shared.onFocus()
    }

    @objc public static func onUnfocus() {
        shared.onUnfocus()
    }

    @objc public static func reset() {
        lock.withLock { _shared = nil }
    }

    /// The stored record belongs to the previous app, so it must not outlive an app-id change.
    @objc public static func resetAndClearStoredRecord() {
        reset()
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
    }

    public var currentRecord: OSSessionRecord? {
        let ids = pinnableIds()
        return stateLock.withLock {
            loadIfNeeded()
            fillPinnedIds(ids)
            return record
        }
    }

    /// Set at launch, not only when a session starts: a record loaded from disk still needs its IDs
    /// filled in if the previous process exited before the backend assigned them.
    public func setUserProvider(_ userProvider: OSSessionUserProvider) {
        stateLock.withLock { self.userProvider = userProvider }
        refreshPinnedIds()
    }

    /// The User module calls this as soon as the backend assigns a user or subscription ID. Filling
    /// only on the next read could be too late: a login in between switches the current user, and
    /// the subscription can then no longer be attributed to this session's user.
    public func refreshPinnedIds() {
        let ids = pinnableIds()
        stateLock.withLock { fillPinnedIds(ids) }
    }

    /// Leaves any open foreground interval running: the tracker reports focus before the session
    /// starts asynchronously, and that visit belongs to the new session. A launch in the
    /// background has no interval open, so nothing counts until the app becomes active.
    /// The replaced record is returned rather than lost, so its session can be ended.
    @discardableResult
    public func startNewSession(userProvider: OSSessionUserProvider) -> OSSessionStart {
        let previousIds = pinnableIds()
        let user = userProvider.sessionCurrentUser
        var newRecord = OSSessionRecord(
            sessionId: UUID().uuidString,
            startTime: wallNow(),
            activeDuration: 0,
            usesSessionsApi: featureManager().isEnabled(featureKey: FeatureFlag.sdkSessionsV2ApiCutover.key),
            identityModelId: user.identityModelId,
            onesignalId: user.onesignalId,
            subscriptionId: user.pushSubscriptionId
        )
        let ended: OSSessionRecord? = stateLock.withLock {
            loadIfNeeded()
            // Last chance to fill the replaced record's IDs while it is still the current one.
            fillPinnedIds(previousIds)
            let ended = record
            newRecord.lastFocusTime = openFocusTime
            self.userProvider = userProvider
            record = newRecord
            recordStartedInThisProcess = true
            persist()
            return ended
        }
        return OSSessionStart(started: newRecord, ended: ended)
    }

    func onFocus() {
        let now = monotonicNow()
        let wallNow = wallNow()
        stateLock.withLock {
            focusedAt = now
            loadIfNeeded()
            openFocusTime = wallNow
            guard record != nil, focusContinuesRecord(at: wallNow) else {
                return
            }
            // Saved now, since a kill leaves no unfocus to record when the session was last active.
            record?.lastFocusTime = wallNow
            persist()
        }
    }

    /// A focus that will start a new session is not saved on the current record, or a kill before
    /// that session starts would move the current session's end past its last unfocus.
    private func focusContinuesRecord(at time: TimeInterval) -> Bool {
        guard recordStartedInThisProcess, let lastUnfocusTime = record?.lastUnfocusTime else {
            return recordStartedInThisProcess
        }
        return time - lastUnfocusTime < OSSessionStartGate.threshold
    }

    func onUnfocus() {
        let now = monotonicNow()
        let wallNow = wallNow()
        let ids = pinnableIds()
        stateLock.withLock {
            guard let start = focusedAt else {
                return
            }
            focusedAt = nil
            openFocusTime = nil
            loadIfNeeded()
            guard record != nil else {
                return
            }
            record?.activeDuration += max(0, now - start)
            record?.lastUnfocusTime = wallNow
            fillPinnedIds(ids)
            persist()
        }
    }

    private struct PinnableIds {
        let identityModelId: String
        let onesignalId: String?
        let pushSubscriptionId: String?
    }

    /// Read outside `stateLock` because the provider takes the User module's locks.
    private func pinnableIds() -> PinnableIds? {
        let pinned: (OSSessionUserProvider, String)? = stateLock.withLock {
            loadIfNeeded()
            guard let userProvider, let identityModelId = record?.identityModelId else {
                return nil
            }
            return (userProvider, identityModelId)
        }
        guard let (provider, identityModelId) = pinned else {
            return nil
        }
        return PinnableIds(
            identityModelId: identityModelId,
            onesignalId: provider.sessionOnesignalId(identityModelId: identityModelId),
            pushSubscriptionId: provider.sessionCurrentUser.pushSubscriptionId
        )
    }

    /// A session that starts before its user is created has no IDs to pin yet. Fill them in once
    /// the backend assigns them. The onesignal_id is the session's own user's. The push
    /// subscription is the same device subscription across logins, even when a login conflict
    /// moves it to another user, so it is filled from the current one.
    private func fillPinnedIds(_ ids: PinnableIds?) {
        guard let ids, var current = record, current.identityModelId == ids.identityModelId else {
            return
        }
        if current.onesignalId == nil {
            current.onesignalId = ids.onesignalId
        }
        if current.subscriptionId == nil {
            current.subscriptionId = ids.pushSubscriptionId
        }
        guard current != record else {
            return
        }
        record = current
        persist()
    }

    private func loadIfNeeded() {
        guard !loaded else {
            return
        }
        loaded = true
        guard let data = storage.getSavedObject(forKey: OSUD_SESSION_RECORD, defaultValue: nil) as? Data else {
            return
        }
        do {
            record = try JSONDecoder().decode(OSSessionRecord.self, from: data)
        } catch {
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSSessionService dropping a stored session record it cannot decode: \(error)")
        }
    }

    private func persist() {
        guard let record, let data = try? JSONEncoder().encode(record) else {
            return
        }
        storage.saveObject(forKey: OSUD_SESSION_RECORD, withValue: data)
    }
}

/// Decides whether a foreground starts a new session: the app must have been closed, and the SDK
/// initialized, at least `threshold` seconds ago.
@objc(OSSessionStartGate)
public final class OSSessionStartGate: NSObject {
    @objc public static let shared = OSSessionStartGate()
    static let threshold: TimeInterval = 30

    private let storage: OneSignalUserDefaults
    private let now: () -> TimeInterval
    private let lock = NSLock()
    private var initializationTime: TimeInterval = 0
    private var lastStartTime: TimeInterval?

    init(
        storage: OneSignalUserDefaults = .initStandard(),
        now: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.storage = storage
        self.now = now
        super.init()
    }

    @objc public func recordInitialization() {
        let now = now()
        lock.withLock { initializationTime = now }
    }

    @objc public func shouldStartNewSession() -> Bool {
        let now = now()
        let lastClosedTime = storage.getSavedDouble(forKey: OSUD_APP_LAST_CLOSED_TIME, defaultValue: 0)
        let initializationTime = lock.withLock { self.initializationTime }
        let elapsed = min(now - lastClosedTime, now - initializationTime)
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionStartGate seconds since last closed or initialized: \(elapsed)")
        return elapsed >= Self.threshold
    }

    /// Records a session start, unless `deduplicate` is set and a session started within the threshold.
    /// Recovery from a prewarm and the foreground that triggered it each start a session, in either
    /// order, so both pass `deduplicate` and the later one is skipped. Returns whether to start.
    @objc public func beginSessionStart(deduplicate: Bool) -> Bool {
        let now = now()
        return lock.withLock {
            if deduplicate, let lastStartTime, now - lastStartTime < Self.threshold {
                return false
            }
            lastStartTime = now
            return true
        }
    }
}
