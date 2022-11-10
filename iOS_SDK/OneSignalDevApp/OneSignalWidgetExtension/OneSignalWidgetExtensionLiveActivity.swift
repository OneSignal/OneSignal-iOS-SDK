//
//  OneSignalWidgetExtensionLiveActivity.swift
//  OneSignalWidgetExtension
//
//  Created by Henry Boswell on 11/9/22.
//  Copyright © 2022 OneSignal. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI


struct OneSignalWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OneSignalWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here\VStack(alignment: .leading) {
            VStack {
                Spacer()
                Text(context.attributes.title).font(.headline)
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
