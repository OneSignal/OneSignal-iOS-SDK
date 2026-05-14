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

import Foundation
import SwiftUI

/// Log level for categorizing log entries
enum LogLevel: String {
    case debug = "D"
    case info = "I"
    case warning = "W"
    case error = "E"

    var color: Color {
        switch self {
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

/// A single log entry
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

/// Thread-safe pass-through logger that captures logs for UI display and prints to console
@MainActor
final class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var entries: [LogEntry] = []

    private let maxEntries = 100

    private init() {}

    func log(_ tag: String, _ message: String, level: LogLevel = .debug) {
        let entry = LogEntry(timestamp: Date(), level: level, message: "[\(tag)] \(message)")
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        // Also print to console
        print("\(entry.formattedTimestamp) \(level.rawValue) \(entry.message)")
    }

    func clear() {
        entries.removeAll()
    }

    // Convenience methods
    func d(_ tag: String, _ message: String) { log(tag, message, level: .debug) }
    func i(_ tag: String, _ message: String) { log(tag, message, level: .info) }
    func w(_ tag: String, _ message: String) { log(tag, message, level: .warning) }
    func e(_ tag: String, _ message: String) { log(tag, message, level: .error) }
}
