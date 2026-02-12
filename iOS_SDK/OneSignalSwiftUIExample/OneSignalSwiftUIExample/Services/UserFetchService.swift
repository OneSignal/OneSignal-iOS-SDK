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

/// Service for fetching user data from the OneSignal REST API.
/// No API key is required for this public endpoint.
final class UserFetchService {

    static let shared = UserFetchService()

    private init() {}

    /// Fetch user data by OneSignal ID. No auth header required.
    func fetchUser(appId: String, onesignalId: String) async -> UserData? {
        let urlString = "https://api.onesignal.com/apps/\(appId)/users/by/onesignal_id/\(onesignalId)"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[UserFetchService] Non-200 response")
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            return parseUserData(json)
        } catch {
            print("[UserFetchService] Fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private

    private func parseUserData(_ json: [String: Any]) -> UserData {
        // Parse identity (aliases)
        var aliases: [String: String] = [:]
        var externalId: String?

        if let identity = json["identity"] as? [String: Any] {
            for (key, value) in identity {
                if key == "external_id" {
                    externalId = value as? String
                } else if key == "onesignal_id" {
                    // Skip onesignal_id from aliases display
                    continue
                } else if let strValue = value as? String {
                    aliases[key] = strValue
                }
            }
        }

        // Parse tags from properties
        var tags: [String: String] = [:]
        if let properties = json["properties"] as? [String: Any],
           let tagsDict = properties["tags"] as? [String: Any] {
            for (key, value) in tagsDict {
                if let strValue = value as? String {
                    tags[key] = strValue
                } else {
                    tags[key] = "\(value)"
                }
            }
        }

        // Parse subscriptions for emails and SMS
        var emails: [String] = []
        var smsNumbers: [String] = []

        if let subscriptions = json["subscriptions"] as? [[String: Any]] {
            for sub in subscriptions {
                guard let type = sub["type"] as? String,
                      let token = sub["token"] as? String else { continue }

                if type == "Email" {
                    emails.append(token)
                } else if type == "SMS" {
                    smsNumbers.append(token)
                }
            }
        }

        return UserData(
            aliases: aliases,
            tags: tags,
            emails: emails,
            smsNumbers: smsNumbers,
            externalId: externalId
        )
    }
}
