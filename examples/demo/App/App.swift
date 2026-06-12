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
import OneSignalLiveActivities

@main
struct App: SwiftUI.App {
    @StateObject private var viewModel = OneSignalViewModel()
    @StateObject private var toastPresenter = ToastPresenter()

    // REPRO SDK-4757: pure SwiftUI lifecycle (no AppDelegate), initialize in App.init()
    // like the reporter's app. Revert to the @UIApplicationDelegateAdaptor version after.
    init() {
        let sharedApp = UIApplication
            .perform(NSSelectorFromString("sharedApplication"))?
            .takeUnretainedValue() as? UIApplication
        if let app = sharedApp {
            print("[SDK-4757 REPRO] App.init — sharedApplication exists, isProtectedDataAvailable=\(app.isProtectedDataAvailable)")
        } else {
            print("[SDK-4757 REPRO] App.init — UIApplication.sharedApplication is NIL (UIApplicationMain not called yet)")
        }
        OneSignalService.shared.initialize(launchOptions: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(toastPresenter)
        }
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
