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

/// Service that fetches and provides tooltip content from the shared sdk-shared repo.
/// Tooltips are non-critical; if the fetch fails, they are simply unavailable.
final class TooltipService: ObservableObject {

    static let shared = TooltipService()

    private let tooltipURL = URL(string: "https://raw.githubusercontent.com/OneSignal/sdk-shared/main/demo/tooltip_content.json")!

    @Published private(set) var tooltips: [String: TooltipData] = [:]
    private var initialized = false

    private init() {}

    /// Fetch tooltip content on a background thread. Safe to call multiple times; only fetches once.
    func initialize() {
        guard !initialized else { return }
        initialized = true

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.fetchTooltips()
        }
    }

    /// Returns tooltip data for the given section key, or nil if unavailable.
    func getTooltip(key: String) -> TooltipData? {
        tooltips[key]
    }

    // MARK: - Private

    private func fetchTooltips() {
        var request = URLRequest(url: tooltipURL)
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil else {
                print("[TooltipService] Failed to fetch tooltips: \(error?.localizedDescription ?? "unknown")")
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                var parsed: [String: TooltipData] = [:]

                for (key, value) in json {
                    guard let dict = value as? [String: Any],
                          let title = dict["title"] as? String,
                          let description = dict["description"] as? String else { continue }

                    var options: [TooltipOption]?
                    if let optionsArray = dict["options"] as? [[String: Any]] {
                        options = optionsArray.compactMap { optDict in
                            guard let name = optDict["name"] as? String,
                                  let desc = optDict["description"] as? String else { return nil }
                            return TooltipOption(name: name, description: desc)
                        }
                    }

                    parsed[key] = TooltipData(title: title, description: description, options: options)
                }

                DispatchQueue.main.async {
                    self?.tooltips = parsed
                    print("[TooltipService] Loaded \(parsed.count) tooltips")
                }
            } catch {
                print("[TooltipService] Failed to parse tooltips: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
}
