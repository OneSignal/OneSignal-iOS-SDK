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

/// Section for push subscription management
struct PushSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Push")
            
            CardContainer {
                InfoRow(
                    label: "Push-Id:",
                    value: viewModel.pushSubscriptionId ?? "Not available",
                    isMonospaced: true
                )
                CardDivider()
                ToggleRow(
                    title: "Enabled",
                    isOn: Binding(
                        get: { viewModel.isPushEnabled },
                        set: { _ in viewModel.togglePushEnabled() }
                    )
                )
            }
        }
    }
}

/// Section for email subscription management
struct EmailsSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Emails")
            
            CardContainer {
                if viewModel.emails.isEmpty {
                    EmptyListRow(message: "No Emails Added")
                } else {
                    ForEach(Array(viewModel.emails.enumerated()), id: \.element) { index, email in
                        if index > 0 {
                            CardDivider()
                        }
                        SingleValueRow(value: email) {
                            viewModel.removeEmail(email)
                        }
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

/// Section for SMS subscription management
struct SMSSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "SMSs")
            
            CardContainer {
                if viewModel.smsNumbers.isEmpty {
                    EmptyListRow(message: "No SMSs Added")
                } else {
                    ForEach(Array(viewModel.smsNumbers.enumerated()), id: \.element) { index, sms in
                        if index > 0 {
                            CardDivider()
                        }
                        SingleValueRow(value: sms) {
                            viewModel.removeSms(sms)
                        }
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
