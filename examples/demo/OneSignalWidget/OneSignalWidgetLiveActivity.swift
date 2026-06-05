/**
 * Modified MIT License
 *
 * Copyright 2024 OneSignal
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

/// Live Activity widget that renders the order tracking flow used by the demo.
/// Uses `DefaultLiveActivityAttributes` (provided by the OneSignal SDK) so the same
/// data shape works between `OneSignal.LiveActivities.startDefault(...)` and remote
/// `event_updates` payloads sent via the REST API.
@available(iOS 16.2, *)
struct OneSignalWidgetLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DefaultLiveActivityAttributes.self) { context in
            let orderNumber = context.attributes.data["orderNumber"]?.asString() ?? "Order"
            let status = context.state.data["status"]?.asString() ?? "preparing"
            let message = context.state.data["message"]?.asString() ?? "Your order is being prepared"
            let eta = context.state.data["estimatedTime"]?.asString() ?? ""

            VStack(spacing: 10) {
                HStack {
                    Text(orderNumber)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    if !eta.isEmpty {
                        Text(eta)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: Self.statusIcon(for: status))
                        .font(.title2)
                        .foregroundColor(Self.statusColor(for: status))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.statusLabel(for: status))
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    Spacer()
                }

                DeliveryProgressBar(status: status)
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.11, green: 0.13, blue: 0.19))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            let status = context.state.data["status"]?.asString() ?? "preparing"
            let message = context.state.data["message"]?.asString() ?? "Preparing"
            let eta = context.state.data["estimatedTime"]?.asString() ?? ""

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: Self.statusIcon(for: status))
                        .font(.title2)
                        .foregroundColor(Self.statusColor(for: status))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(Self.statusLabel(for: status))
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !eta.isEmpty {
                        Text(eta)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: Self.statusIcon(for: status))
                    .foregroundColor(Self.statusColor(for: status))
            } compactTrailing: {
                Text(Self.statusLabel(for: status))
                    .font(.caption)
            } minimal: {
                Image(systemName: Self.statusIcon(for: status))
                    .foregroundColor(Self.statusColor(for: status))
            }
        }
    }

    // MARK: - Status helpers

    private static func statusIcon(for status: String) -> String {
        switch status {
        case "on_the_way": return "box.truck.fill"
        case "delivered":  return "checkmark.circle.fill"
        default:           return "bag.fill"
        }
    }

    private static func statusColor(for status: String) -> Color {
        switch status {
        case "on_the_way": return .blue
        case "delivered":  return .green
        default:           return .orange
        }
    }

    private static func statusLabel(for status: String) -> String {
        switch status {
        case "on_the_way": return "On the Way"
        case "delivered":  return "Delivered"
        default:           return "Preparing"
        }
    }
}

@available(iOS 16.2, *)
struct DeliveryProgressBar: View {
    let status: String

    private var progress: CGFloat {
        switch status {
        case "on_the_way": return 0.6
        case "delivered":  return 1.0
        default:           return 0.25
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(progress >= 1.0 ? Color.green : Color.blue)
                    .frame(width: geo.size.width * progress, height: 6)
            }
        }
        .frame(height: 6)
    }
}
