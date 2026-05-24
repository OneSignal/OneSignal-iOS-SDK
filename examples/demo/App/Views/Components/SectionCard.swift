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

/// Section container. Renders a section header (12pt bold uppercase, osGrey700,
/// letter spacing 0.5) above a vertical stack of children. Per the design spec
/// children supply their own card chrome — this view only owns the header.
struct SectionCard<Content: View>: View {
    let title: String
    let sectionKey: String
    let onInfoTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        sectionKey: String,
        onInfoTap: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.sectionKey = sectionKey
        self.onInfoTap = onInfoTap
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OS.Spacing.cardGap) {
            HStack(alignment: .center, spacing: 0) {
                Text(title.uppercased())
                    .font(OS.Font.bodySmall.weight(.bold))
                    .tracking(0.5)
                    .foregroundColor(OS.Color.grey700)
                Spacer(minLength: 0)
                if let onInfoTap = onInfoTap {
                    Button(action: onInfoTap) {
                        Image(systemName: "info.circle")
                            .font(.system(size: OS.Layout.infoIconSize))
                            .foregroundColor(OS.Color.grey500)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, -6)
                    .accessibilityIdentifier("\(sectionKey)_info_icon")
                }
            }

            VStack(alignment: .leading, spacing: OS.Spacing.cardGap) {
                content()
            }
        }
        .accessibilityIdentifier("\(sectionKey)_section")
    }
}

/// Generic value card used at the top of sections (App ID, Push ID, Status, etc.).
/// Renders rows with a 14pt label and a 12pt value (monospace by default for IDs).
struct ValueCard: View {
    struct Row {
        let label: String
        let value: String
        let valueAccessibilityID: String?
        let monospaced: Bool

        init(label: String, value: String, valueAccessibilityID: String? = nil, monospaced: Bool = false) {
            self.label = label
            self.value = value
            self.valueAccessibilityID = valueAccessibilityID
            self.monospaced = monospaced
        }
    }

    let rows: [Row]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                HStack(alignment: .center, spacing: 12) {
                    Text(row.label)
                        .font(OS.Font.bodyMedium)
                        .foregroundColor(OS.Color.bodyText)
                    Spacer(minLength: 0)
                    Text(row.value)
                        .font(row.monospaced ? OS.Font.mono12 : OS.Font.bodySmall)
                        .foregroundColor(OS.Color.bodyText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier(row.valueAccessibilityID ?? "")
                }
                .padding(.vertical, 4)

                if index < rows.count - 1 {
                    Rectangle()
                        .fill(OS.Color.divider)
                        .frame(height: OS.Layout.dividerHeight)
                        .padding(.vertical, 4)
                }
            }
        }
        .osCard()
    }
}
