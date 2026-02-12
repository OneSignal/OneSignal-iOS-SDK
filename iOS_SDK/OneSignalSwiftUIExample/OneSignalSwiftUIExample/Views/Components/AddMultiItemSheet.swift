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

/// A multi-pair add dialog with dynamic rows, matching the Android "Add Tags/Aliases/Triggers" dialog.
struct AddMultiItemSheet: View {
    let type: MultiAddItemType
    let onAdd: ([(String, String)]) -> Void
    let onCancel: () -> Void

    @State private var rows: [(key: String, value: String)] = [("", "")]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Title
                Text(type.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Rows
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(spacing: 8) {
                                TextField("", text: Binding(
                                    get: { rows[index].key },
                                    set: { rows[index].key = $0 }
                                ))
                                .textFieldStyle(UnderlineTextFieldStyle())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                TextField("", text: Binding(
                                    get: { rows[index].value },
                                    set: { rows[index].value = $0 }
                                ))
                                .textFieldStyle(UnderlineTextFieldStyle())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                if rows.count > 1 {
                                    Button {
                                        rows.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }

                // Add Row button
                Button {
                    rows.append(("", ""))
                } label: {
                    Text("+ ADD ROW")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Spacer()

                // Action Buttons
                HStack(spacing: 24) {
                    Spacer()

                    Button("CANCEL") {
                        onCancel()
                    }
                    .foregroundColor(.accentColor)

                    Button("ADD") {
                        let pairs = rows
                            .filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty &&
                                      !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
                            .map { ($0.key, $0.value) }
                        onAdd(pairs)
                    }
                    .foregroundColor(isValid ? .accentColor : .gray)
                    .disabled(!isValid)
                }
                .font(.system(size: 16, weight: .semibold))
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var isValid: Bool {
        rows.allSatisfy {
            !$0.key.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

#Preview {
    AddMultiItemSheet(
        type: .tags,
        onAdd: { pairs in print("Add: \(pairs)") },
        onCancel: { print("Cancel") }
    )
}
