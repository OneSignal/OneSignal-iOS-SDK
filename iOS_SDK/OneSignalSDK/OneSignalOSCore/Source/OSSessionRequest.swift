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
import Network

struct OSSessionRequest: Codable, Equatable {
    enum Kind: Codable, Equatable {
        /// `startTime` is seconds since 1970.
        case create(startTime: TimeInterval, directAttributionId: String?)
        /// `activeDuration` is cumulative for the session. `endTime` is seconds since 1970, set
        /// only on the update that ends the session.
        case update(activeDuration: TimeInterval, endTime: TimeInterval?)
    }

    let appId: String
    /// `OSSessionRecord.sessionId`, which stands in for the backend session ID until the create succeeds.
    let localSessionId: String
    /// Set on an update once its session's create succeeds.
    var serverSessionId: String?
    let identityModelId: String?
    var onesignalId: String?
    var subscriptionId: String?
    var kind: Kind
    /// Generated once and persisted, so every retry, including after a restart, is deduplicated by the backend.
    let idempotencyKey: String
    /// Failed attempts the backend answered, persisted so the limit holds across restarts.
    var failedAttempts = 0

    var isCreate: Bool {
        if case .create = kind {
            return true
        }
        return false
    }

    var isEnd: Bool {
        if case .update(_, let endTime) = kind {
            return endTime != nil
        }
        return false
    }

    var activeDuration: TimeInterval? {
        if case .update(let activeDuration, _) = kind {
            return activeDuration
        }
        return nil
    }
}

protocol OSSessionNetworkMonitoring: AnyObject {
    func start(onAvailable: @escaping () -> Void)
    func stop()
}

final class OSSessionNetworkMonitor: OSSessionNetworkMonitoring {
    private var monitor: NWPathMonitor?

    func start(onAvailable: @escaping () -> Void) {
        guard monitor == nil else {
            return
        }
        let monitor = NWPathMonitor()
        var wasSatisfied: Bool?
        monitor.pathUpdateHandler = { path in
            let isSatisfied = path.status == .satisfied
            defer { wasSatisfied = isSatisfied }
            if isSatisfied, wasSatisfied == false {
                onAvailable()
            }
        }
        monitor.start(queue: DispatchQueue(label: "OneSignal.OSSessionNetworkMonitor"))
        self.monitor = monitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }

    deinit {
        monitor?.cancel()
    }
}

extension OSSessionsApiResult {
    func map<T>(_ transform: (Value) -> T) -> OSSessionsApiResult<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .retry(let statusCode, let retryAfterSeconds):
            return .retry(statusCode: statusCode, retryAfterSeconds: retryAfterSeconds)
        case .drop(let statusCode):
            return .drop(statusCode: statusCode)
        }
    }
}
