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

// MARK: - Shared list-card chrome

private struct ListCardEmpty: View {
    let text: String
    let accessibilityID: String

    var body: some View {
        Text(text)
            .font(OS.Font.bodyMedium)
            .foregroundColor(OS.Color.grey600)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, OS.Spacing.cardPadding)
            .accessibilityIdentifier(accessibilityID)
            .osCard()
    }
}

private struct ItemDivider: View {
    var body: some View {
        Rectangle()
            .fill(OS.Color.divider)
            .frame(height: OS.Layout.dividerHeight)
    }
}

private struct DeleteButton: View {
    let accessibilityID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: OS.Layout.infoIconSize, weight: .semibold))
                .foregroundColor(OS.Color.primary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }
}

private struct MoreLink: View {
    let hidden: Int
    let onExpand: () -> Void
    let accessibilityID: String

    var body: some View {
        Button(action: onExpand) {
            Text("\(hidden) more")
                .font(OS.Font.bodyMedium.weight(.medium))
                .foregroundColor(OS.Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
    }
}

// MARK: - Stacked (key-value) list

/// List of paired items. Each row shows a 14pt key on top and a 12pt grey value below,
/// with an optional close button to remove. Lists longer than `maxVisible` collapse
/// into a "N more" link.
struct PairList: View {
    let items: [KeyValueItem]
    let emptyText: String
    let sectionKey: String
    let onRemove: ((String) -> Void)?
    let maxVisible: Int

    @State private var expanded = false

    init(
        items: [KeyValueItem],
        emptyText: String,
        sectionKey: String,
        onRemove: ((String) -> Void)? = nil,
        maxVisible: Int = OS.Layout.listMaxVisible
    ) {
        self.items = items
        self.emptyText = emptyText
        self.sectionKey = sectionKey
        self.onRemove = onRemove
        self.maxVisible = maxVisible
    }

    private var visibleItems: [KeyValueItem] {
        expanded ? items : Array(items.prefix(maxVisible))
    }

    private var hiddenCount: Int { max(0, items.count - maxVisible) }

    var body: some View {
        if items.isEmpty {
            ListCardEmpty(text: emptyText, accessibilityID: "\(sectionKey)_empty")
        } else {
            VStack(spacing: 0) {
                ForEach(visibleItems.indices, id: \.self) { index in
                    let item = visibleItems[index]
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.key)
                                .font(OS.Font.bodyMedium)
                                .foregroundColor(OS.Color.bodyText)
                                .accessibilityIdentifier("\(sectionKey)_pair_key_\(item.key)")
                            Text(item.value)
                                .font(OS.Font.bodySmall)
                                .foregroundColor(OS.Color.grey600)
                                .accessibilityIdentifier("\(sectionKey)_pair_value_\(item.key)")
                        }
                        Spacer(minLength: 0)
                        if let onRemove = onRemove {
                            DeleteButton(
                                accessibilityID: "\(sectionKey)_remove_\(item.key)",
                                action: { onRemove(item.key) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)

                    if index < visibleItems.count - 1 {
                        ItemDivider()
                    }
                }
                if !expanded && hiddenCount > 0 {
                    ItemDivider()
                    MoreLink(
                        hidden: hiddenCount,
                        onExpand: { expanded = true },
                        accessibilityID: "\(sectionKey)_more"
                    )
                }
            }
            .osCard()
        }
    }
}

// MARK: - Unstacked (single-string) list

/// List of plain string items (emails, sms numbers). Single 14pt line per row.
struct SingleList: View {
    let items: [String]
    let emptyText: String
    let sectionKey: String
    let onRemove: ((String) -> Void)?
    let maxVisible: Int

    @State private var expanded = false

    init(
        items: [String],
        emptyText: String,
        sectionKey: String,
        onRemove: ((String) -> Void)? = nil,
        maxVisible: Int = OS.Layout.listMaxVisible
    ) {
        self.items = items
        self.emptyText = emptyText
        self.sectionKey = sectionKey
        self.onRemove = onRemove
        self.maxVisible = maxVisible
    }

    private var visibleItems: [String] {
        expanded ? items : Array(items.prefix(maxVisible))
    }

    private var hiddenCount: Int { max(0, items.count - maxVisible) }

    var body: some View {
        if items.isEmpty {
            ListCardEmpty(text: emptyText, accessibilityID: "\(sectionKey)_empty")
        } else {
            VStack(spacing: 0) {
                ForEach(visibleItems.indices, id: \.self) { index in
                    let item = visibleItems[index]
                    HStack(alignment: .center, spacing: 8) {
                        Text(item)
                            .font(OS.Font.bodyMedium)
                            .foregroundColor(OS.Color.bodyText)
                            .accessibilityIdentifier("\(sectionKey)_value_\(item)")
                        Spacer(minLength: 0)
                        if let onRemove = onRemove {
                            DeleteButton(
                                accessibilityID: "\(sectionKey)_remove_\(item)",
                                action: { onRemove(item) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)

                    if index < visibleItems.count - 1 {
                        ItemDivider()
                    }
                }
                if !expanded && hiddenCount > 0 {
                    ItemDivider()
                    MoreLink(
                        hidden: hiddenCount,
                        onExpand: { expanded = true },
                        accessibilityID: "\(sectionKey)_more"
                    )
                }
            }
            .osCard()
        }
    }
}
