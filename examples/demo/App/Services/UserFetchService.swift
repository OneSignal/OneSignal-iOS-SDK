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

/// Reads the OneSignal /users API to hydrate aliases / tags / channels in the demo
final class UserFetchService {
    static let shared = UserFetchService()
    private init() {}

    func fetchUser(appId: String, onesignalId: String) async -> UserData? {
        let urlString = "https://api.onesignal.com/apps/\(appId)/users/by/onesignal_id/\(onesignalId)"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return parse(json)
        } catch {
            return nil
        }
    }

    private func parse(_ json: [String: Any]) -> UserData {
        let identity = json["identity"] as? [String: Any] ?? [:]
        let properties = json["properties"] as? [String: Any] ?? [:]
        let subscriptions = json["subscriptions"] as? [[String: Any]] ?? []

        var aliases: [String: String] = [:]
        for (key, value) in identity {
            guard key != "external_id", key != "onesignal_id" else { continue }
            if let stringValue = value as? String {
                aliases[key] = stringValue
            }
        }

        var tags: [String: String] = [:]
        if let rawTags = properties["tags"] as? [String: Any] {
            for (key, value) in rawTags {
                if let stringValue = value as? String {
                    tags[key] = stringValue
                }
            }
        }

        var emails: [String] = []
        var smsNumbers: [String] = []
        for sub in subscriptions {
            let type = sub["type"] as? String ?? ""
            let token = sub["token"] as? String ?? ""
            guard !token.isEmpty else { continue }
            if type == "Email" { emails.append(token) }
            if type == "SMS" { smsNumbers.append(token) }
        }

        let externalId = identity["external_id"] as? String

        return UserData(
            aliases: aliases,
            tags: tags,
            emails: emails,
            smsNumbers: smsNumbers,
            externalId: externalId
        )
    }
}
