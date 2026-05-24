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
import OneSignalLiveActivities

/// Order tracking phases used by the Live Activity demo
enum LiveActivityStatus: String, CaseIterable, Identifiable {
    case preparing
    case onTheWay = "on_the_way"
    case delivered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preparing: return "Preparing"
        case .onTheWay: return "On The Way"
        case .delivered: return "Delivered"
        }
    }

    var message: String {
        switch self {
        case .preparing: return "Your order is being prepared"
        case .onTheWay: return "Driver is heading your way"
        case .delivered: return "Order delivered!"
        }
    }

    var estimatedTime: String {
        switch self {
        case .preparing: return "15 min"
        case .onTheWay: return "10 min"
        case .delivered: return ""
        }
    }

    /// Returns the next status in the preparing → on_the_way → delivered → preparing cycle
    var next: LiveActivityStatus {
        switch self {
        case .preparing: return .onTheWay
        case .onTheWay: return .delivered
        case .delivered: return .preparing
        }
    }
}

/// Wraps the OneSignal Live Activities SDK and the REST API endpoints used to update / end activities
enum LiveActivityController {

    @available(iOS 16.1, *)
    static func setup() {
        OneSignal.LiveActivities.setupDefault()
    }

    @available(iOS 16.1, *)
    static func start(
        activityId: String,
        orderNumber: String,
        status: LiveActivityStatus
    ) {
        let attributes: [String: Any] = [
            "orderNumber": orderNumber
        ]
        let content: [String: Any] = [
            "status": status.rawValue,
            "message": status.message,
            "estimatedTime": status.estimatedTime
        ]
        OneSignal.LiveActivities.startDefault(
            activityId,
            attributes: attributes,
            content: content
        )
    }

    static func update(appId: String, activityId: String, status: LiveActivityStatus) async -> Bool {
        let payload: [String: Any] = [
            "event": "update",
            "name": "Live Activity Update",
            "priority": 10,
            "event_updates": [
                "data": [
                    "status": status.rawValue,
                    "message": status.message,
                    "estimatedTime": status.estimatedTime
                ]
            ]
        ]
        return await postLiveActivity(appId: appId, activityId: activityId, payload: payload)
    }

    static func end(appId: String, activityId: String) async -> Bool {
        let payload: [String: Any] = [
            "event": "end",
            "name": "End Live Activity",
            "priority": 10,
            "dismissal_date": Int(Date().timeIntervalSince1970),
            "event_updates": [
                "message": "Ended Live Activity"
            ]
        ]
        return await postLiveActivity(appId: appId, activityId: activityId, payload: payload)
    }

    // The Live Activity API key is read from a Secrets.plist bundled with the demo. Without
    // a key the request returns 401 - we surface that as a failed result so the UI can react.
    private static var apiKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let key = plist["ONESIGNAL_API_KEY"] as? String,
              !key.isEmpty else {
            return nil
        }
        return key
    }

    static var hasApiKey: Bool { apiKey != nil }

    private static func postLiveActivity(appId: String, activityId: String, payload: [String: Any]) async -> Bool {
        guard let key = apiKey else { return false }
        let urlString = "https://api.onesignal.com/apps/\(appId)/live_activities/\(activityId)/notifications"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Key \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
