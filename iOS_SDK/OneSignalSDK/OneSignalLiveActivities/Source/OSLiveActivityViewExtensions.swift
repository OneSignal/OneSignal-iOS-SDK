/*
 Modified MIT License

 Copyright 2025 OneSignal

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

// Effectively blanks out this file for Mac Catalyst
#if targetEnvironment(macCatalyst)
#else
import WidgetKit
import ActivityKit
import SwiftUI

@available(iOS 16.1, *)
extension DynamicIsland {
    /// Sets the URL that opens the corresponding app of a Live Activity when a user taps on the Live Activity.
    /// Sets OneSignal activity metadata. See Important callout below on usage.
    ///
    /// By setting the URL with this function, it becomes the default URL for deep linking into the app
    /// for each view of the Live Activity. However, if you include a
    /// <doc://com.apple.documentation/documentation/swiftui/link> in the Live Activity,
    /// the link takes priority over the default URL. When a person taps on the `Link`, it takes them to the
    /// place in the app that corresponds to the URL of the `Link`.
    ///
    /// - Parameters:
    ///   - url: The URL that opens the app.
    ///   - context: The activity view context.
    ///
    /// - Returns: The configuration object for the Dynamic Island with the specified URL.
    ///
    /// > Important: Use instead of`.widgetURL`. Requires handling from your app's URL handling code
    /// (e.g., `application(_:open:options:)` in AppDelegate or `onOpenURL` in SwiftUI) using the
    /// `OneSignal.LiveActivities.trackClickAndReturnOriginal(url)` method.
    public func onesignalWidgetURL<T: OneSignalLiveActivityAttributes>(
        _ url: URL?,
        context: ActivityViewContext<T>
    ) -> DynamicIsland {
        return self.widgetURL(LiveActivityTrackingUtils.generateTrackingDeepLink(originalURL: url, context: context))
    }
}

@available(iOS 16.1, *)
extension View {
    /// Sets the URL to open in the containing app when the user clicks the widget.
    /// Sets OneSignal activity metadata. See Important callout below on usage.
    ///
    /// - Parameters:
    ///   - url: The URL to open in the containing app.
    ///   - context: The activity view context.
    /// - Returns: A view that opens the specified URL when the user clicks
    ///   the widget.
    ///
    /// Widgets support one `onesignalWidgetURL` modifier in their view hierarchy.
    /// If multiple views have `onesignalWidgetURL` modifiers, the behavior is undefined.
    ///
    /// > Important: Use instead of`.widgetURL`. Requires handling from your app's URL handling code
    /// (e.g., `application(_:open:options:)` in AppDelegate or `onOpenURL` in SwiftUI) using the
    /// `OneSignal.LiveActivities.trackClickAndReturnOriginal(url)` method.
    @MainActor @preconcurrency public func onesignalWidgetURL<T: OneSignalLiveActivityAttributes>(_ url: URL?, context: ActivityViewContext<T>) -> some View {
        return self.widgetURL(LiveActivityTrackingUtils.generateTrackingDeepLink(originalURL: url, context: context))
    }
}

// MARK: - Tracking Utilities

/// Utilities for building and managing Live Activity tracking URLs
enum LiveActivityTrackingUtils {
    /// Generates a tracking deep link from an original URL and activity context
    /// - Parameters:
    ///   - originalURL: The original URL to track clicks for
    ///   - context: The activity view context containing metadata
    /// - Returns: The tracking URL, or nil if construction failed
    @available(iOS 16.1, *)
    static func generateTrackingDeepLink<T: OneSignalLiveActivityAttributes>(originalURL: URL?, context: ActivityViewContext<T>) -> URL? {
        // Get activity metadata from context
        let activityId = context.attributes.onesignal.activityId
        let activityType = String(describing: T.self)
        let notificationId = context.state.onesignal?.notificationId

        return buildTrackingURL(
            originalURL: originalURL,
            activityId: activityId,
            activityType: activityType,
            notificationId: notificationId
        )
    }

    /// Builds a tracking URL that wraps the original URL with OneSignal tracking parameters
    /// - Parameters:
    ///   - originalURL: The original URL to track clicks for
    ///   - activityId: The activity identifier
    ///   - activityType: The activity type name
    ///   - notificationId: Optional notification ID
    /// - Returns: The tracking URL, or nil if construction failed
    static func buildTrackingURL(
        originalURL: URL?,
        activityId: String,
        activityType: String,
        notificationId: String?
    ) -> URL? {
        // Generate a unique click ID
        let clickId = UUID().uuidString

        // Build OneSignal tracking URL
        var components = URLComponents()
        components.scheme = LiveActivityConstants.Tracking.scheme
        components.host = LiveActivityConstants.Tracking.host
        components.path = LiveActivityConstants.Tracking.clickPath

        var queryItems = [
            URLQueryItem(name: LiveActivityConstants.Tracking.clickId, value: clickId),
            URLQueryItem(name: LiveActivityConstants.Tracking.activityId, value: activityId),
            URLQueryItem(name: LiveActivityConstants.Tracking.activityType, value: activityType),
            URLQueryItem(name: LiveActivityConstants.Tracking.notificationId, value: notificationId)
        ]

        if let originalURL = originalURL {
            // URLQueryItem automatically percent-encodes the value when URLComponents constructs the URL
            // This ensures special characters like &, #, ?, etc. in the redirect URL are properly encoded
            queryItems.append(URLQueryItem(name: LiveActivityConstants.Tracking.redirect, value: originalURL.absoluteString))
        }

        components.queryItems = queryItems

        return components.url
    }
}
#endif
