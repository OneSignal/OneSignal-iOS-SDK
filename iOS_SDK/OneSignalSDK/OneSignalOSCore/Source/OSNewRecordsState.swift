/*
 Modified MIT License

 Copyright 2024 OneSignal

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

/**
 * Purpose: Keeps track of IDs that were just created on the backend.
 * This list gets used to delay network calls to ensure upcoming
 * requests are ready to be accepted by the backend.
 */
public class OSNewRecordsState {
    /**
     Params:
     - Key - a string ID such as onesignal ID or subscription ID
     - Value - a Date timestamp of when the ID was created
     */
    private var records: [String: Date] = [:]
    private let lock = NSRecursiveLock()

    public init() { }

    /**
     Only add a new record with the current timestamp if overwriting is requested, or it is not already present
     */
    public func add(_ key: String, _ overwrite: Bool = false) {
        lock.withLock {
            if overwrite || records[key] == nil {
                records[key] = Date()
            }
        }
    }

    public func canAccess(_ key: String) -> Bool {
        lock.withLock {
            guard let timeLastMovedOrCreated = records[key] else {
                return true
            }

            let minimumTime = timeLastMovedOrCreated.addingTimeInterval(TimeInterval(OP_REPO_POST_CREATE_DELAY_SECONDS))

            return Date() >= minimumTime
        }
    }
}
