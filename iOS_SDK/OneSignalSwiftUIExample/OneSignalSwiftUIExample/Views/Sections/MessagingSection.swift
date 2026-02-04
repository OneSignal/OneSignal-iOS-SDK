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

/// Section for outcome events
struct OutcomeEventsSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var showingOutcomeSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Outcome Events")
            
            ActionButton(title: "Send Outcome") {
                showingOutcomeSheet = true
            }
        }
        .sheet(isPresented: $showingOutcomeSheet) {
            OutcomeSheet(
                onSend: { name, value in
                    if let value = value {
                        viewModel.sendOutcome(name, value: value)
                    } else {
                        viewModel.sendOutcome(name)
                    }
                    showingOutcomeSheet = false
                },
                onCancel: {
                    showingOutcomeSheet = false
                }
            )
        }
    }
}

/// Section for in-app messaging controls
struct InAppMessagingSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "In-App Messaging")
            
            CardContainer {
                ToggleRow(
                    title: "Pause In-App Messages:",
                    subtitle: "Toggle in-app messages",
                    isOn: Binding(
                        get: { viewModel.isInAppMessagesPaused },
                        set: { _ in viewModel.toggleInAppMessagesPaused() }
                    )
                )
            }
        }
    }
}

/// Section for trigger management
struct TriggersSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Triggers")
            
            CardContainer {
                if viewModel.triggers.isEmpty {
                    EmptyListRow(message: "No Triggers Added")
                } else {
                    ForEach(Array(viewModel.triggers.enumerated()), id: \.element.id) { index, trigger in
                        if index > 0 {
                            CardDivider()
                        }
                        KeyValueRow(item: trigger) {
                            viewModel.removeTrigger(trigger)
                        }
                    }
                }
            }
            
            ActionButton(title: "Add Trigger") {
                viewModel.showAddSheet(for: .trigger)
            }
            .padding(.top, 12)
        }
    }
}

/// Sheet for sending outcomes
struct OutcomeSheet: View {
    let onSend: (String, Double?) -> Void
    let onCancel: () -> Void
    
    @State private var outcomeName = ""
    @State private var outcomeValue = ""
    @State private var includeValue = false
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case name, value
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Outcome Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter outcome name", text: $outcomeName)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Toggle("Include Value", isOn: $includeValue)
                
                if includeValue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter value", text: $outcomeValue)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .value)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Button("Send") {
                        let value = includeValue ? Double(outcomeValue) : nil
                        onSend(outcomeName, value)
                    }
                    .foregroundColor(.accentColor)
                    .disabled(outcomeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .textCase(.uppercase)
                .font(.system(size: 16, weight: .semibold))
            }
            .padding(24)
            .navigationTitle("Send Outcome")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                focusedField = .name
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ScrollView {
        VStack {
            OutcomeEventsSection()
            InAppMessagingSection()
            TriggersSection()
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environmentObject(OneSignalViewModel())
}
