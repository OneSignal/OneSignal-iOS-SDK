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

/// Reusable sheet for adding items with one or two text fields
struct AddItemSheet: View {
    let itemType: AddItemType
    let onAdd: (String, String) -> Void
    let onCancel: () -> Void

    @State private var keyText: String = ""
    @State private var valueText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case key, value }

    var body: some View {
        NavigationStack {
            Form {
                if itemType.requiresKeyValue {
                    Section {
                        TextField(itemType.keyPlaceholder, text: $keyText)
                            .focused($focusedField, equals: .key)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("\(itemType.accessibilityKey)_key_input")

                        TextField(itemType.valuePlaceholder, text: $valueText)
                            .focused($focusedField, equals: .value)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(itemType.keyboardType)
                            .accessibilityIdentifier("\(itemType.accessibilityKey)_value_input")
                    }
                } else {
                    Section {
                        TextField(itemType.valuePlaceholder, text: $valueText)
                            .focused($focusedField, equals: .value)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(itemType.keyboardType)
                            .accessibilityIdentifier("\(itemType.accessibilityKey)_input")
                    }
                }
            }
            .navigationTitle(itemType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("singleinput_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(itemType.confirmLabel) {
                        onAdd(
                            keyText.trimmingCharacters(in: .whitespaces),
                            valueText.trimmingCharacters(in: .whitespaces)
                        )
                    }
                    .disabled(!isValid)
                    .accessibilityIdentifier("singleinput_confirm_button")
                }
            }
            .onAppear {
                focusedField = itemType.requiresKeyValue ? .key : .value
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var isValid: Bool {
        if itemType.requiresKeyValue {
            return !keyText.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !valueText.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !valueText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
