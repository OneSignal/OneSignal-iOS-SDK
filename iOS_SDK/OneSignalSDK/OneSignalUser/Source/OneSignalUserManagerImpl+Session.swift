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

    /// Queues the session's create. Does nothing unless the session uses the sessions API.
    func enqueueSessionCreate(_ record: OSSessionRecord, directAttributionId: String? = nil) {
        var value: [String: Any] = [OSSessionDeltaKey.startTime: record.startTime]
        value[OSSessionDeltaKey.directAttributionId] = directAttributionId
        enqueueSessionDelta(OS_CREATE_SESSION_DELTA, record: record, value: value)
    }

    /// Queues the session's cumulative foreground time, ending the session when `endTime` is set.
    func enqueueSessionUpdate(_ record: OSSessionRecord, endTime: Date? = nil) {
        var value: [String: Any] = [OSSessionDeltaKey.activeDuration: record.activeDuration]
        value[OSSessionDeltaKey.endTime] = endTime?.timeIntervalSince1970
        value[OSSessionDeltaKey.serverSessionId] = record.serverSessionId
        enqueueSessionDelta(OS_UPDATE_SESSION_DELTA, record: record, value: value)
    }

    private func enqueueSessionDelta(_ name: String, record: OSSessionRecord, value: [String: Any]) {
        guard record.usesSessionsApi,
              let identityModelId = record.identityModelId,
              let identityModel = identityModelRepo.get(modelId: identityModelId),
              let appId = OneSignalIdentifiers.currentAppId
        else {
            return
        }
        var value = value
        value[OSSessionDeltaKey.appId] = appId
        value[OSSessionDeltaKey.onesignalId] = record.onesignalId
        value[OSSessionDeltaKey.subscriptionId] = record.subscriptionId
        let delta = OSDelta(
            name: name,
            identityModelId: identityModelId,
            externalId: identityModel.externalId,
            model: identityModel,
            property: record.sessionId,
            value: value
        )
        operationRepo.enqueueDelta(delta)
    }
}
