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

/// Visual treatment of an action button. The spec defines exactly two variants:
/// the filled primary, and the outlined ("destructive" / secondary) button.
enum ActionButtonStyle {
    case filled
    case outline
}

/// Standard wide button used by sections.
///
/// Matches the spec: full width, 48 tall, 8 corner radius, semibold label,
/// optional 18pt leading icon with 8pt gap before the label.
struct ActionButton: View {
    let title: String
    let style: ActionButtonStyle
    let icon: Image?
    let isDisabled: Bool
    let accessibilityID: String
    let action: () -> Void

    init(
        _ title: String,
        style: ActionButtonStyle = .filled,
        icon: Image? = nil,
        isDisabled: Bool = false,
        accessibilityID: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.icon = icon
        self.isDisabled = isDisabled
        self.accessibilityID = accessibilityID
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    icon
                        .font(.system(size: OS.Layout.infoIconSize, weight: .semibold))
                }
                Text(title)
                    .font(OS.Font.bodyMedium.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: OS.Layout.buttonHeight)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: OS.Radius.button))
            .overlay(border)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityIdentifier(accessibilityID)
    }

    private var backgroundColor: Color {
        switch style {
        case .filled:  return OS.Color.primary
        case .outline: return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:  return .white
        case .outline: return OS.Color.primary
        }
    }

    @ViewBuilder
    private var border: some View {
        if case .outline = style {
            RoundedRectangle(cornerRadius: OS.Radius.button)
                .strokeBorder(OS.Color.primary, lineWidth: 1)
        }
    }
}
