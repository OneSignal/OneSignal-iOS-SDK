//
//  ViewController.swift
//  OneSignalSwiftExample
//
//  Created by Joseph Kalash on 6/24/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import UIKit
import OneSignal

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    /* Sends a notification to the device itself */
    @IBAction func push(sender: AnyObject) {
        print("Sending Test Notification to this device.")
        OneSignal.postNotification(["contents": ["en": "Test Message"], "include_player_ids": [(UIApplication.sharedApplication().delegate as! AppDelegate).userid!]], onSuccess: { (results) in
            print(results)
            }, onFailure: { (error) in
                print(error.localizedDescription)
        })
    }
}
