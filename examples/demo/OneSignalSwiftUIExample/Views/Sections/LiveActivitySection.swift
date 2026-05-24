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
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        VStack(spacing: 0) {
            HStack {
                Text("Activity ID").foregroundColor(.secondary)
                Spacer()
                TextField("Activity ID", text: $activityId)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("live_activity_id_input")
            }
            .padding(12)

            Divider().padding(.leading, 12)

            HStack {
                Text("Order #").foregroundColor(.secondary)
                Spacer()
                TextField("Order #", text: $orderNumber)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("live_activity_order_number")
            }
            .padding(12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
