import Foundation
@_spi(OneSignalInternal) import OneSignalOSCore

final class CapturingRequestSender {
    let captured = DispatchSemaphore(value: 0)

    private let lock = NSLock()
    private(set) var requests: [URLRequest] = []

    func send(
        request: URLRequest,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        lock.lock()
        requests.append(request)
        lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 202,
            httpVersion: nil,
            headerFields: nil
        )
        DispatchQueue.global().async {
            completion(nil, response, nil)
            self.captured.signal()
        }
    }

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    var firstRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return requests.first
    }
}

let requestSender = CapturingRequestSender()
let logger = OSRemoteLogger(
    installIdProvider: { "catalyst-host" },
    onesignalIdProvider: { nil },
    pushSubscriptionIdProvider: { nil },
    appStateProvider: { "foreground" },
    featureFlagsProvider: { [] },
    remoteLogLevelProvider: { "INFO" },
    exporterLoggingEnabledProvider: { false },
    requestSender: requestSender.send
)

precondition(!logger.kmpVersion.isEmpty)
precondition(!logger.crashStoragePath.isEmpty)

logger.start()
logger.log(level: "INFO", message: "Catalyst logger round trip")

let flushed = DispatchSemaphore(value: 0)
logger.forceFlush {
    flushed.signal()
}
precondition(flushed.wait(timeout: .now() + 5) == .success)
precondition(requestSender.captured.wait(timeout: .now() + 5) == .success)

let request = requestSender.firstRequest
precondition(request?.httpMethod == "POST")
precondition(request?.url?.path == "/sdk/log")
precondition(request?.httpBody?.isEmpty == false)

logger.shutdown()

let requestCountAfterShutdown = requestSender.requestCount
logger.log(level: "INFO", message: "Must not be exported after shutdown")
precondition(requestSender.captured.wait(timeout: .now() + 1) == .timedOut)
precondition(requestSender.requestCount == requestCountAfterShutdown)
