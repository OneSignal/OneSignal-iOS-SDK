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

/// Toggle row inside a card. Label (14) + optional supporting subtitle (12 osGrey600)
/// on the left, native switch on the right.
struct ToggleRow: View {
    let label: String
    let description: String?
    let isOn: Binding<Bool>
    let isDisabled: Bool
    let accessibilityID: String

    init(
        label: String,
        description: String? = nil,
        isOn: Binding<Bool>,
        isDisabled: Bool = false,
        accessibilityID: String
    ) {
        self.label = label
        self.description = description
        self.isOn = isOn
        self.isDisabled = isDisabled
        self.accessibilityID = accessibilityID
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(OS.Font.bodyMedium)
                    .foregroundColor(OS.Color.bodyText)
                if let description = description {
                    Text(description)
                        .font(OS.Font.bodySmall)
                        .foregroundColor(OS.Color.grey600)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(OS.Color.primary)
                .disabled(isDisabled)
                .accessibilityIdentifier(accessibilityID)
        }
        .osCard()
    }
}
