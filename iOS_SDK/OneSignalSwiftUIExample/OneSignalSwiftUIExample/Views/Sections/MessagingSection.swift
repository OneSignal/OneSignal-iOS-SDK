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
            SectionHeader(title: "Outcome Events", tooltipKey: "outcomes")

            ActionButton(title: "Send Outcome") {
                showingOutcomeSheet = true
            }
        }
        .sheet(isPresented: $showingOutcomeSheet) {
            OutcomeSheet(
                onSendNormal: { name in
                    viewModel.sendOutcome(name)
                    showingOutcomeSheet = false
                },
                onSendUnique: { name in
                    viewModel.sendUniqueOutcome(name)
                    showingOutcomeSheet = false
                },
                onSendWithValue: { name, value in
                    viewModel.sendOutcome(name, value: value)
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
            SectionHeader(title: "In-App Messaging", tooltipKey: "inAppMessaging")

            CardContainer {
                ToggleRow(
                    title: "Pause In-App Messages",
                    subtitle: "Toggle in-app message display",
                    isOn: Binding(
                        get: { viewModel.isInAppMessagesPaused },
                        set: { _ in viewModel.toggleInAppMessagesPaused() }
                    )
                )
            }
        }
    }
}

/// Section for trigger management with Add Trigger, Add Triggers (multi), Remove Triggers, and Clear Triggers
struct TriggersSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Triggers", tooltipKey: "triggers")

            CardContainer {
                if viewModel.triggers.isEmpty {
                    EmptyListRow(message: "No triggers added")
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

            ActionButton(title: "Add") {
                viewModel.showAddSheet(for: .trigger)
            }
            .padding(.top, 12)

            ActionButton(title: "Add Multiple") {
                viewModel.showMultiAddSheet(for: .triggers)
            }
            .padding(.top, 8)

            // Remove Selected and Clear All - only visible when triggers exist
            if !viewModel.triggers.isEmpty {
                OutlineActionButton(title: "Remove Selected") {
                    viewModel.showRemoveMultiSheet(for: .triggers)
                }
                .padding(.top, 8)

                OutlineActionButton(title: "Clear All") {
                    viewModel.clearTriggers()
                }
                .padding(.top, 8)
            }
        }
    }
}

/// Outcome type options matching Android's radio button selection
private enum OutcomeType: Int, CaseIterable {
    case normal = 0
    case unique = 1
    case withValue = 2

    var label: String {
        switch self {
        case .normal: return "Normal Outcome"
        case .unique: return "Unique Outcome"
        case .withValue: return "Outcome with Value"
        }
    }
}

/// Sheet for sending outcomes with radio button selection (Normal/Unique/With Value)
struct OutcomeSheet: View {
    let onSendNormal: (String) -> Void
    let onSendUnique: (String) -> Void
    let onSendWithValue: (String, Double) -> Void
    let onCancel: () -> Void

    @State private var selectedType: OutcomeType = .normal
    @State private var outcomeName = ""
    @State private var outcomeValue = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, value
    }

    private var isSendDisabled: Bool {
        let nameEmpty = outcomeName.trimmingCharacters(in: .whitespaces).isEmpty
        if selectedType == .withValue {
            return nameEmpty || Double(outcomeValue) == nil
        }
        return nameEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Radio button selection
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(OutcomeType.allCases, id: \.rawValue) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedType == type ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(selectedType == type ? .accentColor : .secondary)
                                Text(type.label)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Outcome name field (always shown)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Outcome Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Outcome Name", text: $outcomeName)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                // Value field (only when "Outcome with Value" selected)
                if selectedType == .withValue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Value", text: $outcomeValue)
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
                        switch selectedType {
                        case .normal:
                            onSendNormal(outcomeName)
                        case .unique:
                            onSendUnique(outcomeName)
                        case .withValue:
                            onSendWithValue(outcomeName, Double(outcomeValue) ?? 0)
                        }
                    }
                    .foregroundColor(.accentColor)
                    .disabled(isSendDisabled)
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
