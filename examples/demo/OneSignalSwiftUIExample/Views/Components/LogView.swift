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

struct LogView: View {
    @ObservedObject var logManager: LogManager
    @State private var isExpanded = true

    private let bgColor = Color(red: 0.10, green: 0.11, blue: 0.12)
    private let timestampColor = Color(red: 0.40, green: 0.43, blue: 0.48)
    private let iconColor = Color(red: 0.62, green: 0.62, blue: 0.62)

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("LOGS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text("(\(logManager.entries.count))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(iconColor)

                    Spacer()

                    if !logManager.entries.isEmpty {
                        Button {
                            logManager.clear()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(iconColor)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("log_view_clear_button")
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("log_view_header")

            if isExpanded {
                if logManager.entries.isEmpty {
                    Text("No logs yet")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(iconColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .accessibilityIdentifier("log_view_empty")
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(Array(logManager.entries.enumerated()), id: \.element.id) { index, entry in
                                    HStack(alignment: .top, spacing: 4) {
                                        Text(entry.formattedTimestamp)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(timestampColor)

                                        Text(entry.level.rawValue)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(entry.level.color)

                                        Text(entry.message)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 1)
                                    .accessibilityIdentifier("log_entry_\(index)")
                                }
                            }
                        }
                        .frame(height: 100)
                    }
                    .accessibilityIdentifier("log_view_list")
                }
            }
        }
        .background(bgColor)
        .accessibilityIdentifier("log_view_container")
    }
}
