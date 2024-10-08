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

// Effectively blanks out this file for Mac Catalyst
#if targetEnvironment(macCatalyst)
#else

/**
 A default struct conforming to OneSignalLiveActivityAttributes which is registered with OneSignal as a Live Activity
 through `OneSignal.LiveActivities.setupDefault`.  The only action required by the customer app is
 to implement a Widget in their Widget Extension with an `ActivityConfiguration` for
 `DefaultLiveActivityAttributes`.  All properties (attributes and content-state) within this widget are
 dynamically defined as a dictionary of values within the static `data` property. Note that the `data` properties are
 required in the payloads.
 
 Example "start notification" payload using DefaultLiveActivityAttributes:
 ```
 {
   "name": "Live Activity Update XXXX",
   "event": "start",
   "activity_type": "DefaultLiveActivityAttributes",
   "event_attributes": {
       "data": {
         "yourAttributesKey": "yourAttributesValue"
       }
    },
   "event_updates": {
       "data": {
         "yourContentStateKey": "yourContentStateValue"
       }
   }
 }
 ```

 Example "update notification" payload using DefaultLiveActivityAttributes:
 ```
 {
   "name": "Live Activity Update XXXX",
   "event": "update",
   "event_updates": {
       "data": {
         "yourContentStateKey": "yourContentStateValue"
       }
   }
 }
 ```
 */
public struct DefaultLiveActivityAttributes: OneSignalLiveActivityAttributes {
    public struct ContentState: OneSignalLiveActivityContentState {
        public var data: [String: AnyCodable]
        public var onesignal: OneSignalLiveActivityContentStateData?
    }

    public var data: [String: AnyCodable]
    public var onesignal: OneSignalLiveActivityAttributeData
}
#endif
