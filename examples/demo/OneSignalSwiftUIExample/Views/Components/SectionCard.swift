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

/// Card with a section title (ALL CAPS) and optional info icon. Mirrors the Capacitor SectionCard.
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.subheadline.weight(.bold))
                    .kerning(0.5)
                    .foregroundColor(.secondary)
                Spacer()
                if let onInfoTap = onInfoTap {
                    Button(action: onInfoTap) {
                        Image(systemName: "info.circle")
                            .imageScale(.medium)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(sectionKey)_info_icon")
                }
            }

            content()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.vertical, 6)
        .accessibilityIdentifier("\(sectionKey)_section")
    }
}

/// Generic value card used at the top of sections (App ID, Push ID, Status, etc.)
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
                HStack {
                    Text(row.label)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(row.value)
                        .font(row.monospaced ? .system(.footnote, design: .monospaced) : .body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier(row.valueAccessibilityID ?? "")
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)

                if index < rows.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
