//
//  OnesignalLaWidget2LiveActivity.swift
//  OnesignalLaWidget2
//
//  Created by Jordan Chong on 2/1/24.
//  Copyright © 2024 OneSignal. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct OnesignalLaWidget2Attributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct OnesignalLaWidget2LiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OnesignalLaWidget2Attributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
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
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension OnesignalLaWidget2Attributes {
    fileprivate static var preview: OnesignalLaWidget2Attributes {
        OnesignalLaWidget2Attributes(name: "World")
    }
}

extension OnesignalLaWidget2Attributes.ContentState {
    fileprivate static var smiley: OnesignalLaWidget2Attributes.ContentState {
        OnesignalLaWidget2Attributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: OnesignalLaWidget2Attributes.ContentState {
         OnesignalLaWidget2Attributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: OnesignalLaWidget2Attributes.preview) {
   OnesignalLaWidget2LiveActivity()
} contentStates: {
    OnesignalLaWidget2Attributes.ContentState.smiley
    OnesignalLaWidget2Attributes.ContentState.starEyes
}
