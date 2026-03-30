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

import SwiftUI
import UserNotifications
import OneSignalFramework

@main
struct OneSignalSwiftUIExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = OneSignalViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private let cachedIAMPausedKey = "CachedInAppMessagesPaused"
    private let cachedLocationSharedKey = "CachedLocationShared"
    private let cachedConsentRequiredKey = "CachedConsentRequired"
    private let cachedPrivacyConsentKey = "CachedPrivacyConsent"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        let consentRequired = UserDefaults.standard.bool(forKey: cachedConsentRequiredKey)
        let privacyConsent = UserDefaults.standard.bool(forKey: cachedPrivacyConsentKey)
        OneSignal.setConsentRequired(consentRequired)
        OneSignal.setConsentGiven(privacyConsent)

        OneSignalService.shared.initialize(launchOptions: launchOptions)

        restoreCachedStates()
        setupNotificationListeners()
        setupInAppMessageListeners()
        setupLogListener()
        TooltipService.shared.initialize()

        return true
    }

    // MARK: - Manual Push Integration (for swizzle-disabled setups)

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        OneSignal.Notifications.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        OneSignal.Notifications.didFailToRegisterForRemoteNotifications(error: error as NSError)
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        OneSignal.Notifications.didReceiveRemoteNotification(
            userInfo: userInfo, completionHandler: completionHandler)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        OneSignal.Notifications.willPresentNotification(
            payload: notification.request.content.userInfo) { notif in
                if notif != nil {
                    if #available(iOS 14.0, *) {
                        completionHandler([.banner, .list, .sound])
                    } else {
                        completionHandler([.alert, .sound])
                    }
                } else {
                    completionHandler([])
                }
            }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        OneSignal.Notifications.didReceiveNotificationResponse(response)
        completionHandler()
    }

    // MARK: - Private Setup

    private func setupLogListener() {
        OneSignal.Debug.setLogLevel(.LL_VERBOSE)
        OneSignal.Debug.addLogListener(SDKLogListener.shared)
    }

    private func restoreCachedStates() {
        let iamPaused = UserDefaults.standard.object(forKey: cachedIAMPausedKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: cachedIAMPausedKey)
        OneSignal.InAppMessages.paused = iamPaused

        let locationShared = UserDefaults.standard.bool(forKey: cachedLocationSharedKey)
        OneSignal.Location.isShared = locationShared
    }

    private func setupNotificationListeners() {
        OneSignal.Notifications.addForegroundLifecycleListener(NotificationLifecycleHandler.shared)
        OneSignal.Notifications.addClickListener(NotificationClickHandler.shared)
    }

    private func setupInAppMessageListeners() {
        OneSignal.InAppMessages.addLifecycleListener(InAppMessageLifecycleHandler.shared)
        OneSignal.InAppMessages.addClickListener(InAppMessageClickHandler.shared)
    }
}

// MARK: - Notification Handlers

class NotificationLifecycleHandler: NSObject, OSNotificationLifecycleListener {
    static let shared = NotificationLifecycleHandler()

    func onWillDisplay(event: OSNotificationWillDisplayEvent) {
        Task { @MainActor in
            LogManager.shared.i("Notification", "Will display: \(event.notification.title ?? "No title")")
        }
    }
}

class NotificationClickHandler: NSObject, OSNotificationClickListener {
    static let shared = NotificationClickHandler()

    func onClick(event: OSNotificationClickEvent) {
        Task { @MainActor in
            LogManager.shared.i("Notification", "Clicked: \(event.notification.title ?? "No title")")
        }
    }
}

// MARK: - In-App Message Handlers

class InAppMessageLifecycleHandler: NSObject, OSInAppMessageLifecycleListener {
    static let shared = InAppMessageLifecycleHandler()

    func onWillDisplay(event: OSInAppMessageWillDisplayEvent) {
        Task { @MainActor in
            LogManager.shared.i("IAM", "Will display: \(event.message.messageId)")
        }
    }

    func onDidDisplay(event: OSInAppMessageDidDisplayEvent) {
        Task { @MainActor in
            LogManager.shared.i("IAM", "Did display: \(event.message.messageId)")
        }
    }

    func onWillDismiss(event: OSInAppMessageWillDismissEvent) {
        Task { @MainActor in
            LogManager.shared.i("IAM", "Will dismiss: \(event.message.messageId)")
        }
    }

    func onDidDismiss(event: OSInAppMessageDidDismissEvent) {
        Task { @MainActor in
            LogManager.shared.i("IAM", "Did dismiss: \(event.message.messageId)")
        }
    }
}

class InAppMessageClickHandler: NSObject, OSInAppMessageClickListener {
    static let shared = InAppMessageClickHandler()

    func onClick(event: OSInAppMessageClickEvent) {
        Task { @MainActor in
            LogManager.shared.i("IAM", "Clicked: \(event.result.actionId ?? "No action ID")")
        }
    }
}

// MARK: - SDK Log Listener

class SDKLogListener: NSObject, OSLogListener {
    static let shared = SDKLogListener()

    func onLogEvent(_ event: OneSignalLogEvent) {
        let level: LogLevel
        switch event.level {
        case .LL_FATAL, .LL_ERROR: level = .error
        case .LL_WARN: level = .warning
        case .LL_INFO: level = .info
        default: level = .debug
        }
        Task { @MainActor in
            LogManager.shared.log("SDK", event.entry, level: level)
        }
    }
}
