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

/// A checkbox dialog for selectively removing items, matching the Android "Remove Tags/Aliases/Triggers" dialog.
struct RemoveMultiSheet: View {
    let type: RemoveMultiItemType
    let items: [KeyValueItem]
    let onRemove: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selectedKeys: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Title
                Text(type.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Checkbox list
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(items) { item in
                            Button {
                                if selectedKeys.contains(item.key) {
                                    selectedKeys.remove(item.key)
                                } else {
                                    selectedKeys.insert(item.key)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedKeys.contains(item.key) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 22))
                                        .foregroundColor(selectedKeys.contains(item.key) ? .accentColor : .secondary)

                                    Text("\(item.key): \(item.value)")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)

                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            if item.id != items.last?.id {
                                Divider()
                            }
                        }
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

                    Button("REMOVE") {
                        onRemove(Array(selectedKeys))
                    }
                    .foregroundColor(selectedKeys.isEmpty ? .gray : .accentColor)
                    .disabled(selectedKeys.isEmpty)
                }
                .font(.system(size: 16, weight: .semibold))
            }
            .padding(24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    RemoveMultiSheet(
        type: .tags,
        items: [
            KeyValueItem(key: "name", value: "John"),
            KeyValueItem(key: "age", value: "25"),
            KeyValueItem(key: "city", value: "NYC")
        ],
        onRemove: { keys in print("Remove: \(keys)") },
        onCancel: { print("Cancel") }
    )
}
