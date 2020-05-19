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

@interface ViewController ()<UITableViewDataSource,UITableViewDelegate> {
    NSMutableArray *data1;
    NSMutableArray *data2;
}
@property (weak, nonatomic) IBOutlet UITableView *dataTableView1;
@property (weak, nonatomic) IBOutlet UITableView *dataTableView2;
@end

@implementation ViewController

// START DEMO APP SETUP IAM BUG BASH
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    int size = 0;
    if ([tableView isEqual:_dataTableView1]) {
        size = data1.count;
    } else if ([tableView isEqual:_dataTableView2]) {
        size = data2.count;
    }
    
    return size;
}

- (UITableViewCell *)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView isEqual:_dataTableView1]) {
        static NSString *cellId = @"cell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
         
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        }
        
        cell.textLabel.text = [data1 objectAtIndex:indexPath.row];
        
        return cell;
    } else if ([tableView isEqual:_dataTableView2]) {
        static NSString *cellId = @"cell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
         
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        }
        
        cell.textLabel.text = [data2 objectAtIndex:indexPath.row];
        
        return cell;
    }
    
    return [UITableViewCell new];
}

- (void)setupData {
    data1 = [NSMutableArray new];
    data2 = [NSMutableArray new];
    
    [self startOutcomeIdUpdater];
}

- (IBAction)attachIAMV2Params:(id)sender {
    NSDictionary* params =
    @{
        @"tags" : self.iamV2Tags.text,
        @"outcomes" : self.iamV2Outcomes.text,
    };
    
    [OneSignal setIAMV2Params:params];
    
    [OneSignal pauseInAppMessages:false];
}

- (void)startOutcomeIdUpdater {
    // NSTimer calling updateOutcomeIds, every 1 second
    [NSTimer scheduledTimerWithTimeInterval:1.0f
                                     target:self
                                   selector:@selector(updateOutcomeIds:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)updateOutcomeIds:(NSTimer *)timer {
    NSDictionary* data = [OneSignal getOutcomeIds];
    
    NSArray *directNotifId = data[@"direct_notif_id"];
    NSArray *indirectNotifIds = data[@"indirect_notif_id"];
    NSArray *directIamId = data[@"direct_iam_id"];
    NSArray *indirectIamIds = data[@"indirect_iam_id"];
    
    NSString *notifTitle = @"Unattributed or Disabled";
    if (directNotifId.count > 0) {
        data1 = [NSMutableArray arrayWithArray:directNotifId];
        notifTitle = [NSString stringWithFormat:@"Direct Notification Id: %lu", data1.count];
    } else if (indirectNotifIds.count > 0) {
        data1 = [NSMutableArray arrayWithArray:indirectNotifIds];
        notifTitle = [NSString stringWithFormat:@"Indirect Notification Ids: %lu", data1.count];
    }
    
    NSString *iamTitle = @"Unattributed or Disabled";
    if (directIamId.count > 0) {
        data2 = [NSMutableArray arrayWithArray:directIamId];
        iamTitle = [NSString stringWithFormat:@"Direct In-App Message Id: %lu", data2.count];
    } else if (indirectIamIds.count > 0) {
        data2 = [NSMutableArray arrayWithArray:indirectIamIds];
        iamTitle = [NSString stringWithFormat:@"Indirect In-App Message Ids: %lu", data2.count];
    }
    
    self.notificationIdTrackingTitle.text = notifTitle;
    self.iamIdTrackingTitle.text = iamTitle;
    
    [_dataTableView1 reloadData];
    [_dataTableView2 reloadData];
}
// END DEMO APP SETUP IAM BUG BASH

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.activityIndicatorView.hidden = true;
    
    self.consentSegmentedControl.selectedSegmentIndex = (NSInteger) ![OneSignal requiresUserPrivacyConsent];

    self.subscriptionSegmentedControl.selectedSegmentIndex = (NSInteger) OneSignal.getPermissionSubscriptionState.subscriptionStatus.subscribed;
    
    self.locationSharedSegementedControl.selectedSegmentIndex = (NSInteger) OneSignal.isLocationShared;
    
    self.inAppMessagingSegmentedControl.selectedSegmentIndex = (NSInteger) ![OneSignal isInAppMessagingPaused];

    self.appIdTextField.text = [AppDelegate getOneSignalAppId];

    self.infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.infoLabel.numberOfLines = 0;
    
    [self setupData];
    
    [self.iamV2ProgressSpinner setHidesWhenStopped:true];
    [OneSignal setCompletionHandler:^() {
        [self.iamV2ProgressSpinner stopAnimating];
    }];
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

- (IBAction)setEmailButton:(id)sender {
    NSString *email = self.emailTextField.text;
    [OneSignal setEmail:email withSuccess:^{
        NSLog(@"Set email successful with email: %@", email);
    } withFailure:^(NSError *error) {
        NSLog(@"Set email failed with code: %@ and message: %@", @(error.code), error.description);
    }];
}

- (IBAction)logoutEmailButton:(id)sender {
    [OneSignal logoutEmailWithSuccess:^{
        NSLog(@"Email logout successful");
    } withFailure:^(NSError *error) {
        NSLog(@"Error logging out email with code: %@ and message: %@", @(error.code), error.description);
    }];
}

- (IBAction)getTagsButton:(id)sender {
    [OneSignal IdsAvailable:^(NSString *userId, NSString *pushToken) {
        NSLog(@"IdsAvailable userId: %@, and pushToken: %@", userId, pushToken);
    }];
    
    [OneSignal getTags:^(NSDictionary *result) {
        NSLog(@"Tags: %@", result.description);
    }];
}

- (IBAction)sendTagButton:(id)sender {
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
}

- (IBAction)promptPushAction:(UIButton *)sender {
    //    [self promptForNotificationsWithNativeiOS10Code];
    //    [OneSignal registerForPushNotifications];
    [OneSignal promptForPushNotificationsWithUserResponse:^(BOOL accepted) {
        NSLog(@"OneSignal Demo App promptForPushNotificationsWithUserResponse: %d", accepted);
    }];
}

- (IBAction)promptLocationAction:(UIButton *)sender {
    [OneSignal promptLocation];
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
    [OneSignal consentGranted:(bool) sender.selectedSegmentIndex];
}

- (IBAction)subscriptionSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller subscription status: %i", (int) sender.selectedSegmentIndex);
    [OneSignal setSubscription:(bool) sender.selectedSegmentIndex];
}

- (IBAction)locationSharedSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller location sharing status: %i", (int) sender.selectedSegmentIndex);
    [OneSignal setLocationShared:(bool) sender.selectedSegmentIndex];
}

