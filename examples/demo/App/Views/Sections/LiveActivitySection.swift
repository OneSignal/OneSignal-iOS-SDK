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

import SwiftUI

/// Live Activities (iOS 16.1+) section with activity ID + order # inputs and status cycler.
/// Mirrors the Capacitor demo's LiveActivitySection.
struct LiveActivitySection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    @State private var activityId: String = "order-1"
    @State private var orderNumber: String = "ORD-1234"
    @State private var statusIndex: Int = 0

    private let statuses: [LiveActivityStatus] = [.preparing, .onTheWay, .delivered]

    var body: some View {
        SectionCard(
            title: "LIVE ACTIVITIES",
            sectionKey: "live_activities",
            onInfoTap: { viewModel.showTooltip(for: "liveActivities") }
        ) {
            inputCard

            ActionButton(
                "START LIVE ACTIVITY",
                isDisabled: trimmedActivityId.isEmpty,
                accessibilityID: "start_live_activity_button"
            ) {
                statusIndex = 0
                viewModel.startLiveActivity(
                    activityId: trimmedActivityId,
                    orderNumber: orderNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    status: statuses[0]
                )
            }

            ActionButton(
                updateButtonTitle,
                isDisabled: trimmedActivityId.isEmpty || !LiveActivityController.hasApiKey,
                accessibilityID: "update_live_activity_button"
            ) {
                let nextIndex = (statusIndex + 1) % statuses.count
                viewModel.updateLiveActivity(
                    activityId: trimmedActivityId,
                    status: statuses[nextIndex]
                )
                statusIndex = nextIndex
            }

            ActionButton(
                "END LIVE ACTIVITY",
                style: .outline,
                isDisabled: trimmedActivityId.isEmpty || !LiveActivityController.hasApiKey,
                accessibilityID: "end_live_activity_button"
            ) {
                viewModel.endLiveActivity(activityId: trimmedActivityId)
            }

            if !LiveActivityController.hasApiKey {
                Text("Set ONESIGNAL_API_KEY in Secrets.plist to enable update & end")
                    .font(OS.Font.bodySmall)
                    .foregroundColor(OS.Color.grey600)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("live_activities_hint")
            }
        }
    }

    private var trimmedActivityId: String {
        activityId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nextStatus: LiveActivityStatus {
        statuses[(statusIndex + 1) % statuses.count]
    }

    private var updateButtonTitle: String {
        "UPDATE → \(nextStatus.displayName.uppercased())"
    }

    private var inputCard: some View {
        VStack(spacing: 4) {
            inlineRow(
                label: "Activity ID",
                placeholder: "Activity ID",
                text: $activityId,
                accessibilityID: "live_activity_id_input"
            )
            inlineRow(
                label: "Order #",
                placeholder: "Order #",
                text: $orderNumber,
                accessibilityID: "live_activity_order_number"
            )
        }
        .osCard()
    }

    private func inlineRow(
        label: String,
        placeholder: String,
        text: Binding<String>,
        accessibilityID: String
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(OS.Font.bodyMedium)
                .foregroundColor(OS.Color.grey600)
                .frame(minWidth: OS.Layout.inlineLabelMinWidth, alignment: .leading)
            TextField(placeholder, text: text)
                .font(OS.Font.bodyMedium)
                .foregroundColor(OS.Color.bodyText)
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier(accessibilityID)
        }
    }
}
