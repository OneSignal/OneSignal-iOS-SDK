/*
 Modified MIT License

 Copyright 2024 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import Foundation
import WidgetKit
import ActivityKit
import SwiftUI

@available(iOS 16.1, *)
extension DynamicIsland {
    public func onesignalClickWidgetURL<T: ActivityAttributes>(
        _ url: URL?,
        context: ActivityViewContext<T>
    ) -> DynamicIsland {
        NSLog("💛 onesignalClickWidgetURL: \(context)")
        let trackingDeepLink = generateTrackingDeepLink(originalURL: url, context: context)
        return self.widgetURL(trackingDeepLink)
    }
}

@available(iOS 16.1, *)
extension View {
    public func onesignalClickWidgetURL<T: OneSignalLiveActivityAttributes>(
        _ url: URL?,
        context: ActivityViewContext<T>
    ) -> some View {
        print("💛 onesignalClickWidgetURL: \(context)")
        let trackingDeepLink = generateTrackingDeepLink(originalURL: url, context: context)
        return self.widgetURL(trackingDeepLink)
    }
}

// MARK: - Helper Function

@available(iOS 16.1, *)
func generateTrackingDeepLink<T: ActivityAttributes>(
    originalURL: URL?,
    context: ActivityViewContext<T>
) -> URL? {
    // Generate a unique click ID
    let clickId = UUID().uuidString

    // Get activity metadata
    let activityId = (context.attributes as? any OneSignalLiveActivityAttributes)?.onesignal.activityId ?? "unknown"
    let activityType = String(describing: T.self)

    // Use bundle ID as scheme (replace dots with hyphens to make it URL-safe)
    // e.g., "com.onesignal.example" becomes "com-onesignal-example"
    guard let bundleId = Bundle.main.bundleIdentifier else {
        return originalURL
    }
    let scheme = bundleId.replacingOccurrences(of: ".", with: "-")

    // Encode the original URL
    var components = URLComponents()
    components.scheme = scheme
    components.host = "onesignal-liveactivity"
    components.path = "/click"

    var queryItems: [URLQueryItem] = [
        URLQueryItem(name: "clickId", value: clickId),
        URLQueryItem(name: "activityId", value: activityId),
        URLQueryItem(name: "activityType", value: activityType)
    ]

    if let originalURL = originalURL {
        queryItems.append(URLQueryItem(name: "redirect", value: originalURL.absoluteString))
    }

    components.queryItems = queryItems

    return components.url ?? originalURL
}
