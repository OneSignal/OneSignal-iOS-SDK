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

// Please see the root Example folder of this repo for an Example project.
// This project exisits to make testing OneSignal SDK changes.

#import "ViewController.h"

#import <OneSignal/OneSignal.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *consentSegmentedControl;
@property (weak, nonatomic) IBOutlet UITextField *externalIdTextField;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.activityIndicatorView.hidden = true;
    
    self.consentSegmentedControl.selectedSegmentIndex = (NSInteger)![OneSignal requiresUserPrivacyConsent];
    
    self.textField.delegate = self;
    self.externalIdTextField.delegate = self;
}

- (void)changeAnimationState:(BOOL)animating {
    animating ? [self.activityIndicatorView startAnimating] : [self.activityIndicatorView stopAnimating];
    self.activityIndicatorView.hidden = !animating;
}

- (IBAction)sendTagButton:(id)sender {
    //[self promptForNotificationsWithNativeiOS10Code];
    
    //[OneSignal registerForPushNotifications];
    
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        NSLog(@"NEW SDK 2.5.0 METHDO: promptForPushNotificationsWithUserResponse: %d", accepted);
    }];
    
    
    
    [OneSignal sendTag:@"key1"
                 value:@"value1"
             onSuccess:^(NSDictionary *result) {
                 static int successes = 0;
                 NSLog(@"successes: %d", ++successes);
             }
             onFailure:^(NSError *error) {
                 static int failures = 0;
                 NSLog(@"failures: %d", ++failures);
    }];
    
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        NSLog(@"IdsAvailable Fired");
    }];
    
}

- (IBAction)setEmailButtonPressed:(UIButton *)sender
{
    [self changeAnimationState:true];
    [OneSignal setEmail:self.textField.text withEmailAuthHashToken:@"aa3e3201f8f8bfd2fcbe8a899c161b7acb5a86545196c5465bef47fd757ca356" withSuccess:^{
        NSLog(@"Successfully sent email");
        dispatch_async(dispatch_get_main_queue(), ^{
            [self changeAnimationState:false];
        });
    } withFailure:^(NSError *error) {
        NSLog(@"Encountered error: %@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self changeAnimationState:false];
        });
    }];
}

- (IBAction)logoutButtonPressed:(UIButton *)sender
{
    [OneSignal logoutEmailWithSuccess:^{
        NSLog(@"Successfully logged out of email");
    } withFailure:^(NSError *error) {
        NSLog(@"Encountered error while logging out of email: %@", error);
    }];
}


- (void)promptForNotificationsWithNativeiOS10Code {
    id responseBlock = ^(BOOL granted, NSError* error) {
        NSLog(@"promptForNotificationsWithNativeiOS10Code: %d", granted);
    };
    
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound + UNAuthorizationOptionBadge)
                          completionHandler:responseBlock];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)consentSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller consent granted: %i", (int)sender.selectedSegmentIndex);
    [OneSignal consentGranted:(bool)sender.selectedSegmentIndex];
}

- (IBAction)setExternalIdButtonPressed:(UIButton *)sender {
    [OneSignal setExternalUserId:self.externalIdTextField.text];
}

- (IBAction)removeExternalIdButtonPressed:(UIButton *)sender {
    [OneSignal removeExternalUserId];
}

#pragma mark UITextFieldDelegate Methods
-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return false;
}

@end
