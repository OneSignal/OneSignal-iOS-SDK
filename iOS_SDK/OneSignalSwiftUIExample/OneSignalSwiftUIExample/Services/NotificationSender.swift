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
import OneSignalFramework

/// Service for sending push notifications via OneSignal API
/// Note: This is for demo purposes only. In production, API calls should be made from your backend.
final class NotificationSender {

    static let shared = NotificationSender()

    private let apiURL = URL(string: "https://onesignal.com/api/v1/notifications")!
    private let imageURL = "https://media.onesignal.com/automated_push_templates/ratings_template.png"

    private init() {}

    // MARK: - Public Methods

    /// Send a simple push notification with a basic title and body
    func sendSimpleNotification(
        appId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let subscriptionId = getSubscriptionId(completion: completion) else { return }

        let payload: [String: Any] = [
            "app_id": appId,
            "include_subscription_ids": [subscriptionId],
            "headings": ["en": "Simple Notification"],
            "contents": ["en": "This is a simple test notification from OneSignal."],
            "ios_sound": "nil"
        ]

        sendRequest(payload: payload, completion: completion)
    }

    /// Send a push notification that includes a big image
    func sendNotificationWithImage(
        appId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let subscriptionId = getSubscriptionId(completion: completion) else { return }

        let payload: [String: Any] = [
            "app_id": appId,
            "include_subscription_ids": [subscriptionId],
            "headings": ["en": "Image Notification"],
            "contents": ["en": "This notification includes an image attachment."],
            "ios_attachments": ["image": imageURL],
            "big_picture": imageURL,
            "ios_sound": "nil"
        ]

        sendRequest(payload: payload, completion: completion)
    }

    /// Send a custom push notification with user-provided title and body
    func sendCustomNotification(
        title: String,
        body: String,
        appId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let subscriptionId = getSubscriptionId(completion: completion) else { return }

        let payload: [String: Any] = [
            "app_id": appId,
            "include_subscription_ids": [subscriptionId],
            "headings": ["en": title],
            "contents": ["en": body],
            "ios_sound": "nil"
        ]

        sendRequest(payload: payload, completion: completion)
    }

    // MARK: - Private Helpers

    private func getSubscriptionId(completion: @escaping (Result<Void, Error>) -> Void) -> String? {
        guard let subscriptionId = OneSignal.User.pushSubscription.id else {
            completion(.failure(NotificationError.noSubscriptionId))
            return nil
        }

        guard OneSignal.User.pushSubscription.optedIn else {
            completion(.failure(NotificationError.notOptedIn))
            return nil
        }

        return subscriptionId
    }

    private func sendRequest(
        payload: [String: Any],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.onesignal.v1+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[OneSignal] Failed to send notification: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 202 {
                    if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                        print("[OneSignal] Success sending notification: \(responseStr)")
                    }
                    completion(.success(()))
                } else {
                    if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                        print("[OneSignal] Failed (\(httpResponse.statusCode)): \(responseStr)")
                    }
                    completion(.failure(NotificationError.apiError(statusCode: httpResponse.statusCode)))
                }
            }
        }.resume()
    }
}

// MARK: - Errors

enum NotificationError: LocalizedError {
    case noSubscriptionId
    case notOptedIn
    case apiError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noSubscriptionId:
            return "No push subscription ID available"
        case .notOptedIn:
            return "Push notifications not opted in"
        case .apiError(let statusCode):
            return "API error with status code: \(statusCode)"
        }
    }
}
