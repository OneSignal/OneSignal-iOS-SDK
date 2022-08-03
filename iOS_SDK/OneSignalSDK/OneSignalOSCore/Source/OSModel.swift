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
open class OSModel: NSObject {
    
    public var id: String? {
        didSet  {
            print("🔥 didSet OSModel.id from \(oldValue) to \(id).")
            self.set(name: "id", value: id)
        }
    }
    var data: [String : AnyObject?] = [:]
    let changeNotifier: OSEventProducer<OSModelChangedHandler>

    public init(changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        self.changeNotifier = changeNotifier
    }
    
    public func set<T>(name: String, value: T) {
        
        let oldValue = data[name] as AnyObject // Error encountered: Argument type 'AnyObject?' expected to be an instance of a class or class-constrained type
        
        let newValue = value as AnyObject // Error encountered: Cannot assign value of type 'T' to subscript of type 'AnyObject??'
        
        if (oldValue === newValue) { return }
            
        data[name] = newValue

        let changeArgs = OSModelChangedArgs(model: self, property: name, oldValue: oldValue, newValue: newValue)
        self.changeNotifier.fire { modelChangeHandler in
            modelChangeHandler.onChanged(args: changeArgs)
        }
    }

    public func get<T>(_ name: String) -> T {
        return data[name] as! T
    }

    // TODO: Other get function which creates if not found
}

