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

import OneSignalCore
import OneSignalOSCore
import ActivityKit

enum LiveActivitiesError: Error {
    case invalidActivityType(String)
}

@objc(OneSignalLiveActivitiesManagerImpl)
public class OneSignalLiveActivitiesManagerImpl: NSObject, OSLiveActivities {
    private static let _executor: OSLiveActivitiesExecutor = OSLiveActivitiesExecutor(requestDispatch: DispatchQueue(label: "OneSignal.LiveActivities"))

    @objc
    public static func liveActivities() -> AnyClass {
        return OneSignalLiveActivitiesManagerImpl.self
    }

    @objc
    public static func start() {
        _executor.start()
    }

    @objc
    public static func enter(_ activityId: String, withToken: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities enter called with activityId: \(activityId) token: \(withToken)")
        _executor.append(OSRequestSetUpdateToken(key: activityId, token: withToken))
    }

    @objc
    public static func exit(_ activityId: String) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities leave called with activityId: \(activityId)")
        _executor.append(OSRequestRemoveUpdateToken(key: activityId))
    }

    @objc
    @available(iOS 17.2, *)
    public static func setPushToStartToken(_ activityType: String, withToken: String) throws {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities setStartToken called with activityType: \(activityType) token: \(withToken)")

        guard let activityType = activityType.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlUserAllowed) else {
            throw LiveActivitiesError.invalidActivityType("Cannot translate activity type to url encoded string.")
        }

        _executor.append(OSRequestSetStartToken(key: activityType, token: withToken))
    }

    @objc
    @available(iOS 17.2, *)
    public static func removePushToStartToken(_ activityType: String) throws {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities removeStartToken called with activityType: \(activityType)")

        guard let activityType = activityType.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlUserAllowed) else {
            throw LiveActivitiesError.invalidActivityType("Cannot translate activity type to url encoded string.")
        }

        _executor.append(OSRequestRemoveStartToken(key: "\(activityType)"))
    }

    @available(iOS 17.2, *)
    public static func setPushToStartToken<T>(_ activityType: T.Type, withToken: String) where T: ActivityAttributes {
        do {
            try OneSignalLiveActivitiesManagerImpl.setPushToStartToken("\(activityType)", withToken: withToken)
        } catch LiveActivitiesError.invalidActivityType(let message) {
            // This should never happen, because a struct name should always be URL encodable.
            OneSignalLog.onesignalLog(.LL_ERROR, message: message)
        } catch {
            // This should never happen.
            OneSignalLog.onesignalLog(.LL_ERROR, message: "Could not set push to start token")
        }
    }

    @available(iOS 17.2, *)
    public static func removePushToStartToken<T>(_ activityType: T.Type) where T: ActivityAttributes {
        do {
            try OneSignalLiveActivitiesManagerImpl.removePushToStartToken("\(activityType)")
        } catch LiveActivitiesError.invalidActivityType(let message) {
            // This should never happen, because a struct name should always be URL encodable.
            OneSignalLog.onesignalLog(.LL_ERROR, message: message)
        } catch {
            // This should never happen.
            OneSignalLog.onesignalLog(.LL_ERROR, message: "Could not set push to start token")
        }
    }

    @objc
    public static func enter(_ activityId: String, withToken: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?) {
        enter(activityId, withToken: withToken)

        if withSuccess != nil {
            DispatchQueue.main.async {
                withSuccess!([AnyHashable: Any]())
            }
        }
    }

    @objc
    public static func exit(_ activityId: String, withSuccess: OSResultSuccessBlock?, withFailure: OSFailureBlock?) {
        exit(activityId)

        if withSuccess != nil {
            DispatchQueue.main.async {
                withSuccess!([AnyHashable: Any]())
            }
        }
    }

    @available(iOS 16.1, *)
    public static func setup<Attributes: OneSignalLiveActivityAttributes>(_ activityType: Attributes.Type, options: LiveActivitySetupOptions? = nil) {
        if #available(iOS 17.2, *) {
            listenForPushToStart(activityType, options: options)
        }
        listenForActivity(activityType, options: options)
    }

    @objc
    @available(iOS 16.1, *)
    public static func setupDefault(options: LiveActivitySetupOptions? = nil) {
        setup(DefaultLiveActivityAttributes.self, options: options)
    }

    @objc
    @available(iOS 16.1, *)
    public static func startDefault(_ activityId: String, attributes: [String: Any], content: [String: Any]) {
        let oneSignalAttribute = OneSignalLiveActivityAttributeData.create(activityId: activityId)

        var attributeData = [String: AnyCodable]()
        for attribute in attributes {
            attributeData.updateValue(AnyCodable(attribute.value), forKey: attribute.key)
        }

        var contentData = [String: AnyCodable]()
        for contentItem in content {
            contentData.updateValue(AnyCodable(contentItem.value), forKey: contentItem.key)
        }

        let attributes = DefaultLiveActivityAttributes(data: attributeData, onesignal: oneSignalAttribute)
        let contentState = DefaultLiveActivityAttributes.ContentState(data: contentData)
        do {
            _ = try Activity<DefaultLiveActivityAttributes>.request(
                    attributes: attributes,
                    contentState: contentState,
                    pushType: .token)
        } catch let error {
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "Cannot start default live activity: " + error.localizedDescription)
        }
    }

    @available(iOS 17.2, *)
    private static func listenForPushToStart<Attributes: OneSignalLiveActivityAttributes>(_ activityType: Attributes.Type, options: LiveActivitySetupOptions? = nil) {
        if options == nil || options!.enablePushToStart {
            Task {
                OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities listening for pushToStart on: \(activityType)")
                for try await data in Activity<Attributes>.pushToStartTokenUpdates {
                    let token = data.map {String(format: "%02x", $0)}.joined()
                    OneSignalLiveActivitiesManagerImpl.setPushToStartToken(Attributes.self, withToken: token)
                }
            }
        }
    }

    @available(iOS 16.1, *)
    private static func listenForActivity<Attributes: OneSignalLiveActivityAttributes>(_ activityType: Attributes.Type, options: LiveActivitySetupOptions? = nil) {
        Task {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities listening for activity on: \(activityType)")
            for await activity in Activity<Attributes>.activityUpdates {
                if #available(iOS 16.2, *) {
                    // if there's already an activity with the same OneSignal activityId, dismiss it before
                    // listening for the new activity's events.
                    for otherActivity in Activity<Attributes>.activities {
                        if activity.id != otherActivity.id && otherActivity.attributes.onesignal.activityId == activity.attributes.onesignal.activityId {
                            await otherActivity.end(nil, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
                        }
                    }
                }

                listenForActivityStateUpdates(activityType, activity: activity, options: options)
                listenForActivityPushToUpdate(activityType, activity: activity, options: options)
            }
        }
    }

    @available(iOS 16.1, *)
    private static func listenForActivityStateUpdates<Attributes: OneSignalLiveActivityAttributes>(_ activityType: Attributes.Type, activity: Activity<Attributes>, options: LiveActivitySetupOptions? = nil) {
        // listen for activity dismisses so we can forget about the token
        Task {
            OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities listening for state update on: \(activityType):\(activity.attributes.onesignal.activityId):\(activity.id)")
            for await activityState in activity.activityStateUpdates {
                switch activityState {
                case .dismissed:
                    OneSignalLiveActivitiesManagerImpl.exit(activity.attributes.onesignal.activityId)
                case .active: break
                case .ended: break
                case .stale: break
                default: break
                }
            }
        }
    }

    @available(iOS 16.1, *)
    private static func listenForActivityPushToUpdate<Attributes: OneSignalLiveActivityAttributes>(_ activityType: Attributes.Type, activity: Activity<Attributes>, options: LiveActivitySetupOptions? = nil) {
        if options == nil || options!.enablePushToUpdate {
            // listen for activity update token updates so we can tell OneSignal how to update the activity
            Task {
                OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.LiveActivities listening for pushToUpdate on: \(activityType):\(activity.attributes.onesignal.activityId):\(activity.id)")
                for await pushToken in activity.pushTokenUpdates {
                    let token = pushToken.map {String(format: "%02x", $0)}.joined()
                    OneSignalLiveActivitiesManagerImpl.enter(activity.attributes.onesignal.activityId, withToken: token)
                }
            }
        }
    }
}
