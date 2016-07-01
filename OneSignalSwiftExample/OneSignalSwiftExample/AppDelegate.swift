import UIKit
import OneSignal

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var userid : NSString? = nil

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        OneSignal.setLogLevel(.VERBOSE, visualLevel: .NONE)
        OneSignal.initWithLaunchOptions(launchOptions, appId: "9df877a0-ceed-4a6f-8237-a62364d3babf")
        OneSignal.enableInAppAlertNotification(true)
        
        return true
    }
}

