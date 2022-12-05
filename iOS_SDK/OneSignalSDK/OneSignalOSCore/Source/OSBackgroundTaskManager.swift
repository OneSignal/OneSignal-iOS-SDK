/*
 Modified MIT License

 Copyright 2022 OneSignal

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

@objc
public protocol OSBackgroundTaskManagerDelegate {
    func beginBackgroundTask(_ taskIdentifier: String)
    func endBackgroundTask(_ taskIdentifier: String)
    func setTaskInvalid(_ taskIdentifier: String)
}

// TODO: Migrate more background tasks to use this...

// check if Core needs to use this, then ok to live here
@objc
public class OSBackgroundTaskManager: NSObject {
    @objc public static weak var delegate: OSBackgroundTaskManagerDelegate?

    @objc
    public static func beginBackgroundTask(_ taskIdentifier: String) {
        guard let delegate = delegate else {
            // Log error, no delegate
            return
        }
        delegate.beginBackgroundTask(taskIdentifier)
    }

    @objc
    public static func endBackgroundTask(_ taskIdentifier: String) {
        guard let delegate = delegate else {
            // Log error, no delegate
            return
        }
        delegate.endBackgroundTask(taskIdentifier)
    }

    @objc
    public static func setTaskInvalid(_ taskIdentifier: String) {
        guard let delegate = delegate else {
            // Log error, no delegate
            // But not necessarily an error because this task won't exist
            // Can be called in initialization of services before delegate is set
            return
        }
        delegate.setTaskInvalid(taskIdentifier)
    }
}
