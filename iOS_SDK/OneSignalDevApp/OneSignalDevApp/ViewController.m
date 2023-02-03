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
#import "OneSignalExample-Swift.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.activityIndicatorView.hidden = true;
    
    self.consentSegmentedControl.selectedSegmentIndex = (NSInteger) ![OneSignal requiresPrivacyConsent];

    self.subscriptionSegmentedControl.selectedSegmentIndex = (NSInteger) OneSignal.User.pushSubscription.optedIn;
    
    self.locationSharedSegementedControl.selectedSegmentIndex = (NSInteger) [OneSignal.Location isShared];
    
    self.inAppMessagingSegmentedControl.selectedSegmentIndex = (NSInteger) ![OneSignal.InAppMessages paused];

    self.appIdTextField.text = [AppDelegate getOneSignalAppId];

    self.infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.infoLabel.numberOfLines = 0;
}

- (void)changeAnimationState:(BOOL)animating {
    animating ? [self.activityIndicatorView startAnimating] : [self.activityIndicatorView stopAnimating];
    self.activityIndicatorView.hidden = !animating;
}

- (IBAction)updateAppId:(id)sender {
    // [AppDelegate setOneSignalAppId:self.appIdTextField.text];
    NSLog(@"Dev App: Not a feature, can't change app id, no op!");
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
    NSLog(@"Dev App: add email: %@", email);
    [OneSignal.User addEmail:email];
}

- (IBAction)removeEmailButton:(id)sender {
    NSString *email = self.emailTextField.text;
    NSLog(@"Dev App: Removing email: %@", email);
    [OneSignal.User removeEmail:email];
}

- (IBAction)addSmsButton:(id)sender {
    NSString *sms = self.smsTextField.text;
    NSLog(@"Dev App: Add sms: %@", sms);
    [OneSignal.User addSms:sms];
}

- (IBAction)removeSmsButton:(id)sender {
    NSString *sms = self.smsTextField.text;
    NSLog(@"Dev App: Removing sms: %@", sms);
    [OneSignal.User removeSms:sms];
}

- (IBAction)addAliasButton:(UIButton *)sender {
    NSString* label = self.addAliasLabelTextField.text;
    NSString* id = self.addAliasIdTextField.text;
    NSLog(@"Dev App: Add alias with label %@ and ID %@", label, id);
    [OneSignal.User addAliasWithLabel:label id:id];
}

- (IBAction)removeAliasButton:(UIButton *)sender {
    NSString* label = self.removeAliasLabelTextField.text;
    NSLog(@"Dev App: Removing alias with label %@", label);
    [OneSignal.User removeAlias:label];
}

- (IBAction)sendTagButton:(id)sender {
    if (self.tagKey.text && self.tagKey.text.length
        && self.tagValue.text && self.tagValue.text.length) {
        NSLog(@"Sending tag with key: %@ value: %@", self.tagKey.text, self.tagValue.text);
        [OneSignal.User addTagWithKey:self.tagKey.text value:self.tagValue.text];
    }
}

- (IBAction)getInfoButton:(id)sender {
    NSLog(@"💛 Dev App: get User and Device information");
    [OneSignalUserManagerImpl.sharedInstance internalDumpInfo];
    NSLog(@"💛 Dev App: OneSignal.Notifications permission: %d", [OneSignal.Notifications permission]);
    NSLog(@"💛 Dev App: OneSignal.Notifications.canRequestPermission: %d", [OneSignal.Notifications canRequestPermission]);
    [OneSignal internalDumpInfo];
    NSLog(@"💛 Dev App: getPrivacyConsent: %d", OneSignal.getPrivacyConsent);
    NSLog(@"💛 Dev App: requiresPrivacyConsent: %d", [OneSignal requiresPrivacyConsent]);
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
    [OneSignal setPrivacyConsent:(bool) sender.selectedSegmentIndex];
}

- (IBAction)subscriptionSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller subscription status: %i", (int) sender.selectedSegmentIndex);
    if (sender.selectedSegmentIndex) {
        [OneSignal.User.pushSubscription optIn];
    } else {
        [OneSignal.User.pushSubscription optOut];
    }
    sender.selectedSegmentIndex = (NSInteger) OneSignal.User.pushSubscription.optedIn;

}

- (IBAction)locationSharedSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller location sharing status: %i", (int) sender.selectedSegmentIndex);
    [OneSignal.Location setShared:(bool) sender.selectedSegmentIndex];
}

- (IBAction)inAppMessagingSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller in app messaging paused: %i", (int) !sender.selectedSegmentIndex);
    [OneSignal.InAppMessages paused:(bool) !sender.selectedSegmentIndex];
}

- (void)handleMessageAction:(NSString *)actionId {
    NSLog(@"View controller did get action: %@", actionId);
}

- (IBAction)loginExternalUserId:(UIButton *)sender {
    NSString* externalUserId = self.externalUserIdTextField.text;
    NSLog(@"Dev App: Logging in to external user ID %@", externalUserId);
    [OneSignal login:externalUserId];
}

- (IBAction)logout:(UIButton *)sender {
    NSLog(@"Dev App: Logout called.");
    [OneSignal logout];
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

- (IBAction)startAndEnterLiveActivity:(id)sender {
    if (@available(iOS 13.0, *)) {
        NSString *activityId = [self.activityId text];
        // Will not make a live activity if activityId is empty
        if (activityId && activityId.length) {
            [LiveActivityController createActivityWithCompletionHandler:^(NSString * token) {
                if(token){
                    [OneSignal enterLiveActivity:activityId withToken:token];
                }
            }];
        }
    } else {
        NSLog(@"Must use iOS 13 or later for swift concurrency which is required for [LiveActivityController createActivityWithCompletionHandler...");
    }
}
- (IBAction)exitLiveActivity:(id)sender {
    if (self.activityId.text && self.activityId.text.length) {
        [OneSignal exitLiveActivity:self.activityId.text];
    }
}

- (IBAction)setLanguage:(id)sender {
    NSLog(@"Dev App: set language called.");
    NSString *language = self.languageTextField.text;
    [OneSignal.User setLanguage:language];
}

- (IBAction)clearAllNotifications:(id)sender {
    NSLog(@"Dev App: clear All Notifications called.");
    [OneSignal.Notifications clearAll];
}

- (IBAction)requireConsent:(id)sender {
    NSLog(@"Dev App: setting setRequiresPrivacyConsent to true.");
    [OneSignal setRequiresPrivacyConsent:true];
}

- (IBAction)dontRequireConsent:(id)sender {
    NSLog(@"Dev App: setting setRequiresPrivacyConsent to false.");
    [OneSignal setRequiresPrivacyConsent:false];
}

@end
