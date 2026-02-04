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

/// A row displaying a key-value pair with optional delete action
struct KeyValueRow: View {
    let item: KeyValueItem
    let onDelete: (() -> Void)?
    
    init(item: KeyValueItem, onDelete: (() -> Void)? = nil) {
        self.item = item
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.key)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(item.value)
                    .font(.body)
            }
            
            Spacer()
            
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
    }
}

/// A row displaying a single value with optional delete action
struct SingleValueRow: View {
    let value: String
    let onDelete: (() -> Void)?
    
    init(value: String, onDelete: (() -> Void)? = nil) {
        self.value = value
        self.onDelete = onDelete
    }
    
    var body: some View {
        HStack {
            Text(value)
                .font(.body)
            
            Spacer()
            
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
    }
}

/// A row displaying a label and value in a horizontal layout
struct InfoRow: View {
    let label: String
    let value: String
    let isMonospaced: Bool
    
    init(label: String, value: String, isMonospaced: Bool = false) {
        self.label = label
        self.value = value
        self.isMonospaced = isMonospaced
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// A placeholder row for empty lists
struct EmptyListRow: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundColor(.secondary)
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }
}

#Preview {
    List {
        Section("Key-Value Items") {
            KeyValueRow(
                item: KeyValueItem(key: "external_id", value: "user_123"),
                onDelete: {}
            )
            KeyValueRow(
                item: KeyValueItem(key: "subscription_tier", value: "premium")
            )
        }
        
        Section("Single Values") {
            SingleValueRow(value: "user@example.com", onDelete: {})
            SingleValueRow(value: "+1234567890")
        }
        
        Section("Info Rows") {
            InfoRow(label: "App ID", value: "77e32082-ea27-42e3-a898-c72e141824ef", isMonospaced: true)
            InfoRow(label: "Status", value: "Active")
        }
        
        Section("Empty") {
            EmptyListRow(message: "No items added")
        }
    }
}
