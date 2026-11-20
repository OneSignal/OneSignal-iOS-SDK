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
    /// Nil while the user is anonymous.
    public let externalId: String?

    public init(identityModelId: String?, onesignalId: String?, pushSubscriptionId: String?, externalId: String?) {
        self.identityModelId = identityModelId
        self.onesignalId = onesignalId
        self.pushSubscriptionId = pushSubscriptionId
        self.externalId = externalId
    }
}

/// The user a session belongs to, supplied by the User module, which also sends its heartbeats.
public protocol OSSessionUserProvider: AnyObject {
    /// Taken from one read of the current user, so a concurrent login cannot mix two users.
    var sessionCurrentUser: OSSessionUser { get }
    func sessionOnesignalId(identityModelId: String) -> String?
    /// Under Identity Verification an anonymous user is never created, so its session's create can
    /// only be sent once a login gives it a user.
    var sessionIdentityVerification: OSRequiresUserAuth { get }
    /// Called with the record whose `reportedDuration` is due to be sent, on any thread.
    func sessionHeartbeat(_ record: OSSessionRecord)
    /// Called once the app is in the background with the record whose `reportedDuration` is due to
    /// be sent, without ending its session.
    func sessionCheckpoint(_ record: OSSessionRecord)
    /// Called to queue a session's create, with the record's `directAttributionId`, before any of its
    /// updates.
    func sessionCreate(_ record: OSSessionRecord)
    /// Called to end a session at a user switch, with its `reportedDuration` and `endTime`.
    func sessionEnd(_ record: OSSessionRecord)
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
    /// Pinned at session start. Only a user switch while the create is held moves it.
    public internal(set) var identityModelId: String?
    /// Pinned at session start. Only a user switch while the create is held moves it.
    public internal(set) var onesignalId: String?
    public internal(set) var subscriptionId: String?
    /// Seconds since 1970 when the app last left the foreground. Nil until then.
    public internal(set) var lastUnfocusTime: TimeInterval?
    /// Seconds since 1970 when the app last entered the foreground during this session.
    public internal(set) var lastFocusTime: TimeInterval?
    /// The foreground time the last heartbeat or background checkpoint reported, which can exceed
    /// `activeDuration` until the visit a heartbeat was sent in ends. The next heartbeat is a full
    /// interval after it.
    public internal(set) var lastHeartbeatDuration: TimeInterval?
    /// Seconds since 1970 when the last heartbeat was sent, measured from the visit's focus on the
    /// monotonic clock so a wall-clock jump mid-visit cannot move a killed session's end. Cleared on
    /// unfocus, which then marks the end.
    public internal(set) var lastHeartbeatTime: TimeInterval?
    /// Set on a session that started in the background. Its create is held until its first focus, so
    /// an open delivered before that focus is on the create, and a session that never focuses sends
    /// neither a create nor an end. Persisted, so a kill before the focus does not send it later.
    public internal(set) var awaitingFocus: Bool?
    /// The external ID of the user the session follows, nil while anonymous. A login after an
    /// anonymous session's create was sent sets it without moving the session, so a later switch
    /// splits.
    public internal(set) var externalId: String?
    /// Set while the session's create is not queued: until its first focus, and for an anonymous
    /// user until the first background, a heartbeat, or the session's end, so a login before then
    /// can move the session to that user.
    public internal(set) var createHeld: Bool?
    /// The open that started the session, kept for a held create.
    public internal(set) var directAttributionId: String?
    /// Set once a user switch while unfocused has ended the session. The app session goes on, and
    /// the next session starts on the next focus.
    public internal(set) var splitPending: Bool?

    /// Cumulative foreground time to report. A session killed in the foreground never added its last
    /// visit to `activeDuration`, so this never reports less than its last heartbeat did.
    public var reportedDuration: TimeInterval {
        max(activeDuration, lastHeartbeatDuration ?? 0)
    }

