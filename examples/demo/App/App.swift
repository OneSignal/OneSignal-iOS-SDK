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
import OneSignalFramework

@main
struct App: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = OneSignalViewModel()
    @StateObject private var toastPresenter = ToastPresenter()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .environmentObject(viewModel)
                    .environmentObject(toastPresenter)
                    .tabItem { Label("Home", systemImage: "photo.on.rectangle") }
                Color.clear
                    .tabItem { Label("Library", systemImage: "square.stack.fill") }
                Color.clear
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Initialize OneSignal
        OneSignalService.shared.initialize(launchOptions: launchOptions)

        // Set up notification lifecycle listeners
        setupNotificationListeners()

        // Set up in-app message listeners
        setupInAppMessageListeners()

        // Set up Live Activities (iOS 16.1+)
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 16.1, *) {
            LiveActivityController.setup()
        }
        #endif

        return true
    }

    private func setupNotificationListeners() {
        // Foreground notification display
        OneSignal.Notifications.addForegroundLifecycleListener(NotificationLifecycleHandler.shared)

        // Notification click handling
        OneSignal.Notifications.addClickListener(NotificationClickHandler.shared)
    }

    private func setupInAppMessageListeners() {
        // In-app message lifecycle
        OneSignal.InAppMessages.addLifecycleListener(InAppMessageLifecycleHandler.shared)

        // In-app message click handling
        OneSignal.InAppMessages.addClickListener(InAppMessageClickHandler.shared)
    }
}

// MARK: - Notification Handlers

class NotificationLifecycleHandler: NSObject, OSNotificationLifecycleListener {
    static let shared = NotificationLifecycleHandler()

    func onWillDisplay(event: OSNotificationWillDisplayEvent) {
        let notification = event.notification
        LogService.show(
            "Notification foregroundWillDisplay: \(notification.notificationId ?? "null") \(notification.title ?? "")"
        )
        // Optionally modify display behavior
        // event.preventDefault() // Prevent automatic display
        // event.notification.display() // Manually display later
    }
}

class NotificationClickHandler: NSObject, OSNotificationClickListener {
    static let shared = NotificationClickHandler()

    func onClick(event: OSNotificationClickEvent) {
        let notification = event.notification
        LogService.show(
            "Notification click: \(notification.notificationId ?? "null") \(notification.title ?? "")"
        )
    }
}

// MARK: - In-App Message Handlers

class InAppMessageLifecycleHandler: NSObject, OSInAppMessageLifecycleListener {
    static let shared = InAppMessageLifecycleHandler()

    func onWillDisplay(event: OSInAppMessageWillDisplayEvent) {
        LogService.show("IAM willDisplay: \(event.message.messageId)")
    }

    func onDidDisplay(event: OSInAppMessageDidDisplayEvent) {
        LogService.show("IAM didDisplay: \(event.message.messageId)")
    }

    func onWillDismiss(event: OSInAppMessageWillDismissEvent) {
        LogService.show("IAM willDismiss: \(event.message.messageId)")
    }

    func onDidDismiss(event: OSInAppMessageDidDismissEvent) {
        LogService.show("IAM didDismiss: \(event.message.messageId)")
    }
}

class InAppMessageClickHandler: NSObject, OSInAppMessageClickListener {
    static let shared = InAppMessageClickHandler()

    func onClick(event: OSInAppMessageClickEvent) {
        LogService.show("IAM click: \(event.message.messageId)")
    }
}
