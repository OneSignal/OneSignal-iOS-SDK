/**
 * Modified MIT License
 *
 * Copyright 2026 OneSignal
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

/// Logcat-style panel pinned below the navigation bar.
struct LogView: View {
    @ObservedObject private var logService = LogService.shared
    @State private var collapsed = false

    private static let headerHeight: CGFloat = 24
    private static let bodyHeight: CGFloat = 100
    private static let bottomAnchor = "log_bottom"

    var body: some View {
        VStack(spacing: 0) {
            header
            entryList
        }
        .frame(maxWidth: .infinity)
        .background(OS.Color.logBackground, ignoresSafeAreaEdges: .horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("log_view")
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("LOGS (\(logService.entries.count))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(OS.Color.grey500)
                .frame(maxWidth: .infinity, alignment: .leading)
            HeaderButton(
                systemImage: "trash.fill",
                iconSize: 14,
                label: "Clear logs",
                accessibilityID: "log_clear_button",
                action: logService.clear
            )
            HeaderButton(
                systemImage: collapsed ? "chevron.down" : "chevron.up",
                iconSize: 18,
                label: collapsed ? "Expand logs" : "Collapse logs",
                accessibilityID: "log_toggle_button",
                action: { collapsed.toggle() }
            )
        }
        .padding(.leading, OS.Spacing.pagePadding)
        .padding(.trailing, 9)
        .frame(height: Self.headerHeight)
    }

    // Collapsing shrinks the body to zero height instead of removing it so the
    // entries stay in the accessibility hierarchy.
    private var entryList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Not lazy: XCUITest only sees rows that SwiftUI has instantiated.
                VStack(alignment: .leading, spacing: 0) {
                    if logService.entries.isEmpty {
                        Text("No logs yet")
                            .foregroundColor(OS.Color.grey600)
                            .modifier(EntryText())
                    }
                    ForEach(Array(logService.entries.enumerated()), id: \.element.id) { index, entry in
                        (Text(entry.time).foregroundColor(OS.Color.grey600)
                            + Text(" \(entry.message)").foregroundColor(OS.Color.logText))
                            .modifier(EntryText())
                            .accessibilityIdentifier("log_entry_\(index)")
                    }
                    Color.clear.frame(height: 0).id(Self.bottomAnchor)
                }
                .padding(.horizontal, OS.Spacing.pagePadding)
                .padding(.bottom, 6)
            }
            .frame(height: collapsed ? 0 : Self.bodyHeight)
            .clipped()
            .onAppear { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
            .onChange(of: logService.entries.last?.id) { _ in
                proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
            }
            .onChange(of: collapsed) { isCollapsed in
                if !isCollapsed { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
            }
        }
    }
}

private struct EntryText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 8, design: .monospaced))
            .lineSpacing(8 * 0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct HeaderButton: View {
    let systemImage: String
    let iconSize: CGFloat
    let label: String
    let accessibilityID: String
    let action: () -> Void

    var body: some View {
        // The header is only 24pt tall, so widen the touch target instead.
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize))
                .foregroundColor(OS.Color.grey500)
                .frame(width: 32, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(accessibilityID)
    }
}
