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

#import "OneSignalDialogController.h"
#import "OneSignalHelper.h"
#import "OneSignalDialogRequest.h"

/*
 This class handles displaying all dialogs (alerts) for the SDK
 Because the SDK can (in rare cases) attempt to present multiple
 dialogs, this controller also queues dialogs
 */

@interface OneSignalDialogController ()

@property (strong, nonatomic, nonnull) NSMutableArray <OSDialogRequest *> *queue;

@end

@interface OneSignal ()

+ (void)handleNotificationOpened:(NSDictionary*)messageDict
                      actionType:(OSNotificationActionType)actionType;

@end

@implementation OneSignalDialogController

+ (instancetype _Nonnull)sharedInstance {
    static OneSignalDialogController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OneSignalDialogController alloc] init];
        // Do any other initialisation stuff here
        
        sharedInstance.queue = [NSMutableArray new];
    });
    return sharedInstance;
}

- (NSArray<NSString *> *)getActionTitlesFromNotification:(OSNotification *)notification {
    NSMutableArray<NSString *> *actionTitles = [NSMutableArray<NSString *> new];
    if (notification.actionButtons) {
        for (id button in notification.actionButtons) {
            [actionTitles addObject:button[@"text"]];
        }
    }
    return actionTitles;
}

- (void)presentDialogWithTitle:(NSString * _Nonnull)title withMessage:(NSString * _Nonnull)message withActions:(NSArray<NSString *> * _Nullable)actionTitles cancelTitle:(NSString * _Nonnull)cancelTitle withActionCompletion:(OSDialogActionCompletion _Nullable)completion {
    
    //ensure this UI code executes on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        let request = [[OSDialogRequest alloc] initWithTitle:title withMessage:message withActionTitles:actionTitles withCancelTitle:cancelTitle withCompletion:completion];
        
        [self.queue addObject:request];
        
        //check if already presenting a different dialog
        //if so, we shouldn't present on top of existing dialog
        if (self.queue.count > 1)
            return;
        
        [self displayDialog:request];
    });
}

- (void)displayDialog:(OSDialogRequest * _Nonnull)request {
    let rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    
    let controller = [UIAlertController alertControllerWithTitle:request.title message:request.message preferredStyle:UIAlertControllerStyleAlert];
    
    [controller addAction:[UIAlertAction actionWithTitle:request.cancelTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self delayResult:-1];
    }]];
    
    if (request.actionTitles != nil) {
        for (int i = 0; i < request.actionTitles.count; i++) {
            NSString *actionTitle = request.actionTitles[i];
            [controller addAction:[UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self delayResult:i];
            }]];
        }
    }
    
    [rootViewController presentViewController:controller animated:true completion:nil];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [self delayResult:(int)buttonIndex-1];
}

- (void)delayResult:(int)result {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        let currentDialog = self.queue.firstObject;
        
        if (currentDialog.completion)
            currentDialog.completion(result);
        
        [self.queue removeObjectAtIndex:0];
        
        //check if no more dialogs left to display in queue
        if (self.queue.count == 0)
            return;
        
        let nextDialog = self.queue.firstObject;
        
        [self displayDialog:nextDialog];
    });
}

- (void)clearQueue {
    self.queue = [NSMutableArray new];
}

@end
