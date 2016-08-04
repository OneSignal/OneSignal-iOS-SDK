/**
 * Modified MIT License
 *
 * Copyright 2015 OneSignal
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

#import "ViewController.h"
#import "AppDelegate.h"

@interface ViewController ()

@end

@implementation ViewController

- (AppDelegate*)appDelegate {
    return (AppDelegate*)[[UIApplication sharedApplication] delegate];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (IBAction)sendTags:(id)sender {
    [OneSignal sendTag:@"key" value:@"value"];
}

- (IBAction)getIds:(id)sender {
    [OneSignal IdsAvailable:^(NSString* userId, NSString* pushToken) {
        if (pushToken)
            self.textMultiLine1.text = [NSString stringWithFormat:@"PlayerId:\n%@\n\nPushToken:\n%@\n", userId, pushToken];
        else
            self.textMultiLine1.text = @"ERROR: Could not get a pushToken from Apple! Make sure your provisioning profile has 'Push Notifications' enabled and rebuild your app.";
        
        NSLog(@"\n%@", self.textMultiLine1.text);
    }];
}

@end
