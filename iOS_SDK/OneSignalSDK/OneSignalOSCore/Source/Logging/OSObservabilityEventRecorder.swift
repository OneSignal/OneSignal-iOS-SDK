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

/// Mirrors the KMP `ObservabilityEvent` catalog so a call site can name an event without seeing KMP
/// types, which this module imports implementation-only.
@_spi(OneSignalInternal)
public enum OSObservabilityEvent: CaseIterable {
    /// Temporary: comes out once its usage question is answered.
    case deviceGesture

    /// The `event.name` of the KMP entry, so a test can check the mirror against the catalog.
    var eventName: String {
        kmpEvent.eventName
    }
}

/// The producer-facing contract, so a call site can take a spy in tests.
@_spi(OneSignalInternal)
public protocol OSObservabilityEventRecorderProtocol: AnyObject {
    /// Never throws or blocks. Drops when the event's flag is off or the per-process cap is
    /// reached; queues, bounded, until remote telemetry is attached.
    func record(event: OSObservabilityEvent, attributes: [String: String])
}

/// The attach side, driven by `OSRemoteLogger`. Internal because the telemetry is a KMP type.
protocol OSObservabilityEventRecorderAttaching: AnyObject {
    func attach(_ telemetry: ILogTelemetry)

    /// Ignored unless `telemetry` is the attached one, so a logger that lost the install race
    /// cannot detach the winner.
    func detach(_ telemetry: ILogTelemetry)
}

/// Wraps the shared KMP recorder, which owns the flag check, the pre-attach queue and the
/// per-process cap. Events ride the remote logger's telemetry, so they share the crash gate
/// rather than the severity filter.
@_spi(OneSignalInternal)
public final class OSObservabilityEventRecorder: OSObservabilityEventRecorderProtocol, OSObservabilityEventRecorderAttaching {
    public static let shared = OSObservabilityEventRecorder(isFeatureEnabled: featureIsEnabledIfInitialized)

    private let recorder: IObservabilityEventRecorder

    /// - Parameter isFeatureEnabled: the feature-manager read for a catalog flag key.
    init(isFeatureEnabled: @escaping (String) -> Bool) {
        // Console-only logger: `attach` runs under the remote logger's lifecycle lock, and
        // `OneSignalLog` reaches app listeners synchronously, so a listener that re-enters the
        // SDK would deadlock on that lock.
        recorder = LoggerFactory.shared.createObservabilityEventRecorder(
            flags: OSFeatureFlagReader(isFeatureEnabled: isFeatureEnabled),
            logger: OSCrashLogger()
        )
    }

    /// Never constructs the feature manager: first touch latches every APP_STARTUP flag from
    /// whatever storage returns, and a record can arrive from any thread at any time. Off until
    /// the manager exists, which is also the documented state before the first flags fetch.
    static func featureIsEnabledIfInitialized(_ key: String) -> Bool {
        OSFeatureManager.enabledFeatureKeysIfInitialized().contains(key)
    }

    public func record(event: OSObservabilityEvent, attributes: [String: String]) {
        recorder.record(event: event.kmpEvent, attributes: attributes)
    }

    /// Drops whatever an earlier app id queued; called beside the other app-id-change resets.
    public func reset() {
        recorder.reset()
    }

    func attach(_ telemetry: ILogTelemetry) {
        recorder.attach(telemetry: telemetry)
    }

    func detach(_ telemetry: ILogTelemetry) {
        recorder.detach(telemetry: telemetry)
    }
}

/// Answers the KMP recorder's flag lookups; each event's own gate decides which flag to ask about.
private final class OSFeatureFlagReader: IFeatureFlagReader {
    private let isFeatureEnabled: (String) -> Bool

    init(isFeatureEnabled: @escaping (String) -> Bool) {
        self.isFeatureEnabled = isFeatureEnabled
    }

    func isEnabled(flag: FeatureFlag) -> Bool {
        isFeatureEnabled(flag.key)
    }
}

private extension OSObservabilityEvent {
    var kmpEvent: ObservabilityEvent {
        switch self {
        case .deviceGesture:
            return .deviceGesture
        }
    }
}
