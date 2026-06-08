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

/// Posts to the OneSignal /notifications REST endpoint to send sample push payloads
final class NotificationSender {
    static let shared = NotificationSender()
    private init() {}

    enum SendError: Error, LocalizedError {
        case noSubscriptionId
        case requestFailed(String)
        case transient(String)

        var errorDescription: String? {
            switch self {
            case .noSubscriptionId: return "No push subscription"
            case .requestFailed(let msg): return msg
            case .transient(let msg): return msg
            }
        }
    }

    private let endpoint = URL(string: "https://onesignal.com/api/v1/notifications")!
    private let maxAttempts = 5

    func sendNotification(
        _ type: NotificationType,
        appId: String,
        subscriptionId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var headings = "Simple Notification"
        var contents = "This is a simple push notification"
        var extra: [String: Any] = [:]

        switch type {
        case .simple:
            break
        case .withImage:
            headings = "Image Notification"
            contents = "This notification includes an image"
            let url = "https://media.onesignal.com/automated_push_templates/ratings_template.png"
            extra["big_picture"] = url
            extra["ios_attachments"] = ["image": url]
        case .withSound:
            headings = "Sound Notification"
            contents = "This notification plays a custom sound"
            extra["ios_sound"] = "vine_boom.wav"
        }

        post(
            appId: appId,
            subscriptionId: subscriptionId,
            heading: headings,
            content: contents,
            extra: extra,
            attempt: 1,
            completion: completion
        )
    }

    func sendCustomNotification(
        title: String,
        body: String,
        appId: String,
        subscriptionId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        post(
            appId: appId,
            subscriptionId: subscriptionId,
            heading: title,
            content: body,
            extra: [:],
            attempt: 1,
            completion: completion
        )
    }

    private func post(
        appId: String,
        subscriptionId: String,
        heading: String,
        content: String,
        extra: [String: Any],
        attempt: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var payload: [String: Any] = [
            "app_id": appId,
            "include_subscription_ids": [subscriptionId],
            "headings": ["en": heading],
            "contents": ["en": content]
        ]
        payload.merge(extra) { _, new in new }

        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(SendError.requestFailed("Could not encode payload")))
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.onesignal.v1+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(SendError.requestFailed(error.localizedDescription)))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(SendError.requestFailed("Unexpected response")))
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(http.statusCode)"
                completion(.failure(SendError.requestFailed(text)))
                return
            }

            // Treat 200 with empty id / errors / zero recipients as a transient backend race
            // (subscription not yet indexed) and retry with exponential backoff.
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               self.isTransientFailure(json) {
                if attempt < self.maxAttempts {
                    let delay = UInt64(2_000_000_000) * UInt64(1 << (attempt - 1))
                    Task {
                        try? await Task.sleep(nanoseconds: delay)
                        self.post(
                            appId: appId,
                            subscriptionId: subscriptionId,
                            heading: heading,
                            content: content,
                            extra: extra,
                            attempt: attempt + 1,
                            completion: completion
                        )
                    }
                    return
                }
                completion(.failure(SendError.transient(String(describing: json))))
                return
            }

            completion(.success(()))
        }.resume()
    }

    private func isTransientFailure(_ json: [String: Any]) -> Bool {
        let id = json["id"] as? String ?? ""
        if id.isEmpty { return true }
        if let recipients = json["recipients"] as? Int, recipients == 0 { return true }
        if let errorsDict = json["errors"] as? [String: Any], !errorsDict.isEmpty { return true }
        if let errorsArr = json["errors"] as? [Any], !errorsArr.isEmpty { return true }
        return false
    }
}
