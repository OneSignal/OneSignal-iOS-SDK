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

/// Collapsible log view showing SDK and app logs, matching Android's LogView
struct LogView: View {
    @ObservedObject var logManager: LogManager
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("LOGS")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("(\(logManager.entries.count))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        logManager.clear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Log entries (expanded)
            if isExpanded {
                Divider()

                if logManager.entries.isEmpty {
                    Text("No logs yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(logManager.entries) { entry in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(entry.formattedTimestamp)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.secondary)

                                        Text(entry.level.rawValue)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(entry.level.color)

                                        Text(entry.message)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 2)
                                    .id(entry.id)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 100)
                        .onChange(of: logManager.entries.count) { _ in
                            if let lastEntry = logManager.entries.last {
                                withAnimation {
                                    proxy.scrollTo(lastEntry.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(0)
    }
}

#Preview {
    VStack {
        LogView(logManager: LogManager.shared)
    }
    .background(Color(.systemGroupedBackground))
}
