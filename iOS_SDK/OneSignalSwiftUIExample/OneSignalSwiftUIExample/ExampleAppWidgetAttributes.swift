#if targetEnvironment(macCatalyst)
#else
import ActivityKit
import OneSignalLiveActivities

struct ExampleAppFirstWidgetAttributes: OneSignalLiveActivityAttributes {
    public struct ContentState: OneSignalLiveActivityContentState {
        var message: String
        var onesignal: OneSignalLiveActivityContentStateData?
    }

    var title: String
    var onesignal: OneSignalLiveActivityAttributeData
}

struct ExampleAppSecondWidgetAttributes: OneSignalLiveActivityAttributes {
    public struct ContentState: OneSignalLiveActivityContentState {
        var message: String
        var status: String
        var progress: Double
        var bugs: Int
        var onesignal: OneSignalLiveActivityContentStateData?
    }

    var title: String
    var onesignal: OneSignalLiveActivityAttributeData
}

struct ExampleAppThirdWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var message: String
    }

    var title: String
    var isPushToStart: Bool
}
#endif
