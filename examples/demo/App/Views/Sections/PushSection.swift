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

/// Push subscription ID, opt-in toggle, and prompt-for-permission CTA
struct PushSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        SectionCard(
            title: "PUSH",
            sectionKey: "push",
            onInfoTap: { viewModel.showTooltip(for: "push") }
        ) {
            VStack(spacing: 0) {
                pushIdRow
                Rectangle()
                    .fill(OS.Color.divider)
                    .frame(height: OS.Layout.dividerHeight)
                    .padding(.vertical, 4)
                pushEnabledRow
            }
            .osCard()

            if !viewModel.hasNotificationPermission {
                ActionButton(
                    "PROMPT PUSH",
                    accessibilityID: "prompt_push_button"
                ) {
                    viewModel.promptPushPermission()
                }
            }
        }
    }

    private var pushIdRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Push ID")
                .font(OS.Font.bodyMedium)
                .foregroundColor(OS.Color.bodyText)
            Spacer(minLength: 0)
            Text(viewModel.pushSubscriptionId ?? "—")
                .font(OS.Font.mono12)
                .foregroundColor(OS.Color.bodyText)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier("push_id_value")
        }
        .padding(.vertical, 4)
    }

    private var pushEnabledRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Push Enabled")
                .font(OS.Font.bodyMedium)
                .foregroundColor(OS.Color.bodyText)
            Spacer(minLength: 0)
            Toggle(
                "",
                isOn: Binding(
                    get: { viewModel.isPushEnabled },
                    set: { viewModel.setPushEnabled($0) }
                )
            )
            .labelsHidden()
            .tint(OS.Color.primary)
            .disabled(!viewModel.hasNotificationPermission)
            .accessibilityIdentifier("push_enabled_toggle")
        }
        .padding(.vertical, 4)
    }
}
