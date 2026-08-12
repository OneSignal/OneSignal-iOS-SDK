import Foundation
import OneSignalOSCore

let logger = OSRemoteLogger(
    installIdProvider: { "catalyst-host" },
    onesignalIdProvider: { nil },
    pushSubscriptionIdProvider: { nil },
    appStateProvider: { "foreground" },
    featureFlagsProvider: { [] },
    remoteLogLevelProvider: { "INFO" },
    exporterLoggingEnabledProvider: { false }
)

precondition(logger.kmpVersion != "unavailable")
precondition(logger.crashStoragePath != "unavailable")

logger.log(level: "INFO", message: "Catalyst logger round trip")

let flushed = DispatchSemaphore(value: 0)
logger.forceFlush {
    flushed.signal()
}
precondition(flushed.wait(timeout: .now() + 5) == .success)
logger.shutdown()
