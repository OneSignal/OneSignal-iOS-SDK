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

// MARK: - Dialog container

/// Standard dialog body. Wraps the supplied content in a vertical stack with
/// 24pt outer padding, places a 24pt-weight-regular title above it, and pins
/// an action row (Cancel / confirm) to the bottom.
struct OSDialog<Content: View>: View {
    let title: String
    let confirmLabel: String
    let isConfirmEnabled: Bool
    let confirmAccessibilityID: String
    let cancelAccessibilityID: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        confirmLabel: String = "Save",
        isConfirmEnabled: Bool = true,
        confirmAccessibilityID: String = "dialog_confirm_button",
        cancelAccessibilityID: String = "dialog_cancel_button",
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.confirmLabel = confirmLabel
        self.isConfirmEnabled = isConfirmEnabled
        self.confirmAccessibilityID = confirmAccessibilityID
        self.cancelAccessibilityID = cancelAccessibilityID
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(OS.Color.bodyText)

            content()

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                OSDialogActionButton(
                    title: "Cancel",
                    accessibilityID: cancelAccessibilityID,
                    isEnabled: true,
                    action: onCancel
                )
                OSDialogActionButton(
                    title: confirmLabel,
                    accessibilityID: confirmAccessibilityID,
                    isEnabled: isConfirmEnabled,
                    action: onConfirm
                )
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OS.Color.cardBackground)
    }
}

// MARK: - Dialog action button

/// Text-style action button for dialog footers.
/// Spec: 14pt, weight medium/500, color osPrimary, 12 horizontal / 8 vertical padding.
struct OSDialogActionButton: View {
    let title: String
    let accessibilityID: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(OS.Font.bodyMedium.weight(.medium))
                .foregroundColor(isEnabled ? OS.Color.primary : OS.Color.grey500)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(accessibilityID)
    }
}

// MARK: - Dialog text inputs

/// Bordered text field used inside dialogs. Spec: 8 corner radius,
/// 12 horizontal / 14 vertical content padding, 1px solid grey700 border,
/// 2px solid osPrimary on focus.
struct OSTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocorrect: Bool = false
    var capitalization: TextInputAutocapitalization = .never
    var accessibilityID: String

    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(OS.Font.bodyMedium)
            .foregroundColor(OS.Color.bodyText)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled(!autocorrect)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .focused($focused)
            .background(
                RoundedRectangle(cornerRadius: OS.Radius.input)
                    .strokeBorder(
                        focused ? OS.Color.primary : OS.Color.grey700,
                        lineWidth: focused ? 2 : 1
                    )
            )
            .accessibilityIdentifier(accessibilityID)
    }
}

/// Bordered multi-line text editor mirroring `OSTextField`'s visual.
struct OSTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 90
    var accessibilityID: String

    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(OS.Font.bodyMedium)
                    .foregroundColor(OS.Color.grey600)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(OS.Font.bodyMedium)
                .foregroundColor(OS.Color.bodyText)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .focused($focused)
                .frame(minHeight: minHeight)
                .accessibilityIdentifier(accessibilityID)
        }
        .background(
            RoundedRectangle(cornerRadius: OS.Radius.input)
                .strokeBorder(
                    focused ? OS.Color.primary : OS.Color.grey700,
                    lineWidth: focused ? 2 : 1
                )
        )
    }
}

// MARK: - Centered dialog presentation

extension View {
    /// Presents `content` as a centered modal dialog over the receiver, matching
    /// the styles.md "Dialogs" spec: 54% black backdrop, 16pt horizontal /
    /// 24pt vertical insets, 28pt corner radius, white card. Tapping the
    /// backdrop dismisses.
    func osCenteredDialog<DialogContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> DialogContent
    ) -> some View {
        modifier(OSCenteredDialogModifier(isPresented: isPresented, dialog: content))
    }
}

private struct OSCenteredDialogModifier<DialogContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder var dialog: () -> DialogContent

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    ZStack {
                        OS.Color.backdrop
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture { isPresented = false }

                        dialog()
                            .clipShape(RoundedRectangle(cornerRadius: OS.Radius.modal))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 24)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isPresented)
    }
}
