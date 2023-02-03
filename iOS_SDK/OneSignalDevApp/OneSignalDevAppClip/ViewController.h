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

#import <UIKit/UIKit.h>
#import <OneSignalFramework/OneSignalFramework.h>

@interface ViewController : UIViewController <OSInAppMessageDelegate>

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *consentSegmentedControl;
@property (weak, nonatomic) IBOutlet UITextField *appIdTextField;
@property (weak, nonatomic) IBOutlet UIButton *updateAppIdButton;
@property (weak, nonatomic) IBOutlet UIButton *getInfoButton;
@property (weak, nonatomic) IBOutlet UIButton *sendTagsButton;
@property (weak, nonatomic) IBOutlet UIButton *promptPushButton;
@property (weak, nonatomic) IBOutlet UIButton *promptLocationButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *subscriptionSegmentedControl;
@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UIButton *addEmailButton;
@property (weak, nonatomic) IBOutlet UIButton *removeEmailButton;
@property (weak, nonatomic) IBOutlet UITextField *externalUserIdTextField;
@property (weak, nonatomic) IBOutlet UIButton *loginExternalUserIdButton;
@property (weak, nonatomic) IBOutlet UIButton *logoutButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *locationSharedSegementedControl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *inAppMessagingSegmentedControl;
@property (weak, nonatomic) IBOutlet UITextField *addTriggerKey;
@property (weak, nonatomic) IBOutlet UITextField *addTriggerValue;
@property (weak, nonatomic) IBOutlet UIButton *addTriggerButton;
@property (weak, nonatomic) IBOutlet UITextField *removeTriggerKey;
@property (weak, nonatomic) IBOutlet UITextField *getTriggerKey;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;
@property (weak, nonatomic) IBOutlet UITextField *outcomeName;
@property (weak, nonatomic) IBOutlet UITextField *outcomeValueName;
@property (weak, nonatomic) IBOutlet UITextField *outcomeValue;
@property (weak, nonatomic) IBOutlet UITextField *outcomeUniqueName;
@property (weak, nonatomic) IBOutlet UITextView *result;
@property (weak, nonatomic) IBOutlet UILabel *appClipLabel;

@end

