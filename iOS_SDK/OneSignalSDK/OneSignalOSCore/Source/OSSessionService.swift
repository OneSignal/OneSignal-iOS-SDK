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

/// The user a session belongs to, supplied by the User module, which also sends its heartbeats.
public protocol OSSessionUserProvider: AnyObject {
    /// Taken from one read of the current user, so a concurrent login cannot mix two users.
    var sessionCurrentUser: OSSessionUser { get }
    func sessionOnesignalId(identityModelId: String) -> String?
    /// Called with the record whose `reportedDuration` is due to be sent, on any thread.
    func sessionHeartbeat(_ record: OSSessionRecord)
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
    /// The foreground time the last heartbeat reported, which can exceed `activeDuration` until the
    /// visit it was sent in ends.
    public internal(set) var lastHeartbeatDuration: TimeInterval?
    /// Seconds since 1970 when the last heartbeat was sent, measured from the visit's focus on the
    /// monotonic clock so a wall-clock jump mid-visit cannot move a killed session's end. Cleared on
    /// unfocus, which then marks the end.
    public internal(set) var lastHeartbeatTime: TimeInterval?

    /// Cumulative foreground time to report. A session killed in the foreground never added its last
    /// visit to `activeDuration`, so this never reports less than its last heartbeat did.
    public var reportedDuration: TimeInterval {
        max(activeDuration, lastHeartbeatDuration ?? 0)
    }

    /// Seconds since 1970. A session killed in the foreground never unfocused, so it ends at its
    /// last focus or heartbeat, whichever is later.
    public var endTime: TimeInterval {
        max(startTime, lastUnfocusTime ?? startTime, lastFocusTime ?? startTime, lastHeartbeatTime ?? startTime)
    }
}

public struct OSSessionStart {
    public let started: OSSessionRecord
    /// The session the new one replaced, which has now ended.
    public let ended: OSSessionRecord?
}

/// Owns the persisted record of the current session. Nothing reads the record while
/// `usesSessionsApi` is false, so with the flag off session behavior is unchanged.
/// While in the foreground, a sessions API session reports its duration every `heartbeatInterval`
/// of foreground time, so the backend keeps it open and a crash loses little of it.
@objc(OSSessionService)
public final class OSSessionService: NSObject {
    static let heartbeatInterval: TimeInterval = 30 * 60

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
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void

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
    /// Bumped whenever the heartbeat restarts or stops, so a check scheduled before then does nothing.
    private var heartbeatGeneration = 0

    init(
        storage: OneSignalUserDefaults = .initStandard(),
        featureManager: @escaping () -> OSFeatureManager = { .shared },
        monotonicNow: @escaping () -> TimeInterval = {
            TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / TimeInterval(NSEC_PER_SEC)
        },
        wallNow: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, block in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: block)
        }
    ) {
        self.storage = storage
        self.featureManager = featureManager
        self.monotonicNow = monotonicNow
        self.wallNow = wallNow
        self.schedule = schedule
        super.init()
    }

    @objc public static func onFocus() {
        shared.onFocus()
    }

    @objc public static func onUnfocus() {
        shared.onUnfocus()
    }

    @objc public static func reset() {
        let retired = lock.withLock {
            let existing = _shared
            _shared = nil
            return existing
        }
        retired?.stopHeartbeat()
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
    /// `enqueue` queues the sessions' end and create. The heartbeat starts after it returns, since an
    /// update queued before its session's create is discarded.
    @discardableResult
    public func startNewSession(
        userProvider: OSSessionUserProvider,
        enqueue: (OSSessionStart) -> Void = { _ in }
    ) -> OSSessionStart {
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
            // The replaced session's heartbeat stops here, before its record is gone.
            heartbeatGeneration += 1
            persist()
            return ended
        }
        let start = OSSessionStart(started: newRecord, ended: ended)
        enqueue(start)
        restartHeartbeat(continuesRecord: true)
        return start
    }

    func onFocus() {
        let now = monotonicNow()
        let wallNow = wallNow()
        let continuesRecord: Bool = stateLock.withLock {
            focusedAt = now
            loadIfNeeded()
            openFocusTime = wallNow
            guard record != nil, focusContinuesRecord(at: wallNow) else {
                return false
            }
            // Saved now, since a kill leaves no unfocus to record when the session was last active.
            record?.lastFocusTime = wallNow
            persist()
            return true
        }
        // A focus that starts a new session leaves the heartbeat to that session's start.
        restartHeartbeat(continuesRecord: continuesRecord)
    }

    /// A focus that will start a new session is not saved on the current record, or a kill before
    /// that session starts would move the current session's end past its last unfocus.
    private func focusContinuesRecord(at time: TimeInterval) -> Bool {
        guard recordStartedInThisProcess, let record else {
            return false
        }
        return time - (record.lastUnfocusTime ?? record.startTime) < OSSessionStartGate.threshold
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
            heartbeatGeneration += 1
            loadIfNeeded()
            guard record != nil else {
                return
            }
            record?.activeDuration += max(0, now - start)
            record?.lastUnfocusTime = wallNow
            record?.lastHeartbeatTime = nil
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

// MARK: - Heartbeat

extension OSSessionService {
    private func stopHeartbeat() {
        stateLock.withLock { heartbeatGeneration += 1 }
    }

    /// Counts only foreground time: the interval resumes from the last heartbeat's duration.
    private func restartHeartbeat(continuesRecord: Bool) {
        let armed: (generation: Int, sessionId: String)? = stateLock.withLock {
            heartbeatGeneration += 1
            guard continuesRecord, focusedAt != nil, let record, record.usesSessionsApi else {
                return nil
            }
            return (heartbeatGeneration, record.sessionId)
        }
        guard let armed else {
            return
        }
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionService starting heartbeat for session \(armed.sessionId)")
        checkHeartbeat(generation: armed.generation)
    }

    /// Rechecks the duration after every wait. The scheduler's clock pauses through device sleep and
    /// `monotonicNow` doesn't, so a check can fire late but never early.
    private func checkHeartbeat(generation: Int) {
        let now = monotonicNow()
        let ids = pinnableIds()
        let next: (due: (record: OSSessionRecord, provider: OSSessionUserProvider?)?, wait: TimeInterval)? = stateLock.withLock {
            guard generation == heartbeatGeneration, let start = focusedAt, let focusTime = openFocusTime,
                  let current = record, current.usesSessionsApi else {
                return nil
            }
            let focusDuration = max(0, now - start)
            let duration = current.activeDuration + focusDuration
            let remaining = (current.lastHeartbeatDuration ?? 0) + Self.heartbeatInterval - duration
            guard remaining <= 0 else {
                return (nil, remaining)
            }
            fillPinnedIds(ids)
            record?.lastHeartbeatDuration = duration
            record?.lastHeartbeatTime = focusTime + focusDuration
            persist()
            return (record.map { ($0, userProvider) }, Self.heartbeatInterval)
        }
        guard let next else {
            return
        }
        if let (record, provider) = next.due {
            OneSignalLog.onesignalLog(
                .LL_DEBUG,
                message: "OSSessionService heartbeat for session \(record.sessionId) with duration \(record.reportedDuration)"
            )
            provider?.sessionHeartbeat(record)
        }
        schedule(next.wait) { [weak self] in
            self?.checkHeartbeat(generation: generation)
        }
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
