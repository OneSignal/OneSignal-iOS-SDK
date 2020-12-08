/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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


import UIKit
import OneSignal

class ViewController: UIViewController, OSPermissionObserver, OSSubscriptionObserver, OSEmailSubscriptionObserver, UITextFieldDelegate {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var allowNotificationsSwitch: UISwitch!
    @IBOutlet weak var setSubscriptionLabel: UILabel!
    @IBOutlet weak var registerForPushNotificationsButton: UIButton!
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var setEmailButton: UIButton!
    @IBOutlet weak var logoutEmailButton: UIButton!
    @IBOutlet weak var setEmailActivityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var logoutEmailActivityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var logoutEmailTrailingConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let status: OSPermissionSubscriptionState = OneSignal.getPermissionSubscriptionState()
        let isSubscribed = status.subscriptionStatus.subscribed
        
        if isSubscribed == true {
            allowNotificationsSwitch.isOn = true
            allowNotificationsSwitch.isUserInteractionEnabled = true
            registerForPushNotificationsButton.backgroundColor = UIColor.green
            registerForPushNotificationsButton.isUserInteractionEnabled = false
            setSubscriptionLabel.text = "OneSignal Push Enabled"
        }
        OneSignal.add(self as OSPermissionObserver)
        OneSignal.add(self as OSSubscriptionObserver)
        OneSignal.add(self as OSEmailSubscriptionObserver)
        
