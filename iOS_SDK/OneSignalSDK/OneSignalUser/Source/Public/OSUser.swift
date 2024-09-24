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

/**
 This is the user interface exposed to the public.
 */
@objc public protocol OSUser {
    var pushSubscription: OSPushSubscription { get }
    var onesignalId: String? { get }
    var externalId: String? { get }
    /**
     Add an observer to the user state, allowing the provider to be notified when the user state has changed.
     Important: When using the observer to retrieve the `onesignalId`, check the `externalId` as well to confirm the values are associated with the expected user.
     */
    func addObserver(_ observer: OSUserStateObserver)
    func removeObserver(_ observer: OSUserStateObserver)
    // Aliases
    func addAlias(label: String, id: String)
    func addAliases(_ aliases: [String: String])
    func removeAlias(_ label: String)
    func removeAliases(_ labels: [String])
    // Tags
    func addTag(key: String, value: String)
    func addTags(_ tags: [String: String])
    func removeTag(_ tag: String)
    func removeTags(_ tags: [String])
    func getTags() -> [String: String]
    // Email
    func addEmail(_ email: String)
    func removeEmail(_ email: String)
    // SMS
    func addSms(_ number: String)
    func removeSms(_ number: String)
    // Language
    func setLanguage(_ language: String)
    // JWT Token Expire
    typealias OSJwtInvalidatedHandler =  (_ event: OSJwtInvalidatedEvent) -> Void
    func onJwtInvalidated(invalidatedHandler: @escaping OSJwtInvalidatedHandler)
}
