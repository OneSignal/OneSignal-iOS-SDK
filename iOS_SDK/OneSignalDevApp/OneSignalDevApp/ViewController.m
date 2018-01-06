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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.example.onesignal"];
    NSLog(@"User defaults value: %@", [userDefaults objectForKey:@"tst"]);
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


@end
