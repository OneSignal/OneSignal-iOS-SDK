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

/// List of pair items (key + value with optional remove button)
struct PairList: View {
    let items: [KeyValueItem]
    let emptyText: String
    let sectionKey: String
    let onRemove: ((String) -> Void)?

    init(
        items: [KeyValueItem],
        emptyText: String,
        sectionKey: String,
        onRemove: ((String) -> Void)? = nil
    ) {
        self.items = items
        self.emptyText = emptyText
        self.sectionKey = sectionKey
        self.onRemove = onRemove
    }

    var body: some View {
        Group {
            if items.isEmpty {
                Text(emptyText)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .accessibilityIdentifier("\(sectionKey)_empty")
            } else {
                VStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.key)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .accessibilityIdentifier("\(sectionKey)_pair_key_\(item.key)")
                                Text(item.value)
                                    .font(.body)
                                    .accessibilityIdentifier("\(sectionKey)_pair_value_\(item.key)")
                            }
                            Spacer()
                            if let onRemove = onRemove {
                                Button {
                                    onRemove(item.key)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("\(sectionKey)_remove_\(item.key)")
                            }
                        }
                        .padding(12)
                        if index < items.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
    }
}

/// List of single-string items with optional remove button (emails, sms numbers)
struct SingleList: View {
    let items: [String]
    let emptyText: String
    let sectionKey: String
    let onRemove: ((String) -> Void)?

    var body: some View {
        Group {
            if items.isEmpty {
                Text(emptyText)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .accessibilityIdentifier("\(sectionKey)_empty")
            } else {
                VStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        HStack {
                            Text(item)
                                .font(.body)
                                .accessibilityIdentifier("\(sectionKey)_value_\(item)")
                            Spacer()
                            if let onRemove = onRemove {
                                Button {
                                    onRemove(item)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("\(sectionKey)_remove_\(item)")
                            }
                        }
                        .padding(12)
                        if index < items.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
    }
}
