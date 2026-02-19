import Foundation
import OneSignalFramework
#if targetEnvironment(macCatalyst)
#else
import ActivityKit
import OneSignalLiveActivities

class LiveActivityController {

    @available(iOS 16.1, *)
    static func start() {
        OneSignal.LiveActivities.setup(ExampleAppFirstWidgetAttributes.self)
        OneSignal.LiveActivities.setup(ExampleAppSecondWidgetAttributes.self)
        OneSignal.LiveActivities.setupDefault()

        if #available(iOS 17.2, *) {
            Task {
                for try await data in Activity<ExampleAppThirdWidgetAttributes>.pushToStartTokenUpdates {
                    let token = data.map { String(format: "%02x", $0) }.joined()
                    OneSignal.LiveActivities.setPushToStartToken(ExampleAppThirdWidgetAttributes.self, withToken: token)
                }
            }
            Task {
                for await activity in Activity<ExampleAppThirdWidgetAttributes>.activityUpdates
                    where activity.attributes.isPushToStart {
                    Task {
                        for await pushToken in activity.pushTokenUpdates {
                            let token = pushToken.map { String(format: "%02x", $0) }.joined()
                            OneSignal.LiveActivities.enter("my-activity-id", withToken: token)
                        }
                    }
                }
            }
        }
    }

    static var counter1 = 0

    @available(iOS 16.1, *)
    static func createOneSignalAwareActivity(activityId: String) {
        counter1 += 1
        let oneSignalAttribute = OneSignalLiveActivityAttributeData.create(activityId: activityId)
        let attributes = ExampleAppFirstWidgetAttributes(title: "#\(counter1) Live Activity", onesignal: oneSignalAttribute)
        let contentState = ExampleAppFirstWidgetAttributes.ContentState(message: "Update this message through push")
        do {
            _ = try Activity<ExampleAppFirstWidgetAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: .token)
        } catch {
            print(error.localizedDescription)
        }
    }

    @available(iOS 16.1, *)
    static func createDefaultActivity(activityId: String) {
        let attributeData: [String: Any] = ["title": "in-app-title"]
        let contentData: [String: Any] = ["message": ["en": "HELLO", "es": "HOLA"], "progress": 0.58, "status": "1/15", "bugs": 2]
        OneSignal.LiveActivities.startDefault(activityId, attributes: attributeData, content: contentData)
    }

    static var counter2 = 0

    @available(iOS 16.1, *)
    static func createActivity(activityId: String) async {
        counter2 += 1
        let attributes = ExampleAppThirdWidgetAttributes(title: "#\(counter2) Live Activity", isPushToStart: false)
        let contentState = ExampleAppThirdWidgetAttributes.ContentState(message: "Update this message through push")
        do {
            let activity = try Activity<ExampleAppThirdWidgetAttributes>.request(
                attributes: attributes,
                contentState: contentState,
                pushType: .token)
            for await data in activity.pushTokenUpdates {
                let myToken = data.map { String(format: "%02x", $0) }.joined()
                OneSignal.LiveActivities.enter(activityId, withToken: myToken)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
#endif