        self.emailTextField.delegate = self;
    }
    
    func displaySettingsNotification() {
        let message = NSLocalizedString("Please turn on notifications by going to Settings > Notifications > Allow Notifications", comment: "Alert message when the user has denied access to the notifications")
        let settingsAction = UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
            } else {
                // Fallback on earlier versions
            }
        });
        self.displayAlert(title: message, message: "OneSignal Example", actions: [UIAlertAction.okAction(), settingsAction]);
    }
    
    func displayError(withMessage message : String) {
        let action = UIAlertAction(title: "Ok", style: .cancel, handler: nil);
        self.displayAlert(title: "An Error Occurred", message: message, actions: [action])
    }
    
    func changeLogoutAnimationState(_ animating : Bool) {
        self.logoutEmailTrailingConstraint.constant = animating ? 36.0 : 0.0;
        if (animating) {
            self.logoutEmailActivityIndicatorView.startAnimating();
        }
        
        UIView.animate(withDuration: 0.15, animations: {
            self.view.layoutIfNeeded();
        }) { (completed) in
            if (completed && !animating) {
                self.logoutEmailActivityIndicatorView.stopAnimating();
            }
        }
    }
    
    func displayAlert(title : String, message: String, actions: [UIAlertAction]) {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert);
        actions.forEach { controller.addAction($0) };
        self.present(controller, animated: true, completion: nil);
    }
    
    func onOSPermissionChanged(_ stateChanges: OSPermissionStateChanges) {
        if stateChanges.from.status == OSNotificationPermission.notDetermined {
            if stateChanges.to.status == OSNotificationPermission.authorized {
                registerForPushNotificationsButton.backgroundColor = UIColor.green
                registerForPushNotificationsButton.isUserInteractionEnabled = false
                allowNotificationsSwitch.isUserInteractionEnabled = true
            } else if stateChanges.to.status == OSNotificationPermission.denied {
                displaySettingsNotification()
            }
        } else if stateChanges.to.status == OSNotificationPermission.denied { // DENIED = NOT SUBSCRIBED
            registerForPushNotificationsButton.isUserInteractionEnabled = true
            allowNotificationsSwitch.isUserInteractionEnabled = false
        }
    }
    
    func onOSSubscriptionChanged(_ stateChanges: OSSubscriptionStateChanges) {
        if stateChanges.from.subscribed && !stateChanges.to.subscribed { // NOT SUBSCRIBED != DENIED
            allowNotificationsSwitch.isOn = false
            setSubscriptionLabel.text = "OneSignal Push Disabled"
            registerForPushNotificationsButton.backgroundColor = UIColor.red
        } else if !stateChanges.from.subscribed && stateChanges.to.subscribed {
            allowNotificationsSwitch.isOn = true
            allowNotificationsSwitch.isUserInteractionEnabled = true
            setSubscriptionLabel.text = "OneSignal Push Enabled"
            registerForPushNotificationsButton.backgroundColor = UIColor.green
            registerForPushNotificationsButton.isUserInteractionEnabled = false
        }
    }
    
    func onOSEmailSubscriptionChanged(_ stateChanges: OSEmailSubscriptionStateChanges) {
        self.textView.text = String(data: try! JSONSerialization.data(withJSONObject: stateChanges.toDictionary(), options: .prettyPrinted), encoding: .utf8);
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        
        return true;
    }
    
    @IBAction func onRegisterForPushNotificationsButton(_ sender: UIButton) {
        let status: OSPermissionSubscriptionState = OneSignal.getPermissionSubscriptionState()
        let hasPrompted = status.permissionStatus.hasPrompted
        if hasPrompted == false {
            // Call when you want to prompt the user to accept push notifications.
            OneSignal.promptForPushNotifications(userResponse: { accepted in
                if accepted == true {
                    print("User accepted notifications: \(accepted)")
                } else {
                    print("User accepted notifications: \(accepted)")
                }
            })
        } else {
            displaySettingsNotification()
        }
    }
    
    @IBAction func onSendTagsButton(_ sender: UIButton) {
        
        let tags: [AnyHashable : Any] = [
            "some_key" : "some_value",
            "users_name" : "Jon",
            "finished_level" : "30",
            "has_followers" : "false",
            "added_review" : "false"
        ]
        
        OneSignal.sendTags(tags, onSuccess: { result in
            print("Tags sent - \(result!)")
        }) { error in
            print("Error sending tags: \(error?.localizedDescription ?? "None")")
        }
    }
    
    @IBAction func onGetTagsButton(_ sender: UIButton) {
        OneSignal.getTags({ tags in
            print("tags - \(tags!)")
            
            guard let tags = tags else {
                self.displayAlert(title: NSLocalizedString("No Tags Available", comment: "Alert message when there were no tags available for this user"), message: NSLocalizedString("There were no tags present for this device", comment: "No tags available for this user"), actions: [UIAlertAction.okAction()]);
                return;
            };
            
            if JSONSerialization.isValidJSONObject(tags), let tagsData = try? JSONSerialization.data(withJSONObject: tags, options: .prettyPrinted), let tagsString = String(data: tagsData, encoding: .utf8) {
                self.displayAlert(title: NSLocalizedString("Tags JSON", comment: "Title for displaying tags JSON"), message: tagsString, actions: [UIAlertAction.okAction()]);
            } else {
                self.displayAlert(title: NSLocalizedString("Unable to Parse Tags", comment: "Alerts the user that tags are present but unable to be parsed"), message: NSLocalizedString("Tags exist but are unable to be parsed or displayed as a string", comment: "Informs the user that the app is unable to parse tags"), actions: [UIAlertAction.okAction()]);
            }
            
        }, onFailure: { error in
            print("Error getting tags - \(error?.localizedDescription ?? "None")")
            // errorWithDomain - OneSignalError
            // code - HTTP error code from the OneSignal server
            // userInfo - JSON OneSignal responded with
        })
    }
    
    @IBAction func onDeleteOrUpdateTagsButton(_ sender: UIButton) {
        //OneSignal.deleteTag("some_key")
        OneSignal.deleteTags(["some_key", "users_name", "has_followers", "added_review"])
        // To update tags simply add new ones
        OneSignal.sendTags(["finished_level" : "60"])
    }
    
    // User IDs
    @IBAction func onGetIDsButton(_ sender: UIButton) {
        //getPermissionSubscriptionState
        let status: OSPermissionSubscriptionState = OneSignal.getPermissionSubscriptionState()
        let hasPrompted = status.permissionStatus.hasPrompted
        print("hasPrompted = \(hasPrompted)")
        let userStatus = status.permissionStatus.status
        print("userStatus = \(userStatus)")
        let isSubscribed = status.subscriptionStatus.subscribed
        print("isSubscribed = \(isSubscribed)")
        let userSubscriptionSetting = status.subscriptionStatus.userSubscriptionSetting
        print("userSubscriptionSetting = \(userSubscriptionSetting)")
        let userID = status.subscriptionStatus.userId
        print("userID = \(userID ?? "None")")
        let pushToken = status.subscriptionStatus.pushToken
        print("pushToken = \(pushToken ?? "None")")
    }
    
    @IBAction func onPromptLocationButton(_ sender: UIButton) {
        // promptLocation method
        // Prompts the user for location permissions to allow geotagging from the OneSignal dashboard. This lets you send notifications based on the device's location.
        /* add to info.plist:
         <key>NSLocationAlwaysUsageDescription</key>
         <string>Your message goes here</string>
         <key>NSLocationWhenInUseUsageDescription</key>
         <string>Your message goes here</string>
         */
        // must add core location framework for this to work. Root Project > Build Phases > Link Binary With Libraries
        OneSignal.promptLocation()
        print("OneSignal version: " + OneSignal.sdkSemanticVersion());
    }
    
    // Sending Notifications
    @IBAction func onSendNotificationButton(_ sender: UIButton) {
        // See the Create notification REST API POST call for a list of all possible options: https://documentation.onesignal.com/reference#create-notification
        // NOTE: You can only use include_player_ids as a targeting parameter from your app. Other target options such as tags and included_segments require your OneSignal App REST API key which can only be used from your server.
        let status: OSPermissionSubscriptionState = OneSignal.getPermissionSubscriptionState()
        let pushToken = status.subscriptionStatus.pushToken
        let userId = status.subscriptionStatus.userId
        
        if pushToken != nil {
            let message = "This is a notification's message or body"
            let notificationContent = [
                "include_player_ids": [userId],
                "contents": ["en": message], // Required unless "content_available": true or "template_id" is set
                "headings": ["en": "Notification Title"],
                "subtitle": ["en": "An English Subtitle"],
                // If want to open a url with in-app browser
                //"url": "https://google.com",
                // If you want to deep link and pass a URL to your webview, use "data" parameter and use the key in the AppDelegate's notificationOpenedBlock
                "data": ["OpenURL": "https://imgur.com"],
                "ios_attachments": ["id" : "https://cdn.pixabay.com/photo/2017/01/16/15/17/hot-air-balloons-1984308_1280.jpg"],
                "ios_badgeType": "Increase",
                "ios_badgeCount": 1
                ] as [String : Any]
            
            OneSignal.postNotification(notificationContent)
        }
    }
    
    @IBAction func onSendNotificationButton2(_ sender: UIButton) {
        let status: OSPermissionSubscriptionState = OneSignal.getPermissionSubscriptionState()
        let pushToken = status.subscriptionStatus.pushToken
        let userId = status.subscriptionStatus.userId
        
        if pushToken != nil {
            let notifiation2Content: [AnyHashable : Any] = [
                // Update the following id to your OneSignal plyaer / user id.
                "include_player_ids": [userId],
                // Tag substitution: https://documentation.onesignal.com/docs/tag-variable-substitution
                "headings": ["en": "Congrats {{users_name}}!!"],
                "contents": ["en": "You finished level {{ finished_level | default: '1' }}! Let's see if you can do more."],
                // Action Buttons: https://documentation.onesignal.com/reference#section-action-buttons
                "buttons": [["id": "id1", "text": "GREEN"], ["id": "id2", "text": "RED"]]
            ]
            OneSignal.postNotification(notifiation2Content, onSuccess: { result in
                print("result = \(result!)")
            }, onFailure: {error in
                print("error = \(error!)")
            })
        }
    }
    
    @IBAction func onAllowNotificationsSwitch(_ sender: UISwitch) {
        // turn off notifications
        // IMPORTANT: user must have already accepted notifications for this to be called
        if !allowNotificationsSwitch.isOn {
            OneSignal.disablePush(true)
        } else {
            OneSignal.disablePush(false)
        }
    }
    
    @IBAction func setEmailButtonPressed(_ sender: UIButton) {
        self.emailTextField.resignFirstResponder();
        
        sender.isHidden = true;
        self.setEmailActivityIndicatorView.startAnimating();
        
        OneSignal.setEmail(self.emailTextField.text ?? "", withSuccess: {
            sender.isHidden = false;
            self.setEmailActivityIndicatorView.stopAnimating();
            
        }) { (error) in
            sender.isHidden = false;
            self.setEmailActivityIndicatorView.stopAnimating();
            
            self.displayError(withMessage: "Encountered error while attempting to set email: " + (error?.localizedDescription ?? "null"));
        };
    }
    
    @IBAction func logoutEmailButtonPressed(_ sender: UIButton) {
        self.changeLogoutAnimationState(true);
        
        OneSignal.logoutEmail(success: {
            self.changeLogoutAnimationState(false);
        }) { (error) in
            self.changeLogoutAnimationState(false);
            
            self.displayError(withMessage: "Encountered error while attempting to log out of email: " + (error?.localizedDescription ?? "null"));
        };
    }
}

extension UIAlertAction {
    static func okAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil);
    }
}
