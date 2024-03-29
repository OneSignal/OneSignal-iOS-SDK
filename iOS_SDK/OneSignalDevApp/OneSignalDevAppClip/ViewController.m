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

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.activityIndicatorView.hidden = true;
    
    // self.subscriptionSegmentedControl.selectedSegmentIndex = (NSInteger) OneSignal.getDeviceState.isSubscribed;
    
    self.locationSharedSegementedControl.selectedSegmentIndex = (NSInteger) [OneSignal.Location isShared];
    
    self.inAppMessagingSegmentedControl.selectedSegmentIndex = (NSInteger) ![OneSignal.InAppMessages paused];

    self.appIdTextField.text = [AppDelegate getOneSignalAppId];

    self.infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.infoLabel.numberOfLines = 0;
}

- (IBAction)updateAppId:(id)sender {
    [AppDelegate setOneSignalAppId:self.appIdTextField.text];
}

- (IBAction)addTriggerAction:(id)sender {
    NSString *key = [self.addTriggerKey text];
    NSString *value = [self.addTriggerValue text];

    if (key && value && [key length] && [value length]) {
        [OneSignal.InAppMessages addTrigger:key withValue:value];
    }
}

- (IBAction)removeTriggerAction:(id)sender {
    NSString *key = [self.removeTriggerKey text];

    if (key && [key length]) {
        [OneSignal.InAppMessages removeTrigger:key];
    }
}

- (IBAction)getTriggersAction:(id)sender {
    NSLog(@"Getting triggers no longer supported");
}

- (IBAction)addEmailButton:(id)sender {
    NSString *email = self.emailTextField.text;
    NSLog(@"Dev App Clip: Adding email: %@", email);
    [OneSignal.User addEmail:email];
}

- (IBAction)removeEmailButton:(id)sender {
    NSString *email = self.emailTextField.text;
    NSLog(@"Dev App Clip: Removing email: %@", email);
    [OneSignal.User removeEmail:email];
}

- (IBAction)getTagsButton:(id)sender {
    NSDictionary<NSString *, NSString*> *tags = [OneSignal.User getTags];
    NSLog(@"Tags: %@", tags);
}

- (IBAction)sendTagsButton:(id)sender {
    NSLog(@"Sending tags %@", @{@"key1": @"value1", @"key2": @"value2"});
    [OneSignal.User addTags:@{@"key1": @"value1", @"key2": @"value2"}];
}

- (IBAction)promptPushAction:(UIButton *)sender {
    // This was already commented out pre-5.0.0
    //    [self promptForNotificationsWithNativeiOS10Code];
    [OneSignal.Notifications requestPermission:^(BOOL accepted) {
        NSLog(@"OneSignal Demo App requestPermission: %d", accepted);
    }];
}

- (IBAction)promptLocationAction:(UIButton *)sender {
    [OneSignal.Location requestPermission];
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
    NSLog(@"View controller consent granted: %i", (int) sender.selectedSegmentIndex);
    [OneSignal setConsentGiven:(bool) sender.selectedSegmentIndex];
}

- (IBAction)subscriptionSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller subscription status: %i", (int) sender.selectedSegmentIndex);
    // [OneSignal disablePush:(bool) !sender.selectedSegmentIndex];
}

- (IBAction)locationSharedSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller location sharing status: %i", (int) sender.selectedSegmentIndex);
    [OneSignal.Location setShared:(bool) sender.selectedSegmentIndex];
}

- (IBAction)inAppMessagingSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller in app messaging paused: %i", (int) !sender.selectedSegmentIndex);
    [OneSignal.InAppMessages paused:(bool) !sender.selectedSegmentIndex];
}

- (IBAction)loginExternalUserId:(UIButton *)sender {
    NSLog(@"setExternalUserId is no longer supported. Please use login or addAlias.");
    // TODO: Update
}

- (IBAction)logout:(UIButton *)sender {
    NSLog(@"removeExternalUserId is no longer supported. Please use logout or removeAlias.");
    // TODO: Update
}

#pragma mark UITextFieldDelegate Methods
-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return false;
}

- (IBAction)sendTestOutcomeEvent:(UIButton *)sender {
    NSLog(@"adding Outcome: %@", [_outcomeName text]);
    [OneSignal.Session addOutcome:[_outcomeName text]];
}

- (IBAction)sendValueOutcomeEvent:(id)sender {
    if ([_outcomeValue text]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        NSNumber *value = [formatter numberFromString:[_outcomeValue text]];
        
        NSLog(@"adding Outcome with name: %@ value: %@", [_outcomeValueName text], value);
        [OneSignal.Session addOutcomeWithValue:[_outcomeValueName text] value:value];
    }
}

- (IBAction)sendUniqueOutcomeEvent:(id)sender {
    NSLog(@"adding unique Outcome: %@", [_outcomeUniqueName text]);
    [OneSignal.Session addUniqueOutcome:[_outcomeUniqueName text]];
}

@end
