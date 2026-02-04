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

// MARK: - Action Button Style

/// A full-width red button with white uppercase text
struct ActionButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            .cornerRadius(8)
    }
}

/// A full-width action button matching the screenshot style
struct ActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(ActionButtonStyle())
    }
}

// MARK: - Card Container

/// A white card container with rounded corners
struct CardContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Section Header

/// A small gray section header
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

// MARK: - Key-Value Row

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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Single Value Row

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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Info Row

/// A row displaying a label and value (like "Push-Id: xxx")
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
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
            Text(value)
                .font(isMonospaced ? .system(size: 15, design: .monospaced) : .system(size: 15))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Toggle Row

/// A toggle row with title and optional subtitle
struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    
    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty List Row

/// A placeholder row for empty lists
struct EmptyListRow: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }
}

// MARK: - Divider Line

/// A subtle divider for card sections
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            SectionHeader(title: "Key-Value Items")
            CardContainer {
                KeyValueRow(
                    item: KeyValueItem(key: "external_id", value: "user_123"),
                    onDelete: {}
                )
                CardDivider()
                KeyValueRow(
                    item: KeyValueItem(key: "subscription_tier", value: "premium")
                )
            }
            
            SectionHeader(title: "Info Rows")
            CardContainer {
                InfoRow(label: "Push-Id:", value: "77e32082-ea27-42e3-a898-c72e141824ef", isMonospaced: true)
                CardDivider()
                ToggleRow(title: "Enabled", isOn: .constant(true))
            }
            
            SectionHeader(title: "Empty")
            CardContainer {
                EmptyListRow(message: "No Items Added")
            }
            
            ActionButton(title: "Add Item") {}
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
