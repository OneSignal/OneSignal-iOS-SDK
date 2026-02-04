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
    
    private init() {}
    
    /// Send a notification to this device through the OneSignal Platform.
    /// Note: This form of API should not be used in production as it is not safe.
    /// The device should make an API call to its own backend, which handles the OneSignal API call.
    func sendNotification(
        type: NotificationType,
        appId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let subscriptionId = OneSignal.User.pushSubscription.id else {
            completion(.failure(NotificationError.noSubscriptionId))
            return
        }
        
        guard OneSignal.User.pushSubscription.optedIn else {
            completion(.failure(NotificationError.notOptedIn))
            return
        }
        
        let templateData = type.getNextTemplate()
        
        var payload: [String: Any] = [
            "app_id": appId,
            "include_subscription_ids": [subscriptionId],
            "contents": ["en": templateData.message],
            "ios_sound": "nil"
        ]
        
        // Add title if present
        if !templateData.title.isEmpty {
            payload["headings"] = ["en": templateData.title]
        }
        
        // Add large icon if present
        if !templateData.largeIconUrl.isEmpty {
            payload["ios_attachments"] = ["icon": templateData.largeIconUrl]
        }
        
        // Add big picture if present
        if !templateData.bigPictureUrl.isEmpty {
            payload["big_picture"] = templateData.bigPictureUrl
        }
        
        // Add buttons for Breaking News
        if type == .breakingNews {
            payload["buttons"] = [
                ["id": "view", "text": "View"],
                ["id": "save", "text": "Save"],
                ["id": "share", "text": "Share"]
            ]
        }
        
        // Add thread/group ID for notification grouping
        payload["thread_id"] = type.rawValue
        
        sendRequest(payload: payload, completion: completion)
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
                print("💛 [OneSignal] Failed to send notification: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 202 {
                    if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                        print("💛 [OneSignal] Success sending notification: \(responseStr)")
                    }
                    completion(.success(()))
                } else {
                    if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                        print("💛 [OneSignal] Failed to send notification (\(httpResponse.statusCode)): \(responseStr)")
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

// MARK: - Notification Template Data

struct NotificationTemplateData {
    let title: String
    let message: String
    let largeIconUrl: String
    let bigPictureUrl: String
}

// MARK: - Notification Data (matching Android NotificationData.java)

extension NotificationType {
    
    private static var templatePositions: [NotificationType: Int] = [:]
    
    /// Get the next template data, cycling through available templates
    func getNextTemplate() -> NotificationTemplateData {
        let templates = self.templates
        var pos = NotificationType.templatePositions[self] ?? 0
        
        let template = templates[pos]
        
        pos += 1
        if pos >= templates.count {
            pos = 0
        }
        NotificationType.templatePositions[self] = pos
        
        return template
    }
    
    private var templates: [NotificationTemplateData] {
        switch self {
        case .general:
            return [
                NotificationTemplateData(
                    title: "Liked post",
                    message: "Michael DiCioccio liked your post!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fbell_red.png?alt=media&token=c80c4e76-1fd7-4912-93f4-f1aee1d98b20",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "Birthdays",
                    message: "Say happy birthday to Rodrigo and 5 others!",
                    largeIconUrl: "https://images.vexels.com/media/users/3/147226/isolated/preview/068af50eededd7a739aac52d8e509ab5-three-candles-birthday-cake-icon-by-vexels.png",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "New Post",
                    message: "Neil just posted for the first time in a while, check it out!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fbell_red.png?alt=media&token=c80c4e76-1fd7-4912-93f4-f1aee1d98b20",
                    bigPictureUrl: ""
                )
            ]
            
        case .greetings:
            return [
                NotificationTemplateData(
                    title: "",
                    message: "Welcome to Nike!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fhuman-greeting-red.png?alt=media&token=cb9f3418-db61-443c-955a-57e664d30271",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Welcome to Adidas!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fhuman-greeting-red.png?alt=media&token=cb9f3418-db61-443c-955a-57e664d30271",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Welcome to Sandra's cooking blog!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fhuman-greeting-red.png?alt=media&token=cb9f3418-db61-443c-955a-57e664d30271",
                    bigPictureUrl: ""
                )
            ]
            
        case .promotions:
            return [
                NotificationTemplateData(
                    title: "",
                    message: "Get 20% off site-wide!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fbrightness-percent-red.png?alt=media&token=9e43c45e-8bcc-413e-8a42-612020c406ba",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Half-off all shoes today only!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fbrightness-percent-red.png?alt=media&token=9e43c45e-8bcc-413e-8a42-612020c406ba",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "3 hour flash sale!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fbrightness-percent-red.png?alt=media&token=9e43c45e-8bcc-413e-8a42-612020c406ba",
                    bigPictureUrl: ""
                )
            ]
            
        case .breakingNews:
            return [
                NotificationTemplateData(
                    title: "The rap game won't be the same",
                    message: "Nipsey Hussle shot dead in his own hometown!",
                    largeIconUrl: "https://pbs.twimg.com/profile_images/719602655337656321/kQUzR2Es_400x400.jpg",
                    bigPictureUrl: "https://lab.fm/wp-content/uploads/2019/04/nipsey-hussle-cipriani-diamond-ball-2018-nyc-credit-jstone-shutterstock@1800x1013.jpg"
                ),
                NotificationTemplateData(
                    title: "CNN being bought by Fox?",
                    message: "Fox has shown an increasing interest in purchasing CNN and because of some other deals this year it could actually happen!",
                    largeIconUrl: "https://www.thewrap.com/sites/default/wp-content/uploads/files/2013/Jul/08/101771/gallupinside.png",
                    bigPictureUrl: "https://i.ytimg.com/vi/C8YBKBuX43Q/maxresdefault.jpg"
                ),
                NotificationTemplateData(
                    title: "Tesla's next venture!",
                    message: "Tesla releasing fully autonomous driving service!",
                    largeIconUrl: "https://i.etsystatic.com/13567406/r/il/6657a5/1083941709/il_794xN.1083941709_k3vi.jpg",
                    bigPictureUrl: "https://electrek.co/wp-content/uploads/sites/3/2018/01/screen-shot-2018-01-04-at-12-59-25-pm.jpg?quality=82&strip=all&w=1600"
                )
            ]
            
        case .abandonedCart:
            return [
                NotificationTemplateData(
                    title: "",
                    message: "You have some shoes left in your cart!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fcart-red.png?alt=media&token=3e9ca206-540c-4275-8f21-1840e9cba930",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Still want to buy the dress you saw?",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fcart-red.png?alt=media&token=3e9ca206-540c-4275-8f21-1840e9cba930",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "20% off the shoes you saw today.",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fcart-red.png?alt=media&token=3e9ca206-540c-4275-8f21-1840e9cba930",
                    bigPictureUrl: ""
                )
            ]
            
        case .newPost:
            return [
                NotificationTemplateData(
                    title: "",
                    message: "I just published a new blog post!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fimage-red.png?alt=media&token=3f44fd3d-27a5-4d05-9544-423edf2f6284",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Come check out my new blog post on aliens!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fimage-red.png?alt=media&token=3f44fd3d-27a5-4d05-9544-423edf2f6284",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "10 places you have to see before you die.",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fimage-red.png?alt=media&token=3f44fd3d-27a5-4d05-9544-423edf2f6284",
                    bigPictureUrl: ""
                )
            ]
            
        case .reEngagement:
            return [
                NotificationTemplateData(
                    title: "",
                    message: "Your friend George just joined Facebook",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fgesture-tap-red.png?alt=media&token=8ea7f6db-18e4-4fdd-aabf-ac97f04522fd",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Can you beat level 23?",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fgesture-tap-red.png?alt=media&token=8ea7f6db-18e4-4fdd-aabf-ac97f04522fd",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Check out our Fall collection!",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fgesture-tap-red.png?alt=media&token=8ea7f6db-18e4-4fdd-aabf-ac97f04522fd",
                    bigPictureUrl: ""
                )
            ]
            
        case .rating:
            return [
                NotificationTemplateData(
                    title: "",
                    message: "How was your food/experience at Chipotle?",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fstar-red.png?alt=media&token=e18e99ce-96ad-4ee5-b0b9-40c7f90613d1",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Rate your experience with Amazon.",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fstar-red.png?alt=media&token=e18e99ce-96ad-4ee5-b0b9-40c7f90613d1",
                    bigPictureUrl: ""
                ),
                NotificationTemplateData(
                    title: "",
                    message: "Let your Lyft driver know how the ride was.",
                    largeIconUrl: "https://firebasestorage.googleapis.com/v0/b/onesignaltest-e7802.appspot.com/o/NOTIFICATION_ICON%2Fstar-red.png?alt=media&token=e18e99ce-96ad-4ee5-b0b9-40c7f90613d1",
                    bigPictureUrl: ""
                )
            ]
        }
    }
}
