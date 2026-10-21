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

import Foundation

struct LogEntry: Identifiable, Equatable {
    let id: Int
    let time: String
    let message: String
}

/// Demo logging that marks every console line with `[OneSignal]`.
///
/// `show` and `error` also append to the in-app Log View, which the shared Appium suite reads.
/// All methods are safe to call from any thread.
final class LogService: ObservableObject {
    static let shared = LogService()

    private static let maxEntries = 100

    // In memory only, so every launch (including a cold start from a notification tap) starts empty.
    @Published private(set) var entries: [LogEntry] = []
    private var nextId = 0

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private init() {}

    static func info(_ message: String) {
        print("[OneSignal] \(message)")
    }

    static func show(_ message: String) {
        info(message)
        shared.addToView(message)
    }

    static func error(_ message: String) {
        FileHandle.standardError.write(Data("[OneSignal] \(message)\n".utf8))
        shared.addToView(message)
    }

    func clear() {
        entries.removeAll()
    }

    private func addToView(_ message: String) {
        let time = timeFormatter.string(from: Date())
        DispatchQueue.main.async {
            self.entries.append(LogEntry(id: self.nextId, time: time, message: message))
            self.nextId += 1
            if self.entries.count > Self.maxEntries {
                self.entries.removeFirst(self.entries.count - Self.maxEntries)
            }
        }
    }
}
