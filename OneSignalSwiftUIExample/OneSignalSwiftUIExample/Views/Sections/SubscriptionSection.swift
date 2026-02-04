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

/// Section for push subscription, email, and SMS management
struct SubscriptionSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        // Push Section
        Section {
            // Push ID
            VStack(alignment: .leading, spacing: 4) {
                Text("Push ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.pushSubscriptionId ?? "Not available")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)
            
            // Enabled Toggle
            Toggle("Enabled", isOn: Binding(
                get: { viewModel.isPushEnabled },
                set: { _ in viewModel.togglePushEnabled() }
            ))
        } header: {
            Text("Push")
        }
        
        // Emails Section
        Section {
            if viewModel.emails.isEmpty {
                EmptyListRow(message: "No Emails Added")
            } else {
                ForEach(viewModel.emails, id: \.self) { email in
                    SingleValueRow(value: email) {
                        viewModel.removeEmail(email)
                    }
                }
            }
            
            Button {
                viewModel.showAddSheet(for: .email)
            } label: {
                HStack {
                    Spacer()
                    Label("Add Email", systemImage: "plus")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        } header: {
            Text("Emails")
        }
        
        // SMS Section
        Section {
            if viewModel.smsNumbers.isEmpty {
                EmptyListRow(message: "No SMSs Added")
            } else {
                ForEach(viewModel.smsNumbers, id: \.self) { sms in
                    SingleValueRow(value: sms) {
                        viewModel.removeSms(sms)
                    }
                }
            }
            
            Button {
                viewModel.showAddSheet(for: .sms)
            } label: {
                HStack {
                    Spacer()
                    Label("Add SMS", systemImage: "plus")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        } header: {
            Text("SMSs")
        }
    }
}

#Preview {
    List {
        SubscriptionSection()
    }
    .environmentObject(OneSignalViewModel())
}
