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

class ViewController: UIViewController, OSPermissionObserver, OSSubscriptionObserver {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var allowNotificationsSwitch: UISwitch!
    @IBOutlet weak var setSubscriptionLabel: UILabel!
    @IBOutlet weak var registerForPushNotificationsButton: UIButton!
    @IBOutlet weak var setEmailButton: UIButton!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var setEmailActivityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var logoutEmailButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        OneSignal.setLogLevel(.LL_VERBOSE, visualLevel: .LL_NONE);
        
        let status: OSPermissionSubscriptionState = OneSignal.getPermissionSubscriptionState()
        let isSubscribed = status.subscriptionStatus.subscribed
        
        if isSubscribed == true {
            allowNotificationsSwitch.isOn = true
            allowNotificationsSwitch.isUserInteractionEnabled = true
            registerForPushNotificationsButton.backgroundColor = UIColor.green
            registerForPushNotificationsButton.isUserInteractionEnabled = false 
        }
        OneSignal.add(self as OSPermissionObserver)
        OneSignal.add(self as OSSubscriptionObserver)
        
        self.emailTextField.delegate = self;
    }
    
    func displayMessageToUser(_ title : String, _ message : String, actions : [UIAlertAction]?=nil) {
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        for action in actions ?? [UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)] {
            alertController.addAction(action);
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func displaySettingsNotification() {
        var actions = [UIAlertAction]();
        
        actions.append(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil));
        actions.append(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
            } else {
                // Fallback on earlier versions
            }
        }));
        
        self.displayMessageToUser(NSLocalizedString("OneSignal Example", comment: "title for the alert"), NSLocalizedString("Please turn on notifications by going to Settings > Notifications > Allow Notifications", comment: "Alert message when the user has denied access to the notifications"), actions: actions);
    }
    
    func changeEmailAnimationState(_ animating : Bool) {
        UIView.animate(withDuration: 0.14) {
            self.setEmailButton.alpha = animating ? 0.0 : 1.0;
        };
        
        self.setEmailButton.isEnabled = !animating;
        self.setEmailButton.adjustsImageWhenDisabled = false;
        animating ? self.setEmailActivityIndicatorView.startAnimating() : self.setEmailActivityIndicatorView.stopAnimating();
    }
    
    func setEmail() {
        self.emailTextField.resignFirstResponder();
        
        guard let emailAddress = self.emailTextField.text else { return };
        
        self.changeEmailAnimationState(true);
        
        OneSignal.setUnauthenticatedEmail(emailAddress, withSuccess: {
            self.changeEmailAnimationState(false);
            
            print("Successfully set email");
            
            self.logoutEmailButton.isEnabled = true;
        }) { (error) in
            self.changeEmailAnimationState(false);
            
            self.displayMessageToUser(NSLocalizedString("An Error Occurred", comment: "Title alerting the user that an error occurred"), NSLocalizedString("Encountered the following error while attempting to set unauthenticated email:\n\n\(error.debugDescription)", comment: "Shows the error to the user"));
        };
    }
    
    func onOSPermissionChanged(_ stateChanges: OSPermissionStateChanges!) {
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
    
    func onOSSubscriptionChanged(_ stateChanges: OSSubscriptionStateChanges!) {
        
        
        if stateChanges.from.subscribed && !stateChanges.to.subscribed { // NOT SUBSCRIBED != DENIED
            allowNotificationsSwitch.isOn = false
            setSubscriptionLabel.text = "Set Subscription OFF"
            registerForPushNotificationsButton.backgroundColor = UIColor.red
        } else if !stateChanges.from.subscribed && stateChanges.to.subscribed {
            allowNotificationsSwitch.isOn = true
            allowNotificationsSwitch.isUserInteractionEnabled = true
            setSubscriptionLabel.text = "Set Subscription ON"
            registerForPushNotificationsButton.backgroundColor = UIColor.green
            registerForPushNotificationsButton.isUserInteractionEnabled = false 
        }
        
        self.logoutEmailButton.isEnabled = stateChanges.to.emailUserId != nil;
    }
    
    @IBAction func onRegisterForPushNotificationsButton(_ sender: UIButton) {
        let status: OSPermissionSubscriptionState = OneSignal.getPermissionSubscriptionState()
        let hasPrompted = status.permissionStatus.hasPrompted
        if hasPrompted == false {
            // Call when you want to prompt the user to accept push notifications.
            // Only call once and only if you set kOSSettingsKeyAutoPrompt in AppDelegate to false.
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
        }, onFailure: { error in
            print("Error getting tags - \(error?.localizedDescription ?? "None")")
            // errorWithDomain - OneSignalError
            // code - HTTP error code from the OneSignal server
            // userInfo - JSON OneSignal responded with
        })
    }
    
    
    @IBAction func setEmailButtonPressed(_ sender : UIButton) {
        // NOTE: Because of implementation details, a call to setEmail() or setUnauthenticatedEmail() can sometimes take 30 seconds or more.
        
        // OneSignal now has the ability to send emails to your users
        // There are two methods to do so. Authenticated and Unauthenticated
        // We heavily recommend taking the time to use authenticated setEmail with your backend
        
        self.setEmail();
    }
    
    @IBAction func logoutEmailButtonPressed(_ sender: UIButton) {
        OneSignal.logoutEmail(success: {
            print("Successfully logged out of email");
        }) { (error) in
            self.displayMessageToUser(NSLocalizedString("An Error Occurred", comment: "Title to show that an error occurred"), NSLocalizedString("An error occurred while attempting to log out of the email for this device:\n\n\(error.debugDescription)", comment: "Displays the error that occurred"));
        };
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
        let emailId = status.subscriptionStatus.emailUserId;
        print("Email userID = \(emailId ?? "None")");
    }
    
    @IBAction func onSyncEmailButton(_ sender: UIButton) {
        // Optional method that sends us the user's email as an anonymized hash so that we can better target and personalize notifications sent to that user across their devices.
        
        if let email = self.emailTextField.text, email.isEmpty == false {
            OneSignal.syncHashedEmail(email)
            print("sync hashedEmail successful")
        } else {
            self.displayMessageToUser(NSLocalizedString("No Email Exists", comment: "Explains that no email is currently set"), NSLocalizedString("You must fill out the email address in the text field before syncing it.", comment: "Explains that no email is currently set in the text field"));
        }
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
            OneSignal.setSubscription(false)
        } else {
            OneSignal.setSubscription(true)
        }
    }
}

extension ViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        
        if (textField.text?.count ?? 0 > 0) {
            self.setEmail();
        }
        
        return true;
    }
}
