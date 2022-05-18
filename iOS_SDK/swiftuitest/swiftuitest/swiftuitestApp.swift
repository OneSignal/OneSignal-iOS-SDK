//
//  swiftuitestApp.swift
//  swiftuitest
//
//  Created by Elliot Mawby on 5/18/22.
//

import SwiftUI
import OneSignal

@main
struct swiftuitestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegateTest.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegateTest: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
           // Remove this method to stop OneSignal Debugging
        OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE)
        OneSignal.sendTag("name", value: "elliot")
        OneSignal.initWithLaunchOptions(launchOptions)
        OneSignal.setAppId("77e32082-ea27-42e3-a898-c72e141824ef")

        OneSignal.promptForPushNotifications(userResponse: { accepted in
         print("User accepted notification: \(accepted)")
        })

        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("ecm swizzle test didregister")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("ecm swizzle test didReceive")
    }
}
