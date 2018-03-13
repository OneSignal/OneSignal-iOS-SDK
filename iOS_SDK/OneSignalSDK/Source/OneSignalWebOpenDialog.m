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

#import "OneSignalWebOpenDialog.h"
#import "OneSignalHelper.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface OneSignalWebOpenDialog ()
@property (strong, nonatomic) UIAlertView *alertView;
@property (nonatomic) OSWebOpenURLResultBlock resultBlock;
@end

@implementation OneSignalWebOpenDialog

+ (instancetype)sharedInstance
{
    static OneSignalWebOpenDialog *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OneSignalWebOpenDialog alloc] init];
        // Do any other initialisation stuff here
    });
    return sharedInstance;
}

+ (void)showOpenDialogwithURL:(NSURL *)url withResponse:(OSWebOpenURLResultBlock)shouldOpen {
    
    let message = NSLocalizedString(([NSString stringWithFormat:@"Would you like to open %@://%@", url.scheme, url.host]), @"Asks whether the user wants to open the URL");
    
    //for iOS 7
    if (![OneSignalHelper isIOSVersionGreaterOrEqual:8]) {
        let alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Open URL?", nil)
                                                   message:message
                                                delegate:[OneSignalWebOpenDialog sharedInstance]
                                         cancelButtonTitle:NSLocalizedString(@"No", nil)
                                                otherButtonTitles:NSLocalizedString(@"Yes", nil), nil];
        
        [OneSignalWebOpenDialog sharedInstance].resultBlock = shouldOpen;
        
        [alertView show];
        
        return;
    }
    
    //for iOS 8+
    let rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    
    let alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Open URL?", nil)
                                                              message:message
                                                preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [OneSignalWebOpenDialog delayResult:shouldOpen shouldOpen:true];
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"No", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [OneSignalWebOpenDialog delayResult:shouldOpen shouldOpen:false];
    }]];
    
    [rootViewController presentViewController:alertController animated:true completion:nil];
}

// We need to delay the result to let pending animations (ie. dismissal of UIAlertController) to complete
+ (void)delayResult:(OSWebOpenURLResultBlock)finishBlock shouldOpen:(BOOL)shouldOpen {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        finishBlock(shouldOpen);
    });
}

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    let index = (int)buttonIndex;
    [OneSignalWebOpenDialog delayResult:self.resultBlock shouldOpen:index == 1];
}

@end
