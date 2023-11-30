/*
 Modified MIT License

 Copyright 2023 OneSignal

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

@objc
public class OSUserState: NSObject {
    @objc public let onesignalId: String?
    @objc public let externalId: String?

    @objc public override var description: String {
        return "<OSUserState: onesignalId: \(onesignalId ?? "nil"), externalId: \(externalId ?? "nil")>"
    }

    init(onesignalId: String?, externalId: String?) {
        self.onesignalId = onesignalId
        self.externalId = externalId
    }

    @objc public func jsonRepresentation() -> NSDictionary {
        return [
            "onesignalId": onesignalId ?? "",
            "externalId": externalId ?? ""
        ]
    }
}

@objc
public class OSUserChangedState: NSObject {
    @objc public let previous: OSUserState
    @objc public let current: OSUserState

    @objc public override var description: String {
        return "<OSUserState:\nprevious: \(self.previous),\ncurrent: \(self.current)\n>"
    }

    init(previous: OSUserState, current: OSUserState) {
        self.previous = previous
        self.current = current
    }

    @objc public func jsonRepresentation() -> NSDictionary {
        return ["previous": previous.jsonRepresentation(), "current": current.jsonRepresentation()]
    }
}

@objc public protocol OSUserStateObserver {
    @objc func onUserStateDidChange(state: OSUserChangedState)
}
