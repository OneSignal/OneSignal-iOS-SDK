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

final class LiveActivityApiService {

    static let shared = LiveActivityApiService()

    private let placeholderKey = "YOUR_REST_API_KEY_HERE"

    private init() {}

    var apiKey: String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["ONESIGNAL_API_KEY"] as? String else {
            return nil
        }
        return key
    }

    var hasApiKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty && key != placeholderKey
    }

    enum LiveActivityEvent: String {
        case update
        case end
    }

    func updateLiveActivity(appId: String, activityId: String, event: LiveActivityEvent, eventUpdates: [String: Any] = [:]) async -> Bool {
        guard let key = apiKey, hasApiKey else { return false }

        let urlString = "https://api.onesignal.com/apps/\(appId)/live_activities/\(activityId)/notifications"
        guard let url = URL(string: urlString) else { return false }

        var payload: [String: Any] = [
            "event": event.rawValue,
            "event_updates": eventUpdates,
            "name": event == .end ? "End Live Activity" : "Live Activity Update",
            "priority": 10
        ]

        if event == .end {
            payload["dismissal_date"] = Int(Date().timeIntervalSince1970)
        }

        return await sendRequest(url: url, payload: payload, apiKey: key)
    }

    private func sendRequest(url: URL, payload: [String: Any], apiKey: String) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            await LogManager.shared.e("LiveActivityApi", "Failed to serialize payload: \(error)")
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            let success = (200...299).contains(httpResponse.statusCode)
            if !success {
                let body = String(data: data, encoding: .utf8) ?? ""
                await LogManager.shared.e("LiveActivityApi", "HTTP \(httpResponse.statusCode): \(body)")
            }
            return success
        } catch {
            await LogManager.shared.e("LiveActivityApi", "Request failed: \(error)")
            return false
        }
    }
}
