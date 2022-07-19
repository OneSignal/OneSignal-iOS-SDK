//
//  SwiftTestFile.swift
//  OneSignalExample
//
//  Copyright © 2022 OneSignal. All rights reserved.
//

import Foundation
import OneSignal

@objc
public class SwiftTestFile: NSObject {
    @objc
    public func testSwift() -> Void {
        // Testing access of methods and parameters
        
        // User Identity
        var _ = OneSignal.user
        
        OneSignal.login("foo") { user in
            var _ = user
        }
       
        OneSignal.login("foo", withToken: "someToken") { user in
            var _ = user
        }
        
        var _ = OneSignal.loginGuest { user in
            var _ = user
        }
               
        // TODO: access user like a property instead of user()
        
        // Aliases
        OneSignal.user().addAlias("foo", id: "bar")
        OneSignal.user().addAliases(["foo": "foo1", "bar": "bar2"])
        OneSignal.user().removeAlias("foo")
        OneSignal.user().removeAliases(["foo", "bar"])
        
        // Tags
        OneSignal.user().setTag("foo", "bar")
        OneSignal.user().setTags(["foo": "foo1", "bar": "bar2"])
        OneSignal.user().removeTag("foo")
        OneSignal.user().removeTags(["foo", "bar"])
        
        // Outcomes
        OneSignal.user().setOutcome("foo")
        OneSignal.user().setUniqueOutcome("foo")
        OneSignal.user().setOutcomeWithValue("foo", 4.50)
        
        // Email
        OneSignal.user().addEmail("person@example.com")
        OneSignal.user().removeEmail("person@example.com")

        // SMS
        OneSignal.user().addSmsNumber("+15551231234")
        OneSignal.user().removeSmsNumber("+15551231234")
        
        // Triggers
        OneSignal.user().setTrigger("foo", "bar")
        OneSignal.user().setTriggers(["foo": "foo1", "bar": "bar2"])
        OneSignal.user().removeTrigger("foo")
        OneSignal.user().removeTriggers(["foo", "bar"])

    }
}
