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
    
    @IBOutlet weak var textMultiLine1 : UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        
        
    }
    
    fileprivate func appDelegate() -> AppDelegate? {
        return UIApplication.shared.delegate as? AppDelegate
    }

    @IBAction func sentTags(_ sender : AnyObject) {
        
        OneSignal.sendTags(["some_key" : "some_value"], onSuccess: { (result) in
            print("success!")
            }) { (error) in
                print("Error sending tags - \(error?.localizedDescription)")
        }
    }
    
    @IBAction func getIds(_ sender : AnyObject) {
        
        OneSignal.idsAvailable { (userId, pushToken) in
            
            if pushToken != nil {
                self.textMultiLine1.text = "PlayerId:\n\(userId)\n\nPushToken:\n\(pushToken)\n"
            }
            else {
                self.textMultiLine1.text = "ERROR: Could not get a pushToken from Apple! Make sure your provisioning profile has 'Push Notifications' enabled and rebuild your app."
            }
            print(self.textMultiLine1.text)
        }
        
    }


}

