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

/// A sheet for adding items with one or two text fields (dialog style matching screenshots)
struct AddItemSheet: View {
    let itemType: AddItemType
    let onAdd: (String, String) -> Void
    let onCancel: () -> Void

    @State private var keyText: String = ""
    @State private var valueText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case key, value
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Title
                Text(itemType.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Input Fields
                if itemType.requiresKeyValue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(itemType.keyPlaceholder, text: $keyText)
                            .textFieldStyle(UnderlineTextFieldStyle())
                            .focused($focusedField, equals: .key)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(itemType.valuePlaceholder, text: $valueText)
                            .textFieldStyle(UnderlineTextFieldStyle())
                            .focused($focusedField, equals: .value)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(itemType.keyboardType)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(singleFieldLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField(itemType.valuePlaceholder, text: $valueText)
                            .textFieldStyle(UnderlineTextFieldStyle())
                            .focused($focusedField, equals: .value)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(itemType.keyboardType)
                    }
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 24) {
                    Spacer()

                    Button("CANCEL") {
                        onCancel()
                    }
                    .foregroundColor(.accentColor)

                    Button(itemType == .externalUserId ? "LOGIN" : "ADD") {
                        onAdd(keyText, valueText)
                    }
                    .foregroundColor(isValid ? .accentColor : .gray)
                    .disabled(!isValid)
                }
                .font(.system(size: 16, weight: .semibold))
            }
            .padding(24)
            .onAppear {
                focusedField = itemType.requiresKeyValue ? .key : .value
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var singleFieldLabel: String {
        switch itemType {
        case .email: return "New Email"
        case .sms: return "New SMS"
        case .externalUserId: return "External User Id"
        default: return "Value"
        }
    }

    private var isValid: Bool {
        if itemType.requiresKeyValue {
            return !keyText.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !valueText.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return !valueText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

/// A text field style with an underline instead of a border
struct UnderlineTextFieldStyle: TextFieldStyle {
    // swiftlint:disable:next identifier_name
    func _body(configuration: TextField<Self._Label>) -> some View {
        VStack(spacing: 0) {
            configuration
                .font(.system(size: 17))
                .padding(.vertical, 8)

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
        }
    }
}

#Preview("Add Alias") {
    AddItemSheet(
        itemType: .alias,
        onAdd: { key, value in print("Add: \(key) = \(value)") },
        onCancel: { print("Cancel") }
    )
}

#Preview("Add Email") {
    AddItemSheet(
        itemType: .email,
        onAdd: { _, value in print("Add: \(value)") },
        onCancel: { print("Cancel") }
    )
}

#Preview("Login User") {
    AddItemSheet(
        itemType: .externalUserId,
        onAdd: { _, value in print("Login: \(value)") },
        onCancel: { print("Cancel") }
    )
}
