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

/**
 Tracks when a Request that failed with a retryable error may be sent again in this run. Delays grow
 exponentially with jitter, and a server's `Retry-After` is the minimum wait.

 State lives in memory, keyed weakly by Request, so it ends with the Request. After a relaunch, cached
 Requests are sent right away.
 */
public final class OSRequestRetryBackoff {
    static let baseDelaySeconds: TimeInterval = 5
    static let maxDelaySeconds: TimeInterval = 300
    static let defaultRetryAfterSeconds: TimeInterval = 60
    static let maxRetryAfterSeconds: TimeInterval = 3600

    private final class Entry {
        var failures = 0
        var retryAt: TimeInterval = 0
        var retryAfterAt: TimeInterval = 0
    }

    private let lock = NSLock()
    private let entries = NSMapTable<AnyObject, Entry>.weakToStrongObjects()
    private let uptime: () -> TimeInterval
    private let jitter: () -> Double

    public convenience init() {
        // CLOCK_MONOTONIC keeps counting while the device sleeps, unlike `systemUptime`.
        self.init(uptime: { TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1e9 }, jitter: { Double.random(in: 0.5...1) })
    }

    init(uptime: @escaping () -> TimeInterval, jitter: @escaping () -> Double) {
        self.uptime = uptime
        self.jitter = jitter
    }

    public func isWaiting(_ request: AnyObject) -> Bool {
        lock.withLock {
            (entries.object(forKey: request)?.retryAt ?? 0) > uptime()
        }
    }

    /// Returns the seconds until `request` may be sent again.
    @discardableResult
    public func recordFailure(_ request: AnyObject, error: OneSignalClientError) -> TimeInterval {
        let retryAfter = Self.retryAfterSeconds(error)
        return lock.withLock {
            let entry = entries.object(forKey: request) ?? Entry()
            entries.setObject(entry, forKey: request)
            entry.failures += 1
            let exponential = Self.baseDelaySeconds * pow(2, Double(entry.failures - 1))
            let now = uptime()
            entry.retryAfterAt = retryAfter.map { now + $0 } ?? 0
            entry.retryAt = max(now + min(exponential, Self.maxDelaySeconds) * jitter(), entry.retryAfterAt)
            return entry.retryAt - now
        }
    }

    /// Ends every backoff early, except what a server's `Retry-After` asked for. Returns whether any
    /// Request can now be sent sooner.
    @discardableResult
    public func retryNow() -> Bool {
        lock.withLock {
            let now = uptime()
            var endedAWait = false
            let enumerator = entries.objectEnumerator()
            while let entry = enumerator?.nextObject() as? Entry {
                if entry.retryAt > max(now, entry.retryAfterAt) {
                    entry.retryAt = entry.retryAfterAt
                    endedAWait = true
                }
            }
            return endedAWait
        }
    }

    /// Only the delay-seconds form is supported, not the HTTP-date form. Capped, so a bad header cannot
    /// hold a queue for the rest of the run.
    static func retryAfterSeconds(_ error: OneSignalClientError) -> TimeInterval? {
        let value = error.responseHeaders?.first { key, _ in
            (key as? String)?.caseInsensitiveCompare("Retry-After") == .orderedSame
        }?.value
        if let value {
            guard let seconds = TimeInterval("\(value)".trimmingCharacters(in: .whitespaces)),
                  seconds.isFinite, seconds >= 0 else {
                return defaultRetryAfterSeconds
            }
            return min(seconds, maxRetryAfterSeconds)
        }
        return error.code == 429 ? defaultRetryAfterSeconds : nil
    }
}
