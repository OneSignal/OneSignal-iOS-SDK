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

/// Loads tooltip content shared with the other OneSignal demo apps
final class TooltipService {
    static let shared = TooltipService()

    private static let remoteURL = URL(
        string: "https://raw.githubusercontent.com/OneSignal/sdk-shared/main/demo/tooltip_content.json"
    )!

    private var cache: [String: TooltipData] = [:]
    private var loaded = false

    private init() {
        cache = TooltipService.bundledFallback()
    }

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true

        Task.detached { [weak self] in
            guard let self = self else { return }
            guard let (data, response) = try? await URLSession.shared.data(from: TooltipService.remoteURL),
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            var parsed: [String: TooltipData] = [:]
            for (key, value) in json {
                guard let dict = value as? [String: Any],
                      let title = dict["title"] as? String,
                      let description = dict["description"] as? String else {
                    continue
                }
                let options: [TooltipOption]?
                if let rawOptions = dict["options"] as? [[String: Any]] {
                    options = rawOptions.compactMap { entry -> TooltipOption? in
                        guard let name = entry["name"] as? String,
                              let optDescription = entry["description"] as? String else { return nil }
                        return TooltipOption(name: name, description: optDescription)
                    }
                } else {
                    options = nil
                }
                parsed[key] = TooltipData(title: title, description: description, options: options)
            }
            await MainActor.run {
                if !parsed.isEmpty {
                    self.cache = parsed
                }
            }
        }
    }

    func tooltip(for key: String) -> TooltipData? {
        cache[key]
    }

    /// Minimal fallback content (keys match the sdk-shared tooltip JSON) so info icons
    /// still work without network. `app` and `user` are demo-only and not in sdk-shared.
    private static func bundledFallback() -> [String: TooltipData] {
        [
            "app": TooltipData(
                title: "App",
                description: "Your OneSignal App ID and consent settings.",
                options: nil
            ),
            "user": TooltipData(
                title: "User",
                description: "External User Id is your own identifier for the current user. Login/logout to associate the device with a user.",
                options: nil
            ),
            "push": TooltipData(
                title: "Push Subscription",
                description: "The push subscription for this device. Enables push notifications, in-app messages, and Live Activities.",
                options: nil
            ),
            "sendPushNotification": TooltipData(
                title: "Send Push Notification",
                description: "Test push notifications by sending them to this device via the OneSignal REST API.",
                options: nil
            ),
            "inAppMessaging": TooltipData(
                title: "In-App Messaging",
                description: "Display targeted messages inside your app. Pause IAM display while testing.",
                options: nil
            ),
            "sendInAppMessage": TooltipData(
                title: "Send In-App Message",
                description: "Adds an iam_type trigger that your dashboard IAM rules can listen for.",
                options: nil
            ),
            "aliases": TooltipData(
                title: "Aliases",
                description: "Custom label/id pairs that let you reference users by your own identifiers.",
                options: nil
            ),
            "emails": TooltipData(
                title: "Email Subscriptions",
                description: "Email addresses associated with this user.",
                options: nil
            ),
            "sms": TooltipData(
                title: "SMS Subscriptions",
                description: "Phone numbers associated with this user.",
                options: nil
            ),
            "tags": TooltipData(
                title: "Tags",
                description: "Key-value string pairs attached to the user for segmentation and personalization.",
                options: nil
            ),
            "outcomes": TooltipData(
                title: "Outcomes",
                description: "Track user actions attributed to push notifications.",
                options: nil
            ),
            "triggers": TooltipData(
                title: "Triggers",
                description: "Device-local key-value pairs that control when in-app messages display.",
                options: nil
            ),
            "customEvents": TooltipData(
                title: "Custom Events",
                description: "Send custom events with optional properties to trigger Journeys.",
                options: nil
            ),
            "location": TooltipData(
                title: "Location",
                description: "Share device location for location-based segmentation.",
                options: nil
            ),
            "liveActivities": TooltipData(
                title: "Live Activities",
                description: "Display real-time updates on the iOS Lock Screen and Dynamic Island.",
                options: nil
            )
        ]
    }
}
