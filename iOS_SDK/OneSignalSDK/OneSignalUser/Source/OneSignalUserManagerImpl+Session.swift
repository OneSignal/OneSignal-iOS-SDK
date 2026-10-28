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

import OneSignalCore
import OneSignalOSCore

extension OneSignalUserManagerImpl {
    @objc
    public func startNewSession() {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignalUserManagerImpl starting new session")
        guard !OneSignalConfig.shouldAwaitAppIdAndLogMissingPrivacyConsent(forMethod: "_startNewSession") else {
            return
        }
        start()

        userExecutor!.executePendingRequestsOnNewSession()
        operationRepo.paused = false
        updatePropertiesDeltas(property: .session_count, value: 1, flush: true)
        let start = OSSessionService.shared.startNewSession(userProvider: self)
        if let ended = start.ended {
            enqueueSessionUpdate(ended, endTime: Date(timeIntervalSince1970: ended.endTime))
        }
        enqueueSessionCreate(start.started)
        OSSessionService.shared.startHeartbeat()

        // Fetch the user's data if there is a onesignal_id
        if let onesignalId = onesignalId {
            userExecutor!.fetchUser(aliasLabel: OS_ONESIGNAL_ID, aliasId: onesignalId, identityModel: user.identityModel, onNewSession: true)
        } else {
            // It is possible to init a user from cache who is missing the onesignalId
            // This can happen if any createUser or identifyUser requests are cached
            OneSignalLog.onesignalLog(.LL_WARN, message: "OneSignalUserManagerImpl.startNewSession() is unable to fetch user with External ID \(externalId ?? "nil") due to null OneSignal ID")
        }
    }
}

extension OneSignalUserManagerImpl: OSSessionUserProvider {
    public var sessionCurrentUser: OSSessionUser {
        let user = _user
        return OSSessionUser(
            identityModelId: user?.identityModel.modelId,
            onesignalId: user?.identityModel.onesignalId,
            pushSubscriptionId: user?.pushSubscriptionModel.subscriptionId
        )
    }

    public func sessionOnesignalId(identityModelId: String) -> String? {
        identityModelRepo.get(modelId: identityModelId)?.onesignalId
    }

    public func sessionHeartbeat(_ record: OSSessionRecord) {
        enqueueSessionUpdate(record)
    }

    /// Queues the session's create. Does nothing unless the session uses the sessions API.
    func enqueueSessionCreate(_ record: OSSessionRecord, directAttributionId: String? = nil) {
        var value: [String: Any] = [OSSessionDeltaKey.startTime: record.startTime]
        value[OSSessionDeltaKey.directAttributionId] = directAttributionId
        value[OSSessionDeltaKey.onesignalId] = record.onesignalId
        value[OSSessionDeltaKey.subscriptionId] = record.subscriptionId
        enqueueSessionDelta(OS_CREATE_SESSION_DELTA, record: record, value: value)
    }

    /// Queues the session's cumulative foreground time, ending the session when `endTime` is set.
    func enqueueSessionUpdate(_ record: OSSessionRecord, endTime: Date? = nil) {
        var value: [String: Any] = [OSSessionDeltaKey.activeDuration: record.reportedDuration]
        value[OSSessionDeltaKey.endTime] = endTime?.timeIntervalSince1970
        enqueueSessionDelta(OS_UPDATE_SESSION_DELTA, record: record, value: value)
    }

    private func enqueueSessionDelta(_ name: String, record: OSSessionRecord, value: [String: Any]) {
        guard record.usesSessionsApi else { return }
        guard let identityModel = sessionIdentityModel(for: record) else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OneSignalUserManagerImpl dropped \(name) for session \(record.sessionId), no identity model")
            return
        }
        guard let appId = OneSignalIdentifiers.currentAppId else {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OneSignalUserManagerImpl dropped \(name) for session \(record.sessionId), no app ID")
            return
        }
        var value = value
        value[OSSessionDeltaKey.appId] = appId
        let delta = OSDelta(
            name: name,
            identityModelId: identityModel.modelId,
            externalId: identityModel.externalId,
            model: identityModel,
            property: record.sessionId,
            value: value
        )
        operationRepo.enqueueDelta(delta)
    }

    /// Identity models are not cached across launches, so the user of a session that ended before a
    /// login in an earlier process is gone. It is restored from the session's pinned `onesignal_id`.
    private func sessionIdentityModel(for record: OSSessionRecord) -> OSIdentityModel? {
        if let identityModelId = record.identityModelId, let identityModel = identityModelRepo.get(modelId: identityModelId) {
            return identityModel
        }
        guard let onesignalId = record.onesignalId else {
            return nil
        }
        let identityModel = OSIdentityModel(aliases: [OS_ONESIGNAL_ID: onesignalId], changeNotifier: OSEventProducer())
        addIdentityModelToRepo(identityModel)
        return identityModel
    }
}
