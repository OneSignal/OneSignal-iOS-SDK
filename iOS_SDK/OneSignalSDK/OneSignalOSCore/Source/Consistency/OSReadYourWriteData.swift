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

@objcMembers
public class OSReadYourWriteData: NSObject {
    public let rywToken: String?
    public let rywDelay: NSNumber?

    public init(rywToken: String?, rywDelay: NSNumber?) {
        self.rywToken = rywToken
        self.rywDelay = rywDelay
    }

    // Override `isEqual` for custom equality comparison.
    override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? OSReadYourWriteData else {
            return false
        }

        let tokensAreEqual = (self.rywToken == other.rywToken) || (self.rywToken == nil && other.rywToken == nil)
        let delaysAreEqual = (self.rywDelay?.isEqual(to: other.rywDelay ?? 0) ?? false) || (self.rywDelay == nil && other.rywDelay == nil)

        return tokensAreEqual && delaysAreEqual
    }

    // Override `hash` to maintain hashability.
    // This is because two equal objects must have the same hash value.
    // Since we are overriding isEqual we must also override `hash`
    override public var hash: Int {
        var hasher = Hasher()
        hasher.combine(rywToken)
        hasher.combine(rywDelay)
        return hasher.finalize()
    }
}
