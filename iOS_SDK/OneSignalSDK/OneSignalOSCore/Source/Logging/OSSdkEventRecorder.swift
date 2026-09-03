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

/// The events the SDK can ship on the log pipeline. Mirrors the shared KMP `SdkEvent` catalog
/// entry for entry, so a call site can name an event without seeing KMP types, which this
/// module imports implementation-only.
public enum OSSdkEvent {
    /// The device gesture was recognised. Temporary: it answers whether the gesture gets used.
    case deviceGesture
}

/// What a producer needs: `record` and nothing else. A call site takes this as a dependency,
/// so a test can stand in a spy.
public protocol OSSdkEventRecorderProtocol: AnyObject {
    /// Fail-open and non-blocking, from any thread. Drops when the event's flag is off or the
    /// per-process cap is reached, and queues, bounded, while no remote sink is attached.
    func record(event: OSSdkEvent, attributes: [String: String])
}

/// The sink side, driven by `OSRemoteLogger` beside its own start and shutdown. Internal
/// because the telemetry is a KMP type.
protocol OSSdkEventSinkAttaching: AnyObject {
    func attach(_ telemetry: ILogTelemetry)
    func detach()
}

/// Wraps the shared KMP recorder, which owns the flag check, the pre-sink queue and the
/// session cap. This host wires the flag read to `OSFeatureManager` and lets
/// `OSRemoteLogger` attach the remote telemetry, so events ride the sink log lines and crash
/// records use and share its gate: `log_level` present and not `NONE`, no severity filter.
public final class OSSdkEventRecorder: OSSdkEventRecorderProtocol, OSSdkEventSinkAttaching {
    /// One per process, like the rest of the pipeline. Reads the feature manager at record
    /// time, so an `IMMEDIATE` event flag turned off remotely stops the next record.
    public static let shared = OSSdkEventRecorder(isFeatureEnabled: { key in
        OSFeatureManager.shared.isEnabled(featureKey: key)
    })

    private let recorder: ISdkEventRecorder

    /// - Parameter isFeatureEnabled: the feature-manager read for a catalog flag key.
    init(isFeatureEnabled: @escaping (String) -> Bool) {
        recorder = LoggerFactory.shared.createEventRecorder(
            isEnabled: { event in KotlinBoolean(bool: isFeatureEnabled(event.flag.key)) },
            logger: IOSLogger()
        )
    }

    public func record(event: OSSdkEvent, attributes: [String: String]) {
        recorder.record(event: event.kmpEvent, attributes: attributes)
    }

    func attach(_ telemetry: ILogTelemetry) {
        recorder.attach(telemetry: telemetry)
    }

    func detach() {
        recorder.detach()
    }
}

private extension OSSdkEvent {
    var kmpEvent: SdkEvent {
        switch self {
        case .deviceGesture:
            return .deviceGesture
        }
    }
}
