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

// MARK: - Push Section

/// Section for push subscription management
struct PushSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Push", tooltipKey: "push")

            CardContainer {
                InfoRow(
                    label: "Push ID",
                    value: viewModel.pushSubscriptionId ?? "Not available",
                    isMonospaced: true
                )
                CardDivider()
                ToggleRow(
                    title: "Enabled",
                    isOn: Binding(
                        get: { viewModel.isPushEnabled },
                        set: { _ in viewModel.togglePushEnabled() }
                    ),
                    isEnabled: viewModel.notificationPermissionGranted
                )
            }

            // Prompt Push button - only visible when permission not granted
            if !viewModel.notificationPermissionGranted {
                ActionButton(title: "Prompt Push") {
                    viewModel.requestPushPermission()
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - Emails Section

/// Section for email subscription management with collapsible >5 items
struct EmailsSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Emails", tooltipKey: "emails")

            CardContainer {
                if viewModel.emails.isEmpty {
                    EmptyListRow(message: "No emails added")
                } else {
                    let displayEmails = isExpanded ? viewModel.emails : Array(viewModel.emails.prefix(5))

                    ForEach(Array(displayEmails.enumerated()), id: \.element) { index, email in
                        if index > 0 {
                            CardDivider()
                        }
                        SingleValueRow(value: email) {
                            viewModel.removeEmail(email)
                        }
                    }

                    // "X more available" when collapsed and more than 5
                    if !isExpanded && viewModel.emails.count > 5 {
                        CardDivider()
                        Button {
                            isExpanded = true
                        } label: {
                            Text("\(viewModel.emails.count - 5) more available")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ActionButton(title: "Add Email") {
                viewModel.showAddSheet(for: .email)
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - SMS Section

/// Section for SMS subscription management with collapsible >5 items
struct SMSSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "SMS", tooltipKey: "sms")

            CardContainer {
                if viewModel.smsNumbers.isEmpty {
                    EmptyListRow(message: "No SMS added")
                } else {
                    let displaySms = isExpanded ? viewModel.smsNumbers : Array(viewModel.smsNumbers.prefix(5))

                    ForEach(Array(displaySms.enumerated()), id: \.element) { index, sms in
                        if index > 0 {
                            CardDivider()
                        }
                        SingleValueRow(value: sms) {
                            viewModel.removeSms(sms)
                        }
                    }

                    if !isExpanded && viewModel.smsNumbers.count > 5 {
                        CardDivider()
                        Button {
                            isExpanded = true
                        } label: {
                            Text("\(viewModel.smsNumbers.count - 5) more available")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ActionButton(title: "Add SMS") {
                viewModel.showAddSheet(for: .sms)
            }
            .padding(.top, 12)
        }
    }
}

#Preview {
    ScrollView {
        VStack {
            PushSection()
            EmailsSection()
            SMSSection()
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environmentObject(OneSignalViewModel())
}
