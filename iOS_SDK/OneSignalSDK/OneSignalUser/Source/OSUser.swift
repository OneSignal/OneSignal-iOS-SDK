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
import OneSignalCore

@objc
public class OSUser: NSObject {
    
    // Aliases
    
    @objc
    public func addAlias(_ label: String, id: String) -> Void {
        print("🔥 OSUser addAlias() called")
    }
    
    @objc
    public func addAliases(_ aliases: [String : String]) -> Void {
        print("🔥 OSUser addAliases() called")
    }
    
    @objc
    public func removeAlias(_ label: String) -> Void {
        print("🔥 OSUser removeAlias() called")
    }
    
    @objc
    public func removeAliases(_ labels: [String]) -> Void {
        print("🔥 OSUser removeAliases() called")
    }
    
    // Tags
    
    @objc
    public func setTag(_ key: String, _ value: String) -> Void {
        // TODO: Value for tags can be non-string?
        print("🔥 OSUser sendTag() called")
    }
    
    @objc
    public func setTags(_ tags: [String : String]) -> Void {
        print("🔥 OSUser sendTags() called")
    }
    
    @objc
    public func removeTag(_ tag: String) -> Void {
        print("🔥 OSUser removeTag() called")
    }
    
    @objc
    public func removeTags(_ tags: [String]) -> Void {
        print("🔥 OSUser removeTags() called")
    }
    
    // Outcomes
    
    @objc
    public func setOutcome(_ name: String) -> Void {
        print("🔥 OSUser sendOutcome() called")
    }
    
    @objc
    public func setUniqueOutcome(_ name: String) -> Void {
        print("🔥 OSUser setUniqueOutcome() called")
    }
    
    @objc
    public func setOutcomeWithValue(_ name: String, _ value: Float) -> Void {
        print("🔥 OSUser setOutcomeWithValue() called")
    }
    
    // Email
    
    @objc
    public func addEmail(_ email: String) -> Void {
        print("🔥 OSUser addEmail() called")
    }
    
    @objc
    public func removeEmail(_ email: String) -> Void {
        print("🔥 OSUser removeEmail() called")
    }
    
    // SMS
    
    @objc
    public func addSmsNumber(_ number: String) -> Void {
        print("🔥 OSUser addPhoneNumber() called")
    }
    
    @objc
    public func removeSmsNumber(_ number: String) -> Void {
        print("🔥 OSUser removePhoneNumber() called")
    }
    
    // Triggers
    
    @objc
    public func setTrigger(_ key: String, _ value: String) -> Void {
        // TODO: Value for trigger can be non-string
        print("🔥 OSUser setTrigger() called")
    }
    
    @objc
    public func setTriggers(_ triggers: [String : String]) -> Void {
        print("🔥 OSUser setTriggers() called")
    }
    
    @objc
    public func removeTrigger(_ trigger: String) -> Void {
        print("🔥 OSUser removeTrigger() called")
    }
    
    @objc
    public func removeTriggers(_ triggers: [String]) -> Void {
        print("🔥 OSUser removeTriggers() called")
    }
}
