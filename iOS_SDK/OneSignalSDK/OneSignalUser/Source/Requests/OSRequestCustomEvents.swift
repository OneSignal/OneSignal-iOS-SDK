/*
 Modified MIT License

 Copyright 2025 OneSignal

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

class OSRequestCustomEvents: OneSignalRequest, OSUserRequest {
    var sentToClient = false
    let stringDescription: String
    override var description: String {
        return stringDescription
    }

    var identityModel: OSIdentityModel

    /// See the ownership convention in `OSUserRequest.swift`.
    let ownerExternalId: String?

    func prepareForExecution(newRecordsState: OSNewRecordsState, auth: OSRequestAuthorizing) -> Bool {
        if let onesignalId = identityModel.onesignalId,
           newRecordsState.canAccess(onesignalId),
           let appId = OneSignalIdentifiers.currentAppId,
           auth.authorize(self)
        {
            _ = self.addPushSubscriptionIdToAdditionalHeaders()
            if auth.ivBehaviorActive, let externalId = ownerExternalId {
                addExternalIdToEvents(externalId)
            }
            self.path = "apps/\(appId)/custom_events"
            return true
        } else {
            return false
        }
    }

    /// The path is app-scoped, so the owner rides in each event's body rather than in the path.
    /// Written at send time rather than at init so a cached payload cannot outlive the gate.
    private func addExternalIdToEvents(_ externalId: String) {
        guard let events = self.parameters?["events"] as? [[String: Any]] else {
            return
        }
        self.parameters?["events"] = events.map { event in
            var event = event
            event[OS_EXTERNAL_ID] = externalId
            return event
        }
    }

    init(events: [[String: Any]], identityModel: OSIdentityModel, ownerExternalId: String?) {
        self.identityModel = identityModel
        self.ownerExternalId = ownerExternalId
        self.stringDescription = "<OSRequestCustomEvents with events: \(events)>"
        super.init()
        self.parameters = [
            "events": events
        ]
        self.method = POST
    }

    func encode(with coder: NSCoder) {
        coder.encode(identityModel, forKey: "identityModel")
        coder.encode(ownerExternalId, forKey: "ownerExternalId")
        coder.encode(parameters, forKey: "parameters")
        coder.encode(method.rawValue, forKey: "method") // Encodes as String
        coder.encode(timestamp, forKey: "timestamp")
    }

    required init?(coder: NSCoder) {
        guard
            let identityModel = coder.decodeObject(forKey: "identityModel") as? OSIdentityModel,
            let rawMethod = coder.decodeObject(forKey: "method") as? UInt32,
            let parameters = coder.decodeObject(forKey: "parameters") as? [String: Any],
            let timestamp = coder.decodeObject(forKey: "timestamp") as? Date
        else {
            // Log error
            return nil
        }
        self.identityModel = identityModel
        self.ownerExternalId = coder.decodeObject(forKey: "ownerExternalId") as? String
        self.stringDescription = "<OSRequestCustomEvents with parameters: \(parameters)>"
        super.init()
        self.parameters = parameters
        self.method = HTTPMethod(rawValue: rawMethod)
        self.timestamp = timestamp
    }
}
