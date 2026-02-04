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
import OneSignalInAppMessages
import OneSignalLocation

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
        
        // Start with IAM paused
        OneSignal.InAppMessages.paused = true
    }
}

// MARK: - Notification Handlers

class NotificationLifecycleHandler: NSObject, OSNotificationLifecycleListener {
    static let shared = NotificationLifecycleHandler()
    
    func onWillDisplay(event: OSNotificationWillDisplayEvent) {
        print("[OneSignal] Notification will display: \(event.notification.title ?? "No title")")
        // Optionally modify display behavior
        // event.preventDefault() // Prevent automatic display
        // event.notification.display() // Manually display later
    }
}

class NotificationClickHandler: NSObject, OSNotificationClickListener {
    static let shared = NotificationClickHandler()
    
    func onClick(event: OSNotificationClickEvent) {
        print("[OneSignal] Notification clicked: \(event.notification.title ?? "No title")")
        // Handle notification click - navigate to specific screen, etc.
    }
}

// MARK: - In-App Message Handlers

class InAppMessageLifecycleHandler: NSObject, OSInAppMessageLifecycleListener {
    static let shared = InAppMessageLifecycleHandler()
    
    func onWillDisplay(event: OSInAppMessageWillDisplayEvent) {
        print("[OneSignal] IAM will display: \(event.message.messageId)")
    }
    
    func onDidDisplay(event: OSInAppMessageDidDisplayEvent) {
        print("[OneSignal] IAM did display: \(event.message.messageId)")
    }
    
    func onWillDismiss(event: OSInAppMessageWillDismissEvent) {
        print("[OneSignal] IAM will dismiss: \(event.message.messageId)")
    }
    
    func onDidDismiss(event: OSInAppMessageDidDismissEvent) {
        print("[OneSignal] IAM did dismiss: \(event.message.messageId)")
    }
}

class InAppMessageClickHandler: NSObject, OSInAppMessageClickListener {
    static let shared = InAppMessageClickHandler()
    
    func onClick(event: OSInAppMessageClickEvent) {
        print("[OneSignal] IAM clicked: \(event.result.actionId ?? "No action ID")")
        // Handle IAM click - navigate, track event, etc.
    }
}
