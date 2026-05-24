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

/// Tooltip dialog body shown when the user taps a section's info icon.
/// Single OK action — no Cancel. Presented as a centered modal via
/// `osCenteredDialog`, so this view renders only the card chrome.
struct TooltipDialog: View {
    let tooltip: TooltipData
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tooltip.title)
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(OS.Color.bodyText)
                .accessibilityIdentifier("tooltip_title")

            ViewThatFits(in: .vertical) {
                bodyContent
                ScrollView { bodyContent }
            }

            HStack {
                Spacer()
                OSDialogActionButton(
                    title: "OK",
                    accessibilityID: "tooltip_ok_button",
                    isEnabled: true,
                    action: onClose
                )
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OS.Color.cardBackground)
        .accessibilityIdentifier("tooltip_sheet")
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tooltip.description)
                .font(OS.Font.bodyMedium)
                .foregroundColor(OS.Color.bodyText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("tooltip_description")

            if let options = tooltip.options, !options.isEmpty {
                Rectangle()
                    .fill(OS.Color.divider)
                    .frame(height: OS.Layout.dividerHeight)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(options, id: \.name) { option in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.name)
                                .font(OS.Font.bodyMedium.weight(.semibold))
                                .foregroundColor(OS.Color.bodyText)
                            Text(option.description)
                                .font(OS.Font.bodyMedium)
                                .foregroundColor(OS.Color.grey600)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}
