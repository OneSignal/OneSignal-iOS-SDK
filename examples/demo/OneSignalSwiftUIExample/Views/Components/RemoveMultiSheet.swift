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

/// Sheet that lets the user pick multiple keys to remove (Remove Tags / Remove Triggers)
struct RemoveMultiSheet: View {
    let type: RemoveMultiItemType
    let items: [KeyValueItem]
    let onRemove: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Nothing to remove")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("remove_multi_empty")
                } else {
                    Form {
                        ForEach(items) { item in
                            Toggle(isOn: Binding(
                                get: { selected.contains(item.key) },
                                set: { isOn in
                                    if isOn {
                                        selected.insert(item.key)
                                    } else {
                                        selected.remove(item.key)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(item.key)
                                    Text(item.value)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .accessibilityIdentifier("remove_checkbox_\(item.key)")
                        }
                    }
                }
            }
            .navigationTitle(type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("multiselect_cancel_button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Remove (\(selected.count))") {
                        onRemove(Array(selected))
                    }
                    .disabled(selected.isEmpty)
                    .accessibilityIdentifier("multiselect_confirm_button")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
