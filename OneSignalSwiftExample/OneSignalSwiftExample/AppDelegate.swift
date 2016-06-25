import UIKit
import OneSignalSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
//        //OneSignal
//        
//        //let oneSignal = OneSignal(launchOptions: launchOptions, appId: "b2f7f966-d8cc-11e4-bed1-df8f05be55ba", handleNotification: nil)
//        OneSignal.defaultClient.ena (inAppAlertNotification: true)
//        
//        oneSignal?.IdsAvailable({ (userId, pushToken) in
//            NSLog("UserId:%@", userId);
//            if (pushToken != nil) {
//                NSLog("Sending Test Noification to this device now");
//                oneSignal.postNotification(["contents": ["en": "Test Message"], "include_player_ids": [userId]]);
//            }
//        });
//        
        return true
    }
}

