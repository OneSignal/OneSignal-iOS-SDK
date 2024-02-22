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

import XCTest
import ActivityKit

class DummyActivityAttributes : ActivityAttributes {
    public struct ContentState: Codable, Hashable {
    }
}

class DummyOneSignalAwareActivityAttributes : OneSignalLiveActivityAttributes {
    var onesignal: OneSignalLiveActivities.OneSignalLiveActivityAttributeData
    
    public struct ContentState: Codable, Hashable {
    }
}

class LiveActivitiesSwiftTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }
    
    /**
     This test lays out the public APIs of live activities
     */
    func testUserModelMethodAccess() throws {
        OneSignal.LiveActivities.enter("my-activity-id",withToken: "my-token")
        OneSignal.LiveActivities.enter("my-activity-id", withToken: "my-token", withSuccess: {_ in }, withFailure: {_ in })
        OneSignal.LiveActivities.exit("my-activity-id")
        OneSignal.LiveActivities.exit("my-activity-id", withSuccess: {_ in }, withFailure: {_ in })
        
        if #available(iOS 16.1, *) {
            OneSignal.LiveActivities.monitor(DummyOneSignalAwareActivityAttributes.self)
        }
        
        if #available(iOS 17.2, *) {
            OneSignal.LiveActivities.setPushToStartToken(DummyActivityAttributes.self, withToken: "my-token")
            OneSignal.LiveActivities.setPushToStartToken("\(DummyActivityAttributes.self)", withToken: "my-token")
            OneSignal.LiveActivities.removePushToStartToken(DummyActivityAttributes.self)
            OneSignal.LiveActivities.removePushToStartToken("\(DummyActivityAttributes.self)")
        }
    }
}

