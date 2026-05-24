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

/// Sheet that adds multiple key/value pairs at once (Add Multiple Aliases / Tags / Triggers)
struct MultiPairInputSheet: View {
    let type: MultiAddItemType
    let onAdd: ([(String, String)]) -> Void
    let onCancel: () -> Void

    @State private var rows: [Row] = [Row()]

    struct Row: Identifiable {
        let id = UUID()
        var key: String = ""
        var value: String = ""
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(rows.indices, id: \.self) { index in
                    Section {
                        TextField(type.keyPlaceholder, text: $rows[index].key)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("multipair_key_\(index)")
                        TextField(type.valuePlaceholder, text: $rows[index].value)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("multipair_value_\(index)")
                        if rows.count > 1 {
                            Button(role: .destructive) {
                                rows.remove(at: index)
                            } label: {
                                Label("Remove Row", systemImage: "minus.circle")
                            }
                            .accessibilityIdentifier("multipair_remove_row_\(index)")
                        }
                    }
                }

                Section {
                    Button {
                        rows.append(Row())
                    } label: {
                        Label("Add Row", systemImage: "plus.circle")
                    }
                    .accessibilityIdentifier("multipair_add_row_button")
                }
            }
            .navigationTitle(type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("multipair_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add All") {
                        let pairs = rows.compactMap { row -> (String, String)? in
                            let key = row.key.trimmingCharacters(in: .whitespaces)
                            let value = row.value.trimmingCharacters(in: .whitespaces)
                            guard !key.isEmpty, !value.isEmpty else { return nil }
                            return (key, value)
                        }
                        onAdd(pairs)
                    }
                    .disabled(!isValid)
                    .accessibilityIdentifier("multipair_confirm_button")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var isValid: Bool {
        guard !rows.isEmpty else { return false }
        return rows.allSatisfy { row in
            !row.key.trimmingCharacters(in: .whitespaces).isEmpty &&
            !row.value.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}
