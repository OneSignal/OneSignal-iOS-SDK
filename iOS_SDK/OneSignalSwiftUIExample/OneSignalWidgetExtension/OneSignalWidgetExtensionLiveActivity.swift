import ActivityKit
import WidgetKit
import SwiftUI
import OneSignalLiveActivities

struct ExampleAppFirstWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExampleAppFirstWidgetAttributes.self) { context in
            VStack {
                Spacer()
                Text("FIRST: " + context.attributes.title).font(.headline)
                Spacer()
                HStack {
                    Spacer()
                    Label {
                        Text(String(context.state.message))
                    } icon: {
                        Image(systemName: "bell.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40.0, height: 40.0)
                    }
                    Spacer()
                }
                Spacer()
            }
            .foregroundColor(.black)
            .onesignalWidgetURL(URL(string: "https://example.com/page?param1=value1&param2=value2#section"), context: context)
            .activitySystemActionForegroundColor(.black)
            .activityBackgroundTint(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("Min")
            }
            .onesignalWidgetURL(URL(string: "https://example.com/page?param1=value1&param2=value2#section"), context: context)
            .keylineTint(Color.red)
        }
    }
}

struct ExampleAppSecondWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExampleAppSecondWidgetAttributes.self) { context in
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "bell.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40.0, height: 40.0)
                    Spacer()
                    Text(context.attributes.title).font(.headline)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("Update:   ").font(.title2)
                    Spacer()
                    Text(context.state.message)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("Progress: ").font(.title2)
                    ProgressView(value: context.state.progress)
                        .padding([.bottom, .top], 5)
                    Text(context.state.status)
                }
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("Bugs:     ").font(.title2)
                    Spacer()
                    Text(String(context.state.bugs))
                }
                Spacer()
            }
            .foregroundColor(.black)
            .padding([.all], 20)
            .activitySystemActionForegroundColor(.black)
            .activityBackgroundTint(.white)
            .onesignalWidgetURL(URL(string: "https://example.com/page?param1=value1&param2=value2#section"), context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("Min")
            }
            .keylineTint(Color.red)
            .onesignalWidgetURL(URL(string: "https://example.com/page?param1=value1&param2=value2#section"), context: context)
        }
    }
}

struct ExampleAppThirdWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ExampleAppThirdWidgetAttributes.self) { context in
            VStack {
                Spacer()
                Text("THIRD: " + context.attributes.title).font(.headline)
                Spacer()
                HStack {
                    Spacer()
                    Label {
                        Text(context.state.message)
                    } icon: {
                        Image(systemName: "bell.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40.0, height: 40.0)
                    }
                    Spacer()
                }
                Spacer()
            }
            .foregroundColor(.black)
            .activitySystemActionForegroundColor(.black)
            .activityBackgroundTint(.white)
        } dynamicIsland: { _ in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("Min")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

struct DefaultOneSignalLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DefaultLiveActivityAttributes.self) { context in
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "bell.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40.0, height: 40.0)
                    Spacer()
                    Text("DEFAULT: " + (context.attributes.data["title"]?.asString() ?? "")).font(.headline)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("Update:   ").font(.title2)
                    Spacer()
                    Text(context.state.data["message"]?.asDict()?["en"]?.asString() ?? "")
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("Progress: ").font(.title2)
                    ProgressView(
                        value: context.state.data["progress"]?.asDouble() ?? 0.0
                    ).padding([.bottom, .top], 5)
                    Text(context.state.data["status"]?.asString() ?? "")
                }
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("Bugs:     ").font(.title2)
                    Spacer()
                    Text(String(context.state.data["bugs"]?.asInt() ?? 0))
                }
                Spacer()
            }
            .foregroundColor(.black)
            .padding([.all], 20)
            .activitySystemActionForegroundColor(.black)
            .activityBackgroundTint(.white)
            .onesignalWidgetURL(URL(string: "https://example.com/page?param1=value1&param2=value2#section"), context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("Min")
            }
            .keylineTint(Color.red)
            .onesignalWidgetURL(URL(string: "https://example.com/page?param1=value1&param2=value2#section"), context: context)
        }
    }
}
