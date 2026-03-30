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

struct AddItemDialog: View {
    let itemType: AddItemType
    let onAdd: (String, String) -> Void
    let onCancel: () -> Void

    @State private var keyText: String = ""
    @State private var valueText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(itemType.title)
                .font(.system(size: 24))
                .frame(maxWidth: .infinity, alignment: .leading)

            if itemType.requiresKeyValue {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key")
                        .font(.system(size: 12))
                        .foregroundColor(.osGrey600)
                    OSTextField(
                        placeholder: itemType.keyPlaceholder,
                        text: $keyText
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Value")
                        .font(.system(size: 12))
                        .foregroundColor(.osGrey600)
                    OSTextField(
                        placeholder: itemType.valuePlaceholder,
                        text: $valueText,
                        keyboardType: itemType.keyboardType
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(singleFieldLabel)
                        .font(.system(size: 12))
                        .foregroundColor(.osGrey600)
                    OSTextField(
                        placeholder: itemType.valuePlaceholder,
                        text: $valueText,
                        keyboardType: itemType.keyboardType
                    )
                }
            }

            DialogActions(
                confirmTitle: itemType == .externalUserId ? "Login" : "Add",
                isConfirmEnabled: isValid,
                onCancel: onCancel,
                onConfirm: { onAdd(keyText, valueText) }
            )
        }
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
