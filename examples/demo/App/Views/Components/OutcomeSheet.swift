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

/// Sheet for sending an outcome (normal, unique, or with value)
struct OutcomeSheet: View {
    let onSend: (String, OutcomeMode, Double?) -> Void
    let onCancel: () -> Void

    @State private var mode: OutcomeMode = .normal
    @State private var name: String = ""
    @State private var valueText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    ForEach(OutcomeMode.allCases) { option in
                        Button {
                            mode = option
                        } label: {
                            HStack {
                                Image(systemName: mode == option ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(.accentColor)
                                Text(option.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .accessibilityIdentifier("outcome_type_\(option.accessibilityKey)_radio")
                    }
                }

                Section {
                    TextField("Outcome Name", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("outcome_name_input")
                }

                if mode == .value {
                    Section {
                        TextField("Outcome Value", text: $valueText)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("outcome_value_input")
                    }
                }
            }
            .navigationTitle("Send Outcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("outcome_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        let value: Double? = mode == .value ? Double(valueText) : nil
                        onSend(trimmed, mode, value)
                    }
                    .disabled(!isValid)
                    .accessibilityIdentifier("outcome_send_button")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }
        if mode == .value {
            return Double(valueText) != nil
        }
        return true
    }
}
