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

// MARK: - In-App Messaging Section

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

// MARK: - Outcome Events Section

struct OutcomeEventsSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Outcome Events", tooltipKey: "outcomes")

            ActionButton(title: "Send Outcome") {
                viewModel.showingOutcomeSheet = true
            }
        }
    }
}

// MARK: - Triggers Section

struct TriggersSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Triggers", tooltipKey: "triggers")

            CardContainer {
                if viewModel.triggers.isEmpty {
                    EmptyListRow(message: "No Triggers Added")
                } else {
                    ForEach(Array(viewModel.triggers.enumerated()), id: \.element.id) { index, trigger in
                        if index > 0 { CardDivider() }
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

// MARK: - Outcome Dialog

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

struct OutcomeDialog: View {
    let onSendNormal: (String) -> Void
    let onSendUnique: (String) -> Void
    let onSendWithValue: (String, Double) -> Void
    let onCancel: () -> Void

    @State private var selectedType: OutcomeType = .normal
    @State private var outcomeName = ""
    @State private var outcomeValue = ""

    private var isSendDisabled: Bool {
        let nameEmpty = outcomeName.trimmingCharacters(in: .whitespaces).isEmpty
        if selectedType == .withValue {
            return nameEmpty || Double(outcomeValue) == nil
        }
        return nameEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Send Outcome")
                .font(.system(size: 24))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(OutcomeType.allCases, id: \.rawValue) { type in
                    Button {
                        selectedType = type
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedType == type
                                  ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(selectedType == type ? .osPrimary : .secondary)
                            Text(type.label)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Outcome Name")
                    .font(.system(size: 12))
                    .foregroundColor(.osGrey600)
                OSTextField(placeholder: "", text: $outcomeName)
            }

            if selectedType == .withValue {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value")
                        .font(.system(size: 12))
                        .foregroundColor(.osGrey600)
                    OSTextField(
                        placeholder: "",
                        text: $outcomeValue,
                        keyboardType: .decimalPad
                    )
                }
            }

            DialogActions(
                confirmTitle: "Send",
                isConfirmEnabled: !isSendDisabled,
                onCancel: onCancel,
                onConfirm: {
                    switch selectedType {
                    case .normal: onSendNormal(outcomeName)
                    case .unique: onSendUnique(outcomeName)
                    case .withValue: onSendWithValue(outcomeName, Double(outcomeValue) ?? 0)
                    }
                }
            )
        }
    }
}
