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
#import "AppDelegate.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextField *appIdTextField;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *consentSegmentedControl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *inAppMessagingSegmentedControl;
@property (weak, nonatomic) IBOutlet UITextField *addTriggerKey;
@property (weak, nonatomic) IBOutlet UITextField *addTriggerValue;
@property (weak, nonatomic) IBOutlet UITextField *removeTriggerKey;
@property (weak, nonatomic) IBOutlet UITextField *getTriggerKey;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.activityIndicatorView.hidden = true;
    
    self.consentSegmentedControl.selectedSegmentIndex = (NSInteger)![OneSignal requiresUserPrivacyConsent];
    
    self.inAppMessagingSegmentedControl.selectedSegmentIndex = (NSInteger)[OneSignal inAppMessagingEnabled];
    
    self.appIdTextField.text = [AppDelegate getOneSignalAppId];
    
    self.infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.infoLabel.numberOfLines = 0;
}

- (void)changeAnimationState:(BOOL)animating {
    animating ? [self.activityIndicatorView startAnimating] : [self.activityIndicatorView stopAnimating];
    self.activityIndicatorView.hidden = !animating;
}

- (IBAction)addTriggerAction:(id)sender {
    NSString *key = [self.addTriggerKey text];
    NSString *value = [self.addTriggerValue text];
    
    if (key && value && [key length] && [value length]) {
        [OneSignal addTrigger:key withValue:value];
    }
}

- (IBAction)removeTriggerAction:(id)sender {
    NSString *key = [self.removeTriggerKey text];
    
    if (key && [key length]) {
        [OneSignal removeTriggerForKey:key];
    }
}

- (IBAction)getTriggersAction:(id)sender {
    NSString *key = [self.getTriggerKey text];
    
    if (key && [key length]) {
        id value = [OneSignal getTriggerValueForKey:key];
        self.infoLabel.text = [NSString stringWithFormat:@"Key: %@ Value: %@", key, value];
    }
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

- (IBAction)setEmailButtonPressed:(UIButton *)sender {
    [AppDelegate setOneSignalAppId:self.appIdTextField.text];
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

- (IBAction)inAppMessagingSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller in app messaging paused: %i", (int)sender.selectedSegmentIndex);
    [OneSignal setInAppMessagingEnabled:(bool)sender.selectedSegmentIndex];
}

-(void)handleMessageAction:(NSString *)actionId {
    NSLog(@"View controller did get action: %@", actionId);
}


@end
