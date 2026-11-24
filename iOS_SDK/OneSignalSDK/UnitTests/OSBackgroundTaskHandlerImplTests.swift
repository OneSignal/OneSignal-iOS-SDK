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

import OneSignalCoreMocks
import OneSignalOSCore
import UIKit
import XCTest

final class OSBackgroundTaskHandlerImplTests: XCTestCase {
    private final class FakeUIKitTasks {
        private let lock = NSLock()
        private var nextRawId = 1
        private var _begunNames: [String] = []
        private var _expirationHandlers: [UIBackgroundTaskIdentifier: () -> Void] = [:]
        private var _endedIds: [UIBackgroundTaskIdentifier] = []
        private var _endedOnMainThread: [Bool] = []
        var nextReturnedId: UIBackgroundTaskIdentifier?
        var expireSynchronously = false

        var begunNames: [String] { lock.withLock { _begunNames } }
        var endedIds: [UIBackgroundTaskIdentifier] { lock.withLock { _endedIds } }
        var endedOnMainThread: [Bool] { lock.withLock { _endedOnMainThread } }

        func begin(_ name: String, expirationHandler: @escaping () -> Void) -> UIBackgroundTaskIdentifier {
            let taskId: UIBackgroundTaskIdentifier = lock.withLock {
                _begunNames.append(name)
                if let fixed = nextReturnedId {
                    return fixed
                }
                let identifier = UIBackgroundTaskIdentifier(rawValue: nextRawId)
                nextRawId += 1
                _expirationHandlers[identifier] = expirationHandler
                return identifier
            }
            if expireSynchronously {
                expirationHandler()
            }
            return taskId
        }

        func end(_ taskId: UIBackgroundTaskIdentifier) {
            lock.withLock {
                _endedIds.append(taskId)
                _endedOnMainThread.append(Thread.isMainThread)
            }
        }

        func expire(_ taskId: UIBackgroundTaskIdentifier) {
            let handler = lock.withLock { _expirationHandlers[taskId] }
            handler?()
        }
    }

    private func makeHandler(
        timeLimit: TimeInterval = 60,
        tasks: FakeUIKitTasks
    ) -> OSBackgroundTaskHandlerImpl {
        OSBackgroundTaskHandlerImpl(
            timeLimit: timeLimit,
            beginTask: { name, expirationHandler in
                tasks.begin(name, expirationHandler: expirationHandler)
            },
            endTask: { taskId in
                tasks.end(taskId)
            }
        )
    }

    func testBeginPassesTaskNameToUIKit() {
        let tasks = FakeUIKitTasks()
        let handler = makeHandler(tasks: tasks)

        handler.beginBackgroundTask("OPERATION_REPO_BACKGROUND_TASK")

        XCTAssertEqual(tasks.begunNames, ["OPERATION_REPO_BACKGROUND_TASK"])
        handler.endBackgroundTask("OPERATION_REPO_BACKGROUND_TASK")
    }

    func testBeginInvalidTaskIsIgnored() {
        let tasks = FakeUIKitTasks()
        tasks.nextReturnedId = .invalid
        let handler = makeHandler(timeLimit: 0.05, tasks: tasks)

        handler.beginBackgroundTask("TASK")
        handler.endBackgroundTask("TASK")
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertTrue(tasks.endedIds.isEmpty)
    }

    func testMultipleBeginsWithSameNameKeepAndEndEveryTask() {
        let tasks = FakeUIKitTasks()
        let handler = makeHandler(tasks: tasks)

        handler.beginBackgroundTask("SHARED_TASK")
        handler.beginBackgroundTask("SHARED_TASK")
        handler.endBackgroundTask("SHARED_TASK")

        XCTAssertEqual(tasks.endedIds, [
            UIBackgroundTaskIdentifier(rawValue: 1),
            UIBackgroundTaskIdentifier(rawValue: 2)
        ])
    }

    func testExpirationHandlerEndsOnlyItsOwnTask() {
        let tasks = FakeUIKitTasks()
        let handler = makeHandler(tasks: tasks)
        let first = UIBackgroundTaskIdentifier(rawValue: 1)
        let second = UIBackgroundTaskIdentifier(rawValue: 2)

        handler.beginBackgroundTask("SHARED_TASK")
        handler.beginBackgroundTask("SHARED_TASK")
        tasks.expire(first)

        XCTAssertEqual(tasks.endedIds, [first])

        handler.endBackgroundTask("SHARED_TASK")

        XCTAssertEqual(tasks.endedIds, [first, second])
    }

    func testSetTaskInvalidEndsOpenTasks() {
        let tasks = FakeUIKitTasks()
        let handler = makeHandler(tasks: tasks)

        handler.beginBackgroundTask("SHARED_TASK")
        handler.beginBackgroundTask("SHARED_TASK")
        handler.setTaskInvalid("SHARED_TASK")

        XCTAssertEqual(tasks.endedIds, [
            UIBackgroundTaskIdentifier(rawValue: 1),
            UIBackgroundTaskIdentifier(rawValue: 2)
        ])
    }

    func testTaskEndsAtTimeLimitOffMainThread() {
        let tasks = FakeUIKitTasks()
        let handler = makeHandler(timeLimit: 0.05, tasks: tasks)
        let first = UIBackgroundTaskIdentifier(rawValue: 1)

        handler.beginBackgroundTask("STALLED_TASK")

        OneSignalCoreMocks.waitUntil("Task was still open after its time limit") {
            tasks.endedIds == [first]
        }
        XCTAssertEqual(tasks.endedOnMainThread, [false])

        tasks.expire(first)
        handler.endBackgroundTask("STALLED_TASK")

        XCTAssertEqual(tasks.endedIds, [first])
    }

    func testEndingEarlyCancelsTimeLimitAndDoesNotDoubleEnd() {
        let tasks = FakeUIKitTasks()
        let handler = makeHandler(timeLimit: 0.05, tasks: tasks)
        let first = UIBackgroundTaskIdentifier(rawValue: 1)

        handler.beginBackgroundTask("FAST_TASK")
        handler.endBackgroundTask("FAST_TASK")
        Thread.sleep(forTimeInterval: 0.15)

        XCTAssertEqual(tasks.endedIds, [first])
    }

    func testExpirationBeforeTrackingStillEndsTaskOnce() {
        let tasks = FakeUIKitTasks()
        tasks.expireSynchronously = true
        let handler = makeHandler(timeLimit: 0.05, tasks: tasks)
        let first = UIBackgroundTaskIdentifier(rawValue: 1)

        handler.beginBackgroundTask("IMMEDIATE_EXPIRE")
        handler.endBackgroundTask("IMMEDIATE_EXPIRE")
        Thread.sleep(forTimeInterval: 0.1)

        XCTAssertEqual(tasks.endedIds, [first])
    }
}
