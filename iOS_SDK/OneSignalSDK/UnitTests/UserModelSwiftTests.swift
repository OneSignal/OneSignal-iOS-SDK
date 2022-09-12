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

import XCTest

// TODO: UM This goes elsewhere
extension OneSignal {
    static var user: OSUser {
        return OneSignal.__user()
    }
}

// Non-class type 'OSPushSubscriptionTestObserver' cannot conform to class protocol 'OSPushSubscriptionObserver'
// ^ Cannot use a struct for an OSPushSubscriptionObserver

class OSPushSubscriptionTestObserver: OSPushSubscriptionObserver {
    func onOSPushSubscriptionChanged(previous: OSPushSubscriptionState, current: OSPushSubscriptionState) {
        print("🔥 onOSPushSubscriptionChanged \(previous) -> \(current)")
        // dump(previous) -> uncomment for more verbose log during testing
        // dump(current) -> uncomment for more verbose log during testing
    }
}

class UserModelSwiftTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        try super.tearDownWithError()
    }

    /**
     This test lays out the public APIs of the user model
     */
    func testUserModelMethodAccess() throws {

        // User Identity
        var myUser: OSUser = OneSignal.user

        OneSignal.login("foo") { user in
            myUser = user
        }

        OneSignal.login("foo", withToken: "someToken") { user in
            myUser = user
        }

        var _ = OneSignal.loginGuest { user in
            myUser = user
        }

        // Aliases
        OneSignal.user.addAlias(label: "foo", id: "bar")
        OneSignal.user.addAliases(["foo": "foo1", "bar": "bar2"])
        OneSignal.user.removeAlias("foo")
        OneSignal.user.removeAliases(["foo", "bar"])

        // Tags
        OneSignal.user.setTag(key: "foo", value: "bar")
        OneSignal.user.setTags(["foo": "foo1", "bar": "bar2"])
        OneSignal.user.removeTag("foo")
        OneSignal.user.removeTags(["foo", "bar"])
        OneSignal.user.getTag("foo")

        // Outcomes
        OneSignal.user.setOutcome("foo")
        OneSignal.user.setUniqueOutcome("foo")
        OneSignal.user.setOutcome(name: "foo", value: 4.50)

        // Email
        OneSignal.user.addEmail("person@example.com")
        OneSignal.user.removeEmail("person@example.com")

        // SMS
        OneSignal.user.addSmsNumber("+15551231234")
        OneSignal.user.removeSmsNumber("+15551231234")

        // Triggers
        OneSignal.user.setTrigger(key: "foo", value: "bar")
        OneSignal.user.setTriggers(["foo": "foo1", "bar": "bar2"])
        OneSignal.user.removeTrigger("foo")
        OneSignal.user.removeTriggers(["foo", "bar"])

        XCTAssertNotNil(myUser)
    }

    /**
     This is to collect things that should not work, but do for now.
     */
    func testTheseShouldNotWork() throws {
        // Should not be accessible
        _ = OneSignalUserManager.user

        // Should not be settable
        // OneSignal.user.pushSubscription.token = UUID() // <- Confirmed that users can't set token
        // OneSignal.user.pushSubscription.subscriptionId = UUID() // <- Confirmed that users can't set subscriptionId
    }

    /**
     Test the access of properties and methods, and setting properties related to the push subscription.
     */
    func testPushSubscriptionPropertiesAccess() throws {
        // Create a user and mock pushSubscription
        let user = OneSignal.user
        user.testCreatePushSubscription(subscriptionId: UUID(), token: UUID(), enabled: false)

        // Access properties of the pushSubscription
        _ = user.pushSubscription.subscriptionId
        _ = user.pushSubscription.token
        _ = user.pushSubscription.enabled

        // Set the enabled property of the pushSubscription
        user.pushSubscription.enabled = true

        // Create a push subscription observer
        let observer = OSPushSubscriptionTestObserver()

        // Push subscription observers are not user-scoped
        // TODO: UM The following does not build as of now
        // OneSignal.addSubscriptionObserver(observer)
        // OneSignal.removeSubscriptionObserver(observer)
    }

    /**
     Test the model repo hook up via a login with external ID and setting alias.
     Test the operation repo hookup as well and check the deltas being enqueued and flushed.
     */
    func testModelAndOperationRepositoryHookUpWithLoginAndSetAlias() throws {
        // login an user with external ID
        OneSignal.login("user01", withResult: { user in
            print("🔥 Unit Tests: logged in user is \(user)")
        })

        let user = OneSignal.user

        // Check that deltas for alias (Identity) are created correctly and enqueued.
        print("🔥 Unit Tests adding alias label_01: user_01")
        user.addAlias(label: "label_01", id: "user_01")
        user.removeAlias("nonexistent")
        user.removeAlias("label_01")
        user.addAlias(label: "label_02", id: "user_02")
        user.addAliases(["test1": "user1", "test2": "user2", "test3": "user3"])
        user.removeAliases(["test1", "label_01", "test2"])

        user.setTag(key: "foo", value: "bar")
        
        // Sleep to allow the flush to be called 1 time.
        Thread.sleep(forTimeInterval: 6)
    }
}
