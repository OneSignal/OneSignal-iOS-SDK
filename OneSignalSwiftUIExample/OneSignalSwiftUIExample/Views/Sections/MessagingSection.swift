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

/// Section for outcomes, in-app messaging, and triggers
struct MessagingSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var showingOutcomeSheet = false
    @State private var outcomeName = ""
    @State private var outcomeValue = ""
    
    var body: some View {
        // Outcome Events Section
        Section {
            Button {
                showingOutcomeSheet = true
            } label: {
                HStack {
                    Spacer()
                    Text("Send Outcome")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        } header: {
            Text("Outcome Events")
        }
        
        // In-App Messaging Section
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.isInAppMessagesPaused },
                set: { _ in viewModel.toggleInAppMessagesPaused() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pause In-App Messages")
                    Text("Toggle in-app messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("In-App Messaging")
        }
        
        // Triggers Section
        Section {
            if viewModel.triggers.isEmpty {
                EmptyListRow(message: "No Triggers Added")
            } else {
                ForEach(viewModel.triggers) { trigger in
                    KeyValueRow(item: trigger) {
                        viewModel.removeTrigger(trigger)
                    }
                }
            }
            
            Button {
                viewModel.showAddSheet(for: .trigger)
            } label: {
                HStack {
                    Spacer()
                    Label("Add Trigger", systemImage: "plus")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        } header: {
            Text("Triggers")
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
            Form {
                Section {
                    TextField("Outcome Name", text: $outcomeName)
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Toggle("Include Value", isOn: $includeValue)
                    
                    if includeValue {
                        TextField("Value", text: $outcomeValue)
                            .focused($focusedField, equals: .value)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Send Outcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        let value = includeValue ? Double(outcomeValue) : nil
                        onSend(outcomeName, value)
                    }
                    .disabled(outcomeName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                focusedField = .name
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    List {
        MessagingSection()
    }
    .environmentObject(OneSignalViewModel())
}
