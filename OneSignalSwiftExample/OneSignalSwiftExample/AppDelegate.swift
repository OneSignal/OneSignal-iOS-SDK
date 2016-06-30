import UIKit
import OneSignal

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var userid : NSString? = nil

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        OneSignal.setLogLevel(.ONE_S_LL_VERBOSE, visualLevel: .ONE_S_LL_NONE)
        OneSignal.initWithLaunchOptions(launchOptions, appId: "9df877a0-ceed-4a6f-8237-a62364d3babf")
        OneSignal.enableInAppAlertNotification(true)
        
        OneSignal.IdsAvailable { (userid, token) in
            if token != nil { self.userid = userid }
        }
        
        return true
    }
}