    /// The backend takes whole seconds, so a checkpoint is due only once that value grows.
    var checkpointDue: Bool {
        usesSessionsApi && awaitingFocus != true && createHeld != true && splitPending != true
            && activeDuration.rounded(.down) > (lastHeartbeatDuration ?? 0).rounded(.down)
    }

    /// Seconds since 1970. A session killed in the foreground never unfocused, so it ends at its
    /// last focus or heartbeat, whichever is later.
    public var endTime: TimeInterval {
        max(startTime, lastUnfocusTime ?? startTime, lastFocusTime ?? startTime, lastHeartbeatTime ?? startTime)
    }
}

public struct OSSessionStart {
    /// Its create is queued now unless `createHeld` is set.
    public let started: OSSessionRecord
    /// The notification whose open started the session.
    public let directAttributionId: String?
    /// The session the new one replaced, which has now ended. Nil when it is not reported: it never
    /// focused, or its create could never be sent.
    public let ended: OSSessionRecord?
    /// The ended session's create was held until now, so it is queued before the end.
    public let endedCreateHeld: Bool
}

/// Owns the persisted record of the current session. Nothing reads the record while
/// `usesSessionsApi` is false, so with the flag off session behavior is unchanged.
/// While in the foreground, a sessions API session reports its duration every heartbeat interval of
/// foreground time, so the backend keeps it open and a crash loses little of it. The interval comes
/// from the params' `sessions.heartbeat_interval_seconds`.
/// An anonymous user's session holds its create until the first background, a heartbeat, or the
/// session's end, so a login before then can move the session to that user. Under Identity
/// Verification it stays held while its user is not created, since that user never will be.
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
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    private let requiresPrivacyConsent: () -> Bool
    /// Read on every check, so a later params fetch applies once the current wait ends.
    private let heartbeatInterval: () -> TimeInterval

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
    /// Bumped at every user switch, before it reads the new user, so a focus that read the user
    /// outside the lock can tell that a switch landed in between.
    private var userSwitchGeneration = 0
    /// The generation a running heartbeat was armed with. Stale once the generation moves on.
    private var armedHeartbeatGeneration: Int?
    /// A notification opened from the background, for the session its focus starts or first brings to
    /// the foreground. A focus that continues a focused session, or a later unfocus, discards it. A
    /// background action from Notification Center arrives after the unfocus and brings no focus, so it
    /// expires after the threshold.
    private var pendingAttribution: (notificationId: String, openedAt: TimeInterval)?

    init(
        storage: OneSignalUserDefaults = .initStandard(),
        featureManager: @escaping () -> OSFeatureManager = { .shared },
        monotonicNow: @escaping () -> TimeInterval = {
            TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / TimeInterval(NSEC_PER_SEC)
        },
        wallNow: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, block in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: block)
        },
        heartbeatInterval: @escaping () -> TimeInterval = {
            OSSessionService.heartbeatInterval(remoteParams: OSRemoteParamController.shared().remoteParams)
        },
        requiresPrivacyConsent: @escaping () -> Bool = { OSPrivacyConsentController.requiresUserPrivacyConsent() }
    ) {
        self.storage = storage
        self.featureManager = featureManager
        self.monotonicNow = monotonicNow
        self.wallNow = wallNow
        self.schedule = schedule
        self.heartbeatInterval = heartbeatInterval
        self.requiresPrivacyConsent = requiresPrivacyConsent
        super.init()
    }

    @objc public static func onFocus() {
        shared.onFocus()
    }

    @objc public static func onUnfocus() {
        shared.onUnfocus()
    }

    @objc public static func onNotificationOpened(_ notificationId: String) {
        shared.onNotificationOpened(notificationId)
    }

    @objc public static func reset() {
        let retired = lock.withLock {
            let existing = _shared
            _shared = nil
            return existing
        }
        retired?.stopHeartbeat()
    }

    static func setSharedForTesting(_ service: OSSessionService) {
        let retired = lock.withLock {
            let existing = _shared
            _shared = service
            return existing
        }
        retired?.stopHeartbeat()
    }

    /// The stored record belongs to the previous app, so it must not outlive an app-id change.
    @objc public static func resetAndClearStoredRecord() {
        reset()
        OneSignalUserDefaults.initStandard().removeValue(forKey: OSUD_SESSION_RECORD)
    }

    /// A sessions API session reports its duration and attribution itself, so the legacy session
    /// duration outcome and `session_time` are not sent for it.
    @objc public static var currentSessionUsesSessionsApi: Bool {
        shared.currentRecord?.usesSessionsApi ?? false
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
        // An ended session's create goes out while the requirement is unknown: the operation repo
        // holds it until the requirement is known, and there is no later chance to send it.
        let identityVerificationRequired = userProvider.sessionIdentityVerification == .on
        let now = monotonicNow()
        var newRecord = Self.makeRecord(
            for: userProvider.sessionCurrentUser,
            startTime: wallNow(),
            usesSessionsApi: featureManager().isEnabled(featureKey: FeatureFlag.sdkSessionsV2ApiCutover.key)
        )
        let start: OSSessionStart = stateLock.withLock {
            loadIfNeeded()
            // Last chance to fill the replaced record's IDs while it is still the current one.
            fillPinnedIds(previousIds)
            let ended = endedRecordToReport(identityVerificationRequired: identityVerificationRequired)
            newRecord.lastFocusTime = openFocusTime
            var directAttributionId: String?
            if openFocusTime == nil {
                // The open that brings this session forward is consumed by its first focus.
                newRecord.awaitingFocus = true
            } else {
                directAttributionId = takePendingAttribution(at: now)
            }
            directAttributionId = Self.holdCreateIfNeeded(&newRecord, directAttributionId: directAttributionId)
            self.userProvider = userProvider
            record = newRecord
            recordStartedInThisProcess = true
            // The replaced session's heartbeat stops here, before its record is gone.
            heartbeatGeneration += 1
            persist()
            return OSSessionStart(
                started: newRecord, directAttributionId: directAttributionId, ended: ended, endedCreateHeld: ended?.createHeld == true
            )
        }
        enqueue(start)
        restartHeartbeat(continuesRecord: true)
        return start
    }

    func onFocus() {
        let now = monotonicNow()
        let wallNow = wallNow()
        let (continuesRecord, release) = focusRecordAfterAnyUserSwitch(now: now, wallNow: wallNow)
        release?.send()
        // A focus that starts a new session leaves the heartbeat to that session's start. A held
        // create is queued above, before the heartbeat whose updates need it.
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
            pendingAttribution = nil
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

// MARK: - Notification attribution

extension OSSessionService {
    /// Called for an open from the background. iOS delivers it before the focus it causes, on a cold
    /// start too, so the session that focus starts or first brings to the foreground carries it.
    func onNotificationOpened(_ notificationId: String) {
        let now = monotonicNow()
        stateLock.withLock { pendingAttribution = (notificationId, now) }
    }

    /// Clears the open in every case, so it never carries over to a later session.
    private func takePendingAttribution(at now: TimeInterval) -> String? {
        defer { pendingAttribution = nil }
        guard let pending = pendingAttribution, now - pending.openedAt < OSSessionStartGate.threshold else {
            return nil
        }
        return pending.notificationId
    }
}

// MARK: - Held create

extension OSSessionService {
    struct SessionCreate {
        let record: OSSessionRecord
        let provider: OSSessionUserProvider

        func send() {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionService queueing the create of session \(record.sessionId)")
            provider.sessionCreate(record)
        }
    }

    /// Read outside `stateLock` because the provider takes the User module's locks.
    private func identityVerificationRequirement() -> OSRequiresUserAuth {
        let provider = stateLock.withLock { userProvider }
        return provider?.sessionIdentityVerification ?? .off
    }

    /// Call with `stateLock` held.
    private func canSendCreate(of record: OSSessionRecord, identityVerificationRequired: Bool) -> Bool {
        // The executor drops an anonymous create whose user can never be created.
        let waitsForLogin = identityVerificationRequired && record.externalId == nil
            && (record.onesignalId == nil || record.subscriptionId == nil)
        return !waitsForLogin && !requiresPrivacyConsent()
    }

    /// Call with `stateLock` held. A session that never focused, or whose create can never be sent,
    /// is not reported.
    private func endedRecordToReport(identityVerificationRequired: Bool) -> OSSessionRecord? {
        guard let record else {
            return nil
        }
        if record.awaitingFocus == true {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionService discarding session \(record.sessionId), it never focused")
            return nil
        }
        if record.splitPending == true {
            return nil
        }
        if record.createHeld == true, !canSendCreate(of: record, identityVerificationRequired: identityVerificationRequired) {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionService session \(record.sessionId) ended with its create held, not reporting it")
            return nil
        }
        return record
    }

    /// Call with `stateLock` held. Returns the held create once it can be sent, which the caller must
    /// send before any update of the session. A session that has not focused keeps it.
    private func takeHeldCreate(identityVerificationRequired: Bool) -> SessionCreate? {
        guard var current = record, current.createHeld == true, current.awaitingFocus != true, let userProvider,
              canSendCreate(of: current, identityVerificationRequired: identityVerificationRequired) else {
            return nil
        }
        let held = current
        current.createHeld = nil
        current.directAttributionId = nil
        record = current
        return SessionCreate(record: held, provider: userProvider)
    }
}

// MARK: - Split

extension OSSessionService {
    static func makeRecord(for user: OSSessionUser, startTime: TimeInterval, usesSessionsApi: Bool) -> OSSessionRecord {
        var record = OSSessionRecord(
            sessionId: UUID().uuidString,
            startTime: startTime,
            activeDuration: 0,
            usesSessionsApi: usesSessionsApi,
            identityModelId: user.identityModelId,
            onesignalId: user.onesignalId,
            subscriptionId: user.pushSubscriptionId
        )
        record.externalId = user.externalId
        return record
    }

    /// Holds the create of a session that has not focused or whose user is anonymous, with its
    /// attribution. Returns the attribution for a create queued now.
    static func holdCreateIfNeeded(_ record: inout OSSessionRecord, directAttributionId: String?) -> String? {
        guard record.usesSessionsApi, record.awaitingFocus == true || record.externalId == nil else {
            return directAttributionId
        }
        record.createHeld = true
        record.directAttributionId = directAttributionId
        return nil
    }

    private struct UserSwitch {
        let heldCreate: SessionCreate?
        let ended: OSSessionRecord?
        let next: SessionCreate?
        let provider: OSSessionUserProvider
        let split: Bool
    }

    /// Called after a login or logout replaces the current user. A held create moves to the new user,
    /// and is queued if that user is identified. Otherwise a logged-in user's switch splits the
    /// session, and an anonymous user's login keeps it, so it is not counted twice.
    public func onUserSwitched() {
        let ids = pinnableIds()
        let identityVerificationRequired = identityVerificationRequirement() == .on
        let provider: OSSessionUserProvider? = stateLock.withLock {
            userSwitchGeneration += 1
            return userProvider
        }
        guard let provider else {
            return
        }
        let user = provider.sessionCurrentUser
        let now = monotonicNow()
        let wallNow = wallNow()
        let change: UserSwitch? = stateLock.withLock {
            loadIfNeeded()
            fillPinnedIds(ids)
            guard var current = record, current.usesSessionsApi, current.splitPending != true, isCurrentSession else {
                return nil
            }
            if current.createHeld == true {
                OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionService moving session \(current.sessionId) to the new user")
                current.identityModelId = user.identityModelId
                current.onesignalId = user.onesignalId
                current.subscriptionId = user.pushSubscriptionId
                current.externalId = user.externalId
                record = current
                let create = user.externalId == nil ? nil : takeHeldCreate(identityVerificationRequired: identityVerificationRequired)
                persist()
                return UserSwitch(heldCreate: create, ended: nil, next: nil, provider: provider, split: false)
            }
            if current.externalId == nil {
                record?.externalId = user.externalId
                persist()
                return nil
            }
            return takeSplit(for: user, now: now, wallNow: wallNow, identityVerificationRequired: identityVerificationRequired, provider: provider)
        }
        guard let change else {
            return
        }
        change.heldCreate?.send()
        if let ended = change.ended {
            change.provider.sessionEnd(ended)
        }
        change.next?.send()
        if change.split {
            restartHeartbeat(continuesRecord: true)
        }
    }

    /// Call with `stateLock` held. False while the record is about to be replaced: it is from an
    /// earlier process, or the open visit's focus will start a new session. That session is ended
    /// as it was, and the new one starts for the new user.
    private var isCurrentSession: Bool {
        guard recordStartedInThisProcess else {
            return false
        }
        return focusedAt == nil || openFocusTime.map(focusContinuesRecord) == true
    }

    /// Call with `stateLock` held. Ends the current session now and starts the next one for the new
    /// user. The app session goes on, so no legacy session start or end is sent. While unfocused,
    /// the next session starts on the next focus.
    private func takeSplit(
        for user: OSSessionUser,
        now: TimeInterval,
        wallNow: TimeInterval,
        identityVerificationRequired: Bool,
        provider: OSSessionUserProvider
    ) -> UserSwitch? {
        guard var current = record else {
            return nil
        }
        if let start = focusedAt {
            current.activeDuration += max(0, now - start)
            current.lastUnfocusTime = wallNow
            current.lastHeartbeatTime = nil
            record = current
        }
        let ended = endedRecordToReport(identityVerificationRequired: identityVerificationRequired)
        let heldCreate = ended == nil ? nil : takeHeldCreate(identityVerificationRequired: identityVerificationRequired)
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionService splitting session \(current.sessionId) at a user switch")
        var next: SessionCreate?
        if focusedAt != nil {
            focusedAt = now
            openFocusTime = wallNow
            next = startNextSession(for: user, at: wallNow, directAttributionId: nil)
        } else {
            record?.splitPending = true
        }
        // The ended session's heartbeat stops here.
        heartbeatGeneration += 1
        persist()
        return UserSwitch(heldCreate: heldCreate, ended: ended, next: next, provider: provider, split: true)
    }

    /// Retries when a user switch lands between reading the pending split's user and taking the
    /// lock, since that switch may have ended the record or changed the next user.
    private func focusRecordAfterAnyUserSwitch(now: TimeInterval, wallNow: TimeInterval) -> (Bool, SessionCreate?) {
        while true {
            let pendingSplit = userAfterPendingSplit()
            let focus: (Bool, SessionCreate?)? = stateLock.withLock {
                guard pendingSplit.generation == userSwitchGeneration else {
                    return nil
                }
                return focusRecord(now: now, wallNow: wallNow, splitUser: pendingSplit.user)
            }
            if let focus {
                return focus
            }
        }
    }

    /// Call with `stateLock` held.
    private func focusRecord(now: TimeInterval, wallNow: TimeInterval, splitUser: OSSessionUser?) -> (Bool, SessionCreate?) {
        focusedAt = now
        loadIfNeeded()
        openFocusTime = wallNow
        guard var current = record, focusContinuesRecord(at: wallNow) else {
            return (false, nil)
        }
        let directAttributionId = takePendingAttribution(at: now)
        if current.splitPending == true, let splitUser {
            return (true, startNextSession(for: splitUser, at: wallNow, directAttributionId: directAttributionId))
        }
        // Saved now, since a kill leaves no unfocus to record when the session was last active.
        current.lastFocusTime = wallNow
        let wasAwaitingFocus = current.awaitingFocus == true
        current.awaitingFocus = nil
        if wasAwaitingFocus {
            current.directAttributionId = directAttributionId
        }
        record = current
        // An anonymous session's create stays held past its first focus.
        let release = wasAwaitingFocus && current.externalId != nil ? takeHeldCreate(identityVerificationRequired: false) : nil
        persist()
        return (true, release)
    }

    /// Read outside `stateLock` because the provider takes the User module's locks.
    private func userAfterPendingSplit() -> (generation: Int, user: OSSessionUser?) {
        let (generation, provider): (Int, OSSessionUserProvider?) = stateLock.withLock {
            loadIfNeeded()
            return (userSwitchGeneration, record?.splitPending == true ? userProvider : nil)
        }
        return (generation, provider?.sessionCurrentUser)
    }

    /// Call with `stateLock` held. Replaces the record with the next session after a split, which
    /// keeps the app session's `usesSessionsApi`. Returns its create unless held.
    private func startNextSession(for user: OSSessionUser, at time: TimeInterval, directAttributionId: String?) -> SessionCreate? {
        guard let current = record, let userProvider else {
            return nil
        }
        var next = Self.makeRecord(for: user, startTime: time, usesSessionsApi: current.usesSessionsApi)
        next.lastFocusTime = time
        let attribution = Self.holdCreateIfNeeded(&next, directAttributionId: directAttributionId)
        record = next
        recordStartedInThisProcess = true
        persist()
        guard next.createHeld != true else {
            return nil
        }
        var create = next
        create.directAttributionId = attribution
        return SessionCreate(record: create, provider: userProvider)
    }
}

// MARK: - Heartbeat

extension OSSessionService {
    static let defaultHeartbeatInterval: TimeInterval = 30 * 60
    // Bounds a misconfigured value so it can neither flood requests nor stop heartbeats.
    static let minHeartbeatInterval: TimeInterval = 60
    static let maxHeartbeatInterval: TimeInterval = 24 * 60 * 60

    /// A missing, non-positive, or non-numeric value falls back to the default. A JSON boolean
    /// bridges to an `NSNumber` of 1, so it is rejected explicitly.
    static func heartbeatInterval(remoteParams: [AnyHashable: Any]) -> TimeInterval {
        let sessions = remoteParams["sessions"] as? [AnyHashable: Any]
        guard let number = sessions?["heartbeat_interval_seconds"] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue > 0 else {
            return defaultHeartbeatInterval
        }
        return min(max(number.doubleValue, minHeartbeatInterval), maxHeartbeatInterval)
    }

    /// A cold launch arms the heartbeat before params arrive, so the wait is re-armed with the new
    /// interval. Only a running heartbeat is re-armed: a focus that is about to start a new session
    /// must not send one for the record it replaces.
    @objc public static func onRemoteParamsUpdated() {
        shared.rescheduleHeartbeat()
    }

    func rescheduleHeartbeat() {
        let generation: Int? = stateLock.withLock {
            guard let armed = armedHeartbeatGeneration, armed == heartbeatGeneration else {
                return nil
            }
            heartbeatGeneration += 1
            armedHeartbeatGeneration = heartbeatGeneration
            return heartbeatGeneration
        }
        guard let generation else {
            return
        }
        checkHeartbeat(generation: generation)
    }

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
            armedHeartbeatGeneration = heartbeatGeneration
            return (heartbeatGeneration, record.sessionId)
        }
        guard let armed else {
            return
        }
        OneSignalLog.onesignalLog(.LL_DEBUG, message: "OSSessionService starting heartbeat for session \(armed.sessionId)")
        checkHeartbeat(generation: armed.generation)
    }

    private struct HeartbeatDue {
        let record: OSSessionRecord
        let provider: OSSessionUserProvider?
        let create: SessionCreate?
    }

    /// Rechecks the duration after every wait. The scheduler's clock pauses through device sleep and
    /// `monotonicNow` doesn't, so a check can fire late but never early.
    private func checkHeartbeat(generation: Int) {
        let now = monotonicNow()
        let ids = pinnableIds()
        // The create of a session still going can wait for the requirement to be known.
        let identityVerificationRequired = identityVerificationRequirement() != .off
        let interval = heartbeatInterval()
        let next: (due: HeartbeatDue?, wait: TimeInterval)? = stateLock.withLock {
            guard generation == heartbeatGeneration, let start = focusedAt, let focusTime = openFocusTime,
                  let current = record, current.usesSessionsApi else {
                return nil
            }
            let focusDuration = max(0, now - start)
            let duration = current.activeDuration + focusDuration
            let remaining = (current.lastHeartbeatDuration ?? 0) + interval - duration
            guard remaining <= 0 else {
                return (nil, remaining)
            }
            fillPinnedIds(ids)
            record?.lastHeartbeatDuration = duration
            record?.lastHeartbeatTime = focusTime + focusDuration
            let create = takeHeldCreate(identityVerificationRequired: identityVerificationRequired)
            persist()
            // An update queued before its create is discarded.
            let due = record.flatMap { $0.createHeld == true ? nil : HeartbeatDue(record: $0, provider: userProvider, create: create) }
            return (due, interval)
        }
        guard let next else {
            return
        }
        if let due = next.due {
            due.create?.send()
            OneSignalLog.onesignalLog(
                .LL_DEBUG,
                message: "OSSessionService heartbeat for session \(due.record.sessionId) with duration \(due.record.reportedDuration)"
            )
            due.provider?.sessionHeartbeat(due.record)
        }
        schedule(next.wait) { [weak self] in
            self?.checkHeartbeat(generation: generation)
        }
    }
}