- (IBAction)inAppMessagingSegmentedControlValueChanged:(UISegmentedControl *)sender {
    NSLog(@"View controller in app messaging paused: %i", (int) !sender.selectedSegmentIndex);
    [OneSignal pauseInAppMessages:(bool) !sender.selectedSegmentIndex];
}

- (void)handleMessageAction:(NSString *)actionId {
    NSLog(@"View controller did get action: %@", actionId);
}

- (IBAction)setExternalUserId:(UIButton *)sender {
    NSString* externalUserId = self.externalUserIdTextField.text;
    [OneSignal setExternalUserId:externalUserId withCompletion:^(NSDictionary *results) {
        NSLog(@"External user id update complete with results: %@", results.description);
    }];
}

- (IBAction)removeExternalUserId:(UIButton *)sender {
    [OneSignal removeExternalUserId:^(NSDictionary *results) {
        NSLog(@"External user id update complete with results: %@", results.description);
    }];
}

#pragma mark UITextFieldDelegate Methods
-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return false;
}

- (IBAction)sendTestOutcomeEvent:(UIButton *)sender {
    [OneSignal sendOutcome:[_outcomeName text] onSuccess:^(OSOutcomeEvent *outcome) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _result.text = [NSString stringWithFormat:@"sendTestOutcomeEvent success %@", outcome];
            [self.view endEditing:YES];
        });
    }];
}
- (IBAction)sendValueOutcomeEvent:(id)sender {
    if ([_outcomeValue text]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        NSNumber *value = [formatter numberFromString:[_outcomeValue text]];
        
        [OneSignal sendOutcomeWithValue:[_outcomeValueName text] value:value onSuccess:^(OSOutcomeEvent *outcome) {
            dispatch_async(dispatch_get_main_queue(), ^{
                _result.text = [NSString stringWithFormat:@"sendValueOutcomeEvent success %@", outcome];
                [self.view endEditing:YES];
            });
        }];
    }
}

- (IBAction)sendUniqueOutcomeEvent:(id)sender {
    [OneSignal sendUniqueOutcome:[_outcomeUniqueName text] onSuccess:^(OSOutcomeEvent *outcome) {
        dispatch_async(dispatch_get_main_queue(), ^{
            _result.text = [NSString stringWithFormat:@"sendUniqueOutcomeEvent success %@", outcome];
            [self.view endEditing:YES];
        });
    }];
}

@end
