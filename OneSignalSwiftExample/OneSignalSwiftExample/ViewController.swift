//
//  ViewController.swift
//  OneSignalSwiftExample
//
//  Created by Kasten on 2/17/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import UIKit
import OneSignal

class ViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var allowNotificationsSwitch: UISwitch!
    @IBOutlet weak var setSubscriptionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func onRegisterForPushNotificationsButton(_ sender: UIButton) {
        
        OneSignal.registerForPushNotifications() // Call when you want to prompt the user to accept push notifications. Only call once and only if you set kOSSettingsKeyAutoPrompt in AppDelegate to false.
    }
    
    @IBAction func onSendTagsButton(_ sender: UIButton) {
        
        let tags: [AnyHashable : Any] = [
            "some_key" : "some_value",
            "another_key" : "another_value",
            "finished_game" : "true",
            "has_followers" : "false",
            "added_review" : "false"
        ]
        
        OneSignal.sendTags(tags, onSuccess: { result in
            print("Send Tags Success!")
        }) { error in
            print("Error sending tags: \(error?.localizedDescription)")
        }
    }
    
    @IBAction func onGetTagsButton(_ sender: UIButton) {
        
        OneSignal.getTags({ tags in
            print("tags - \(tags!)")
        }, onFailure: { error in
            print("Error getting tags - \(error?.localizedDescription)")
            // errorWithDomain - OneSignalError
            // code - HTTP error code from the OneSignal server
            // userInfo - JSON OneSignal responded with
        })
    }
    
    @IBAction func onDeleteOrUpdateTagsButton(_ sender: UIButton) {
        
        //OneSignal.deleteTag("some_key")
        OneSignal.deleteTags(["some_key", "another_key"])
        
        // To update tags simply add new ones
        OneSignal.sendTags(["updated_key" : "updated_value"])
    }
    
    // User IDs
    @IBAction func onGetIDsButton(_ sender: UIButton) {
        
        OneSignal.idsAvailable { userId, pushToken in
            
            if pushToken != nil {
                self.textView.text = "PlayerId:\n\(userId!)\n\nPushToken:\n\(pushToken!)\n"
            }
            else {
                self.textView.text = "Error: Could not get a pushToken from Apple! Make sure your profile has 'Push Notifications' enabled and rebuild your app."
            }
            print(self.textView.text)
        }
    }
    
    
    @IBAction func onSyncEmailButton(_ sender: UIButton) {
        
        // Optional method that sends us the user's email as an anonymized hash so that we can better target and personalize notifications sent to that user across their devices.
        let testEmail = "test@test.test"
        OneSignal.syncHashedEmail(testEmail)
        
        print("sync hashedEmail successful")
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
        
        OneSignal.idsAvailable { userId, pushToken in
            
            if pushToken != nil {
                
                let message = "This is a notification's message or body"
                
                let notificationContent = [
                    // Content & Language: https://documentation.onesignal.com/reference#section-content-language
                    "include_player_ids": [userId],
                    "contents": ["en": message], // Required unless "content_available": true or "template_id" is set
                    "headings": ["en": "Notification Title"],
                    "subtitle": ["en": "An English Subtitle"],
                    
                    // Attachments: https://documentation.onesignal.com/reference#section-attachments
                    "data": ["key1" : "value1"],
                    "url": "https://google.com",
                    "ios_attachments": ["id1" : "https://cdn.pixabay.com/photo/2017/01/16/15/17/hot-air-balloons-1984308_1280.jpg"],
                    "ios_badgeType": "Increase",
                    "ios_badgeCount": 1
                    
                    ] as [String : Any]
                
                
                OneSignal.postNotification(notificationContent)
            }
        }
    }
    
    @IBAction func onSendNotificationButton2(_ sender: UIButton) {
        
        let notifiation2Content: [AnyHashable : Any] = [
            "include_player_ids": ["42485ae8-a1c0-475d-854b-745840690548"],
            "contents": ["en": "Notification 2"], // Required unless "content_available": true or "template_id" is set
            
            // Action Buttons: https://documentation.onesignal.com/reference#section-action-buttons
            "buttons": [["id": "id1", "text": "WOW1"], ["id": "id2", "DUDE2": "button2"]]
        ]
        
        OneSignal.postNotification(notifiation2Content, onSuccess: { result in
            print("result = \(result!)")
        }, onFailure: {error in
            print("error = \(error!)")
        })
    }
    
    
    //TODO: CHANGE TO SET SUBSCRIPTION SWITCH
    @IBAction func onAllowNotificationsSwitch(_ sender: UISwitch) {
        
        // turn off notifications
        // IMPORTANT: user must have already accepted notifications for this to be called
        if !allowNotificationsSwitch.isOn {
            OneSignal.setSubscription(false)
            setSubscriptionLabel.text = "Set Subscription OFF"
        } else {
            OneSignal.setSubscription(true)
            setSubscriptionLabel.text = "Set Subscription ON"
        }
    }
    
}
