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

/// Design tokens shared across the demo. Mirrors the CSS variables and tables in
/// `sdk-shared/demo/styles.md`.
enum OS {

    // MARK: Colors

    enum Color {
        static let primary           = SwiftUI.Color(red: 0xE5/255, green: 0x4B/255, blue: 0x4D/255)
        static let primaryPressed    = SwiftUI.Color(red: 0xC3/255, green: 0x3F/255, blue: 0x41/255)
        static let success           = SwiftUI.Color(red: 0x34/255, green: 0xA8/255, blue: 0x53/255)
        static let grey700           = SwiftUI.Color(red: 0x61/255, green: 0x61/255, blue: 0x61/255)
        static let grey600           = SwiftUI.Color(red: 0x75/255, green: 0x75/255, blue: 0x75/255)
        static let grey500           = SwiftUI.Color(red: 0x9E/255, green: 0x9E/255, blue: 0x9E/255)
        static let lightBackground   = SwiftUI.Color(red: 0xF8/255, green: 0xF9/255, blue: 0xFA/255)
        static let cardBackground    = SwiftUI.Color.white
        static let cardBorder        = SwiftUI.Color.black.opacity(0.1)
        static let divider           = SwiftUI.Color(red: 0xE8/255, green: 0xEA/255, blue: 0xED/255)
        static let warningBackground = SwiftUI.Color(red: 0xFF/255, green: 0xF8/255, blue: 0xE1/255)
        static let backdrop          = SwiftUI.Color.black.opacity(0.54)
        static let bodyText          = SwiftUI.Color(red: 0x21/255, green: 0x21/255, blue: 0x21/255)
    }

    // MARK: Spacing

    enum Spacing {
        static let cardGap: CGFloat        = 8
        static let sectionGap: CGFloat     = 24
        static let pagePadding: CGFloat    = 16
        static let cardPadding: CGFloat    = 12
    }

    // MARK: Radii

    enum Radius {
        static let card: CGFloat   = 12
        static let button: CGFloat = 8
        static let input: CGFloat  = 8
        static let modal: CGFloat  = 28
    }

    // MARK: Typography

    enum Font {
        static let bodyLarge  = SwiftUI.Font.system(size: 16, weight: .regular)
        static let bodyMedium = SwiftUI.Font.system(size: 14, weight: .regular)
        static let bodySmall  = SwiftUI.Font.system(size: 12, weight: .regular)
        static let mono12     = SwiftUI.Font.system(size: 12, weight: .regular, design: .monospaced)
        static let mono14     = SwiftUI.Font.system(size: 14, weight: .regular, design: .monospaced)
    }

    // MARK: Layout constants

    enum Layout {
        static let buttonHeight: CGFloat       = 48
        static let cardBorderWidth: CGFloat    = 2
        static let inputBorderWidth: CGFloat   = 1
        static let dividerHeight: CGFloat      = 1
        static let infoIconSize: CGFloat       = 18
        static let inlineLabelMinWidth: CGFloat = 80
        static let listMaxVisible: Int         = 5
    }
}

// MARK: - Card chrome modifier

/// Applies the standard demo card visual: white background, 12 corner radius,
/// 2px border, no shadow, 12 px inner padding.
struct CardChrome: ViewModifier {
    var padding: CGFloat = OS.Spacing.cardPadding
    var background: Color = OS.Color.cardBackground

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: OS.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: OS.Radius.card)
                    .strokeBorder(OS.Color.cardBorder, lineWidth: OS.Layout.cardBorderWidth)
            )
    }
}

extension View {
    /// Wraps the receiver in the demo's standard card chrome.
    func osCard(padding: CGFloat = OS.Spacing.cardPadding, background: Color = OS.Color.cardBackground) -> some View {
        modifier(CardChrome(padding: padding, background: background))
    }
}
