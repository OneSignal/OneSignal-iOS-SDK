//
//  OneSignalWidgetExtension.swift
//  OneSignalWidgetExtension
//
//  Created by Elliot Mawby on 8/4/22.
//  Copyright © 2022 OneSignal. All rights reserved.
//

import WidgetKit
import SwiftUI
import Intents
import ActivityKit

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
}

struct OneSignalWidgetExtensionEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Text(entry.date, style: .time)
    }
}

struct PizzaDeliveryAttributes: ActivityAttributes {
    public typealias PizzaDeliveryStatus = ContentState

    public struct ContentState: Codable, Hashable {
        var driverName: String
        var estimatedDeliveryTime: Date
    }

    var numberOfPizzas: Int
    var totalAmount: String
}

struct PizzaDeliveryActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(attributesType:       PizzaDeliveryAttributes.self) { context in
            // Create the user interface for your Live Activity that appears on the Lock Screen.
           VStack {
               Text("\(context.attributes.numberOfPizzas) ordered for \(context.attributes.totalAmount).")
               HStack {
                   Text("\(context.state.driverName) is on their way with your pizza!")
                   Text(context.state.estimatedDeliveryTime, style: .timer)
               }
           }.activityBackgroundTint(Color.cyan)
        }
    }
}

@main
struct OneSignalWidgetExtension: Widget {
    let kind: String = "OneSignalWidgetExtension"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            OneSignalWidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct OneSignalWidgetExtension_Previews: PreviewProvider {
    static var previews: some View {
        OneSignalWidgetExtensionEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