// MARK: - Background checkpoint

extension OSSessionService {
    private struct Checkpoint {
        let record: OSSessionRecord
        let provider: OSSessionUserProvider?
    }

    /// Called once the app is in the background. Leaving the foreground for Control Center, the
    /// notification shade, or a system prompt unfocuses too, but must not send a checkpoint or move
    /// the next heartbeat. Returns whether a checkpoint was queued, for the caller to flush.
    @objc public static func onEnteredBackground() -> Bool {
        shared.onEnteredBackground()
    }

    /// Reports the duration so far as a checkpoint that leaves the session open, so a kill in the
    /// background loses none of it.
    func onEnteredBackground() -> Bool {
        let ids = pinnableIds()
        // The create of a session still going can wait for the requirement to be known.
        let identityVerificationRequired = identityVerificationRequirement() != .off
        let (create, checkpoint): (SessionCreate?, Checkpoint?) = stateLock.withLock {
            loadIfNeeded()
            guard focusedAt == nil else {
                return (nil, nil)
            }
            fillPinnedIds(ids)
            let create = takeHeldCreate(identityVerificationRequired: identityVerificationRequired)
            let checkpoint = takeCheckpointIfDue()
            if create != nil || checkpoint != nil {
                persist()
            }
            return (create, checkpoint)
        }
        create?.send()
        if let checkpoint {
            sendCheckpoint(checkpoint)
        }
        return create != nil || checkpoint != nil
    }

    /// Call with `stateLock` held.
    private func takeCheckpointIfDue() -> Checkpoint? {
        guard var current = record, current.checkpointDue, !requiresPrivacyConsent() else {
            return nil
        }
        current.lastHeartbeatDuration = current.activeDuration
        record = current
        return Checkpoint(record: current, provider: userProvider)
    }

    private func sendCheckpoint(_ checkpoint: Checkpoint) {
        OneSignalLog.onesignalLog(
            .LL_DEBUG,
            message: "OSSessionService checkpoint for session \(checkpoint.record.sessionId) with duration \(checkpoint.record.reportedDuration)"
        )
        checkpoint.provider?.sessionCheckpoint(checkpoint.record)
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
