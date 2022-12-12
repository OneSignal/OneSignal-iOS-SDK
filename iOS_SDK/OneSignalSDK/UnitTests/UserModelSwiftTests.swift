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
    static var User: OSUser {
        return __user()
    }

    static var Notifications: OSNotifications.Type {
        return OneSignal.__notifications()
    }

    static var Session: OSSession.Type {
        return __session()
    }

    static var InAppMessages: OSInAppMessages.Type {
        return __inAppMessages()
    }
}

extension OSInAppMessages {
    static var Paused: Bool {
        get {
            return __paused()
        }
        set {
            __paused(newValue)
        }
    }
}

// Non-class type 'OSPushSubscriptionTestObserver' cannot conform to class protocol 'OSPushSubscriptionObserver'
// ^ Cannot use a struct for an OSPushSubscriptionObserver

class OSPushSubscriptionTestObserver: OSPushSubscriptionObserver {
    func onOSPushSubscriptionChanged(stateChanges: OneSignalUser.OSPushSubscriptionStateChanges) {
        print("🔥 onOSPushSubscriptionChanged \(stateChanges.from) -> \(stateChanges.to)")
        // dump(stateChanges.from) -> uncomment for more verbose log during testing
        // dump(stateChanges.to) -> uncomment for more verbose log during testing
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
        OneSignal.login("foo")
        OneSignal.login(externalId: "foo", token: "someToken")
        OneSignal.login(externalId: "foo", token: nil)
        OneSignal.logout()

        // Aliases
        OneSignal.User.addAlias(label: "foo", id: "bar")
        OneSignal.User.addAliases(["foo": "foo1", "bar": "bar2"])
        OneSignal.User.removeAlias("foo")
        OneSignal.User.removeAliases(["foo", "bar"])

        // Tags
        OneSignal.User.addTag(key: "foo", value: "bar")
        OneSignal.User.addTags(["foo": "foo1", "bar": "bar2"])
        OneSignal.User.removeTag("foo")
        OneSignal.User.removeTags(["foo", "bar"])

        // Email
        OneSignal.User.addEmail("person@example.com")
        _ = OneSignal.User.removeEmail("person@example.com")

        // SMS
        OneSignal.User.addSmsNumber("+15551231234")
        _ = OneSignal.User.removeSmsNumber("+15551231234")

        // Triggers
        OneSignal.InAppMessages.addTrigger("foo", withValue: "bar")
        OneSignal.InAppMessages.addTriggers(["foo": "foo1", "bar": "bar2"])
        OneSignal.InAppMessages.removeTrigger("foo")
        OneSignal.InAppMessages.removeTriggers(["foo", "bar"])
        OneSignal.InAppMessages.clearTriggers()

        OneSignal.InAppMessages.setClickHandler { action in
            NSLog("action \(action.description)")
        }
        OneSignal.InAppMessages.setLifecycleHandler(nil)
    }

    /**
     This is to collect things that should not work, but do for now.
     */
    func testTheseShouldNotWork() throws {
        // Should not be settable
        // OneSignal.user.pushSubscription.token = UUID() // <- Confirmed that users can't set token
        // OneSignal.user.pushSubscription.subscriptionId = UUID() // <- Confirmed that users can't set subscriptionId
    }

    /**
     Test the access of properties and methods, and setting properties related to the push subscription.
     */
    func testPushSubscriptionPropertiesAccess() throws {
        // TODO: Fix these unit tests

//        // Create a user and mock pushSubscription
//        let user = OneSignal.user
//        user.testCreatePushSubscription(subscriptionId: UUID(), token: UUID(), enabled: false)
//
//        // Access properties of the pushSubscription
//        _ = user.pushSubscription.subscriptionId
//        _ = user.pushSubscription.token
//        _ = user.pushSubscription.enabled
//
//        // Set the enabled property of the pushSubscription
//        user.pushSubscription.enabled = true
//
//        // Create a push subscription observer
//        let observer = OSPushSubscriptionTestObserver()

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
        OneSignal.login("user01")

        // Check that deltas for alias (Identity) are created correctly and enqueued.
        print("🔥 Unit Tests adding alias label_01: user_01")
        OneSignal.User.addAlias(label: "label_01", id: "user_01")
        OneSignal.User.removeAlias("nonexistent")
        OneSignal.User.removeAlias("label_01")
        OneSignal.User.addAlias(label: "label_02", id: "user_02")
        OneSignal.User.addAliases(["test1": "user1", "test2": "user2", "test3": "user3"])
        OneSignal.User.removeAliases(["test1", "label_01", "test2"])

        OneSignal.User.addTag(key: "foo", value: "bar")

        // Sleep to allow the flush to be called 1 time.
        Thread.sleep(forTimeInterval: 6)
    }

    /**
     Test login and logout and creation of guest users.
     */
    func testLoginLogout() throws {
        // A guest user is created when OneSignal.User is accessed
        OneSignal.User.addEmail("test@email.com")
        // ... and more to be added
    }

    /**
     Test email and sms subscriptions. 2 Deltas are created for each add.
     */
    func testEmailAndSmsSubscriptions() throws {
        OneSignal.User.addEmail("test@example.com")
        OneSignal.User.addSmsNumber("+15551231234")

        // Sleep to allow the flush to be called 1 time.
        Thread.sleep(forTimeInterval: 6)
    }

    /**
     Temp test.
     */
    func testTempTester() throws {
        OneSignal.Notifications.requestPermission { accepted in
            print("🔥 promptForPushNotificationsWithUserResponse: \(accepted)")
        }
        OneSignal.Notifications.requestPermission({ accepted in
            print("🔥 promptForPushNotificationsWithUserResponse: \(accepted)")
        }, fallbackToSettings: true)

        // IAM pausing
        OneSignal.InAppMessages.Paused = true
        let paused = OneSignal.InAppMessages.Paused
    }
    
    func testJWTTokenExpired() {
        OneSignal.User.onJwtExpired { externalId, completion in
            let newToken = externalId + "newtokenbasedonexternalid"
            completion(newToken)
        }
    }
}
