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

// MARK: - Design Tokens (styles.md)

extension Color {
    static let osPrimary = Color(red: 229/255, green: 75/255, blue: 77/255)
    static let osSuccess = Color(red: 52/255, green: 168/255, blue: 83/255)
    static let osGrey700 = Color(red: 97/255, green: 97/255, blue: 97/255)
    static let osGrey600 = Color(red: 117/255, green: 117/255, blue: 117/255)
    static let osGrey500 = Color(red: 158/255, green: 158/255, blue: 158/255)
    static let osLightBackground = Color(red: 248/255, green: 249/255, blue: 250/255)
    static let osCardBackground = Color.white
    static let osDivider = Color(red: 232/255, green: 234/255, blue: 237/255)
    static let osWarningBackground = Color(red: 255/255, green: 248/255, blue: 225/255)
    static let osBackdrop = Color.black.opacity(0.54)
    static let osLogBackground = Color(red: 26/255, green: 27/255, blue: 30/255)
    static let osLogDebug = Color(red: 130/255, green: 170/255, blue: 255/255)
    static let osLogInfo = Color(red: 195/255, green: 232/255, blue: 141/255)
    static let osLogWarn = Color(red: 255/255, green: 203/255, blue: 107/255)
    static let osLogError = Color(red: 255/255, green: 83/255, blue: 112/255)
    static let osLogTimestamp = Color(red: 103/255, green: 110/255, blue: 123/255)
}

// MARK: - Action Buttons

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.osPrimary.opacity(configuration.isPressed ? 0.8 : 1.0))
            .cornerRadius(8)
    }
}

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

struct OutlineActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.osPrimary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.clear.opacity(configuration.isPressed ? 0.05 : 0.0))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.osPrimary, lineWidth: 1)
            )
    }
}

struct OutlineActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(OutlineActionButtonStyle())
    }
}

struct ActionButtonWithIcon: View {
    let title: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .textCase(.uppercase)
                Spacer()
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 16)
            .background(Color.osPrimary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Container

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.osCardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.1), lineWidth: 2)
        )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var tooltipKey: String?

    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.osGrey700)
                .kerning(0.5)
                .textCase(.uppercase)

            Spacer()

            if tooltipKey != nil {
                Button {
                    let tooltip = tooltipKey.flatMap { TooltipService.shared.getTooltip(key: $0) }
                        ?? TooltipData(title: title, description: "Tooltip content not available.", options: nil)
                    viewModel.activeTooltip = tooltip
                    viewModel.showingTooltip = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.osGrey500)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - Tooltip Dialog

struct TooltipDialog: View {
    let tooltip: TooltipData
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tooltip.title)
                .font(.system(size: 20, weight: .semibold))

            Text(tooltip.description)
                .font(.system(size: 14))
                .foregroundColor(.osGrey600)

            if let options = tooltip.options {
                ForEach(options, id: \.name) { option in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text(option.description)
                            .font(.system(size: 13))
                            .foregroundColor(.osGrey600)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Ok") { onClose() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.osPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Key-Value Row (Stacked layout)

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
                    .font(.system(size: 14))
                Text(item.value)
                    .font(.system(size: 12))
                    .foregroundColor(.osGrey600)
            }

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(.osPrimary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Single Value Row (Unstacked layout)

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
                .font(.system(size: 14))

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(.osPrimary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Info Row

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
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14))
            Spacer()
            Text(value)
                .font(isMonospaced ? .system(size: 12, design: .monospaced) : .system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let isEnabled: Bool

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>, isEnabled: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.isEnabled = isEnabled
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.osGrey600)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Empty List Row

struct EmptyListRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundColor(.osGrey600)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }
}

// MARK: - Card Divider

struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.osDivider)
            .frame(height: 1)
    }
}

// MARK: - Text Input Field (styles.md spec)

struct OSTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16))
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .focused($isFocused)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .background(Color.osCardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.osPrimary : Color.osGrey700,
                            lineWidth: isFocused ? 2 : 1)
            )
    }
}

// MARK: - Dialog Overlay Container

struct DialogOverlay<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.54)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                content
            }
            .padding(24)
            .background(Color.osCardBackground)
            .cornerRadius(28)
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Dialog Action Buttons

struct DialogActions: View {
    let cancelTitle: String
    let confirmTitle: String
    let isConfirmEnabled: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    init(
        cancelTitle: String = "Cancel",
        confirmTitle: String,
        isConfirmEnabled: Bool = true,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isConfirmEnabled = isConfirmEnabled
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    var body: some View {
        HStack(spacing: 8) {
            Spacer()

            Button(cancelTitle) { onCancel() }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.osPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Button(confirmTitle) { onConfirm() }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isConfirmEnabled ? .osPrimary : .osGrey500)
                .disabled(!isConfirmEnabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }
}
