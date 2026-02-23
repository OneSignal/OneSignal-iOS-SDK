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

// MARK: - Action Button Style

/// A full-width red button with white uppercase text
struct ActionButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1.0))
            .cornerRadius(8)
    }
}

/// A full-width action button matching the screenshot style
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

/// Outlined button style: red border, white background, red text (for destructive actions like LOGOUT)
struct OutlineActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.accentColor)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemBackground).opacity(configuration.isPressed ? 0.8 : 1.0))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
    }
}

/// A full-width outlined action button (red border, white background, red text)
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

/// A full-width action button with a leading icon (for Send In-App Message buttons)
struct ActionButtonWithIcon: View {
    let title: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .textCase(.uppercase)
                Spacer()
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.accentColor)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Container

/// A white card container with rounded corners
struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Section Header

/// A small gray section header with optional info tooltip button
struct SectionHeader: View {
    let title: String
    var tooltipKey: String?

    @State private var showingTooltip = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            if tooltipKey != nil {
                Button {
                    showingTooltip = true
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .alert(isPresented: $showingTooltip) {
            if let key = tooltipKey,
               let tooltip = TooltipService.shared.getTooltip(key: key) {
                var message = tooltip.description
                if let options = tooltip.options {
                    message += "\n"
                    for option in options {
                        message += "\n\(option.name): \(option.description)"
                    }
                }
                return Alert(
                    title: Text(tooltip.title),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                return Alert(
                    title: Text(title),
                    message: Text("Tooltip content not available."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// MARK: - Key-Value Row

/// A row displaying a key-value pair with optional delete action
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
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(item.value)
                    .font(.body)
            }

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Single Value Row

/// A row displaying a single value with optional delete action
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
                .font(.body)

            Spacer()

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Info Row

/// A row displaying a label and value (like "Push-Id: xxx")
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
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(isMonospaced ? .system(size: 15, design: .monospaced) : .system(size: 15))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Toggle Row

/// A toggle row with title and optional subtitle
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
                    .font(.system(size: 15, weight: .medium))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Empty List Row

/// A placeholder row for empty lists
struct EmptyListRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }
}

// MARK: - Divider Line

/// A subtle divider for card sections
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }
}
