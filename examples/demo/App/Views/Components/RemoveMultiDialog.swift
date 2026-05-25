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

/// Centered dialog that lets the user pick multiple keys to remove
/// (Remove Tags / Remove Triggers).
struct RemoveMultiDialog: View {
    let type: RemoveMultiItemType
    let items: [KeyValueItem]
    let onRemove: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<String> = []

    var body: some View {
        OSDialog(
            title: type.rawValue,
            confirmLabel: selected.isEmpty ? "Remove" : "Remove (\(selected.count))",
            isConfirmEnabled: !selected.isEmpty,
            confirmAccessibilityID: "multiselect_confirm_button",
            cancelAccessibilityID: "multiselect_cancel_button",
            onConfirm: { onRemove(Array(selected)) },
            onCancel: onCancel
        ) {
            if items.isEmpty {
                Text("Nothing to remove")
                    .font(OS.Font.bodyMedium)
                    .foregroundColor(OS.Color.grey600)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, OS.Spacing.cardPadding)
                    .accessibilityIdentifier("remove_multi_empty")
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(items.indices, id: \.self) { index in
                            let item = items[index]
                            CheckboxRow(
                                item: item,
                                isChecked: selected.contains(item.key),
                                onToggle: { isChecked in
                                    if isChecked {
                                        selected.insert(item.key)
                                    } else {
                                        selected.remove(item.key)
                                    }
                                }
                            )
                            if index < items.count - 1 {
                                Rectangle()
                                    .fill(OS.Color.divider)
                                    .frame(height: OS.Layout.dividerHeight)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }
}

private struct CheckboxRow: View {
    let item: KeyValueItem
    let isChecked: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isChecked)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundColor(isChecked ? OS.Color.primary : OS.Color.grey700)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.key)
                        .font(OS.Font.bodyLarge)
                        .foregroundColor(OS.Color.bodyText)
                    Text(item.value)
                        .font(OS.Font.bodySmall)
                        .foregroundColor(OS.Color.grey600)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("remove_checkbox_\(item.key)")
    }
}
