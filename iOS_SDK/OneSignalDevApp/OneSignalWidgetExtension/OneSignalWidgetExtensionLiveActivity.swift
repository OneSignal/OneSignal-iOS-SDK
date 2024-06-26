/**
 * Modified MIT License
 *
 * Copyright 2023 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import ActivityKit
import WidgetKit
import SwiftUI
import OneSignalLiveActivities

 struct ExampleAppFirstWidget: Widget {
     var body: some WidgetConfiguration {
         ActivityConfiguration(for: ExampleAppFirstWidgetAttributes.self) { context in
             // Lock screen/banner UI goes here\VStack(alignment: .leading) {
             VStack {
                 Spacer()
                 Text("FIRST: " + context.attributes.title).font(.headline)
                 Spacer()
                 HStack {
                     Spacer()
                     Label {
                         Text(String(context.state.message))
                     } icon: {
                         Image("onesignaldemo")
                             .resizable()
                             .scaledToFit()
                             .frame(width: 40.0, height: 40.0)
                     }
                     Spacer()
                 }
                 Spacer()
             }
             .activitySystemActionForegroundColor(.black)
             .activityBackgroundTint(.white)
         } dynamicIsland: { _ in
             DynamicIsland {
                 // Expanded UI goes here.  Compose the expanded UI through
                 // various regions, like leading/trailing/center/bottom
                 DynamicIslandExpandedRegion(.leading) {
                     Text("Leading")
                 }
                 DynamicIslandExpandedRegion(.trailing) {
                     Text("Trailing")
                 }
                 DynamicIslandExpandedRegion(.bottom) {
                     Text("Bottom")
                     // more content
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

 struct ExampleAppSecondWidget: Widget {
     var body: some WidgetConfiguration {
         ActivityConfiguration(for: ExampleAppSecondWidgetAttributes.self) { context in
             // Lock screen/banner UI goes here\VStack(alignment: .leading) {
             VStack {
                 Spacer()
                 HStack {
                     Image("onesignaldemo")
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
             .padding([.all], 20)
             .activitySystemActionForegroundColor(.black)
             .activityBackgroundTint(.white)
         } dynamicIsland: { _ in
             DynamicIsland {
                 // Expanded UI goes here.  Compose the expanded UI through
                 // various regions, like leading/trailing/center/bottom
                 DynamicIslandExpandedRegion(.leading) {
                     Text("Leading")
                 }
                 DynamicIslandExpandedRegion(.trailing) {
                     Text("Trailing")
                 }
                 DynamicIslandExpandedRegion(.bottom) {
                     Text("Bottom")
                     // more content
                 }
             } compactLeading: {
                 Text("L")
             } compactTrailing: {
                 Text("T")
             } minimal: {
                 Text("Min")
             }
             .keylineTint(Color.red)
         }
     }
 }

 struct ExampleAppThirdWidget: Widget {
     var body: some WidgetConfiguration {
         ActivityConfiguration(for: ExampleAppThirdWidgetAttributes.self) { context in
             // Lock screen/banner UI goes here\VStack(alignment: .leading) {
             VStack {
                 Spacer()
                 Text("THIRD: " + context.attributes.title).font(.headline)
                 Spacer()
                 HStack {
                     Spacer()
                     Label {
                         Text(context.state.message)
                     } icon: {
                         Image("onesignaldemo")
                             .resizable()
                             .scaledToFit()
                             .frame(width: 40.0, height: 40.0)
                     }
                     Spacer()
                 }
                 Spacer()
             }
             .activitySystemActionForegroundColor(.black)
             .activityBackgroundTint(.white)
         } dynamicIsland: { _ in
             DynamicIsland {
                 // Expanded UI goes here.  Compose the expanded UI through
                 // various regions, like leading/trailing/center/bottom
                 DynamicIslandExpandedRegion(.leading) {
                     Text("Leading")
                 }
                 DynamicIslandExpandedRegion(.trailing) {
                     Text("Trailing")
                 }
                 DynamicIslandExpandedRegion(.bottom) {
                     Text("Bottom")
                     // more content
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
            // Lock screen/banner UI goes here\VStack(alignment: .leading) {
            VStack {
                Spacer()
                HStack {
                    Image("onesignaldemo")
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
            .padding([.all], 20)
            .activitySystemActionForegroundColor(.black)
            .activityBackgroundTint(.white)
        } dynamicIsland: { _ in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("Min")
            }
            .keylineTint(Color.red)
        }
    }
}
