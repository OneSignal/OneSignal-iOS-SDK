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
#import "OneSignalAlertViewDelegate.h"

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
                      foreground:(BOOL)foreground
                        isActive:(BOOL)isActive
                      actionType:(OSNotificationActionType)actionType
                     displayType:(OSNotificationDisplayType)displayType;

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

- (NSArray<NSString *> *)getActionTitlesFromPayload:(OSNotificationPayload *)payload {
    NSMutableArray<NSString *> *actionTitles = [NSMutableArray<NSString *> new];
    if (payload.actionButtons) {
        for (id button in payload.actionButtons) {
            [actionTitles addObject:button[@"text"]];
        }
    }
    return actionTitles;
}

- (void)presentDialogWithMessageDict:(NSDictionary *)messageDict {
    if ([OneSignalHelper isIOSVersionLessThan:@"8.0"]) {
        [OneSignalAlertView showInAppAlert:messageDict];
        return;
    }
    let payload = [OSNotificationPayload parseWithApns:messageDict];
    // Add action buttons to payload
    NSArray<NSString *> *actionTitles = [self getActionTitlesFromPayload:payload];

    [self presentDialogWithTitle:payload.title withMessage:payload.body withActions:actionTitles cancelTitle:@"Close" withActionCompletion:^(int tappedActionIndex) {
        OSNotificationActionType actionType = OSNotificationActionTypeOpened;
        
        NSDictionary *finalDict = messageDict;
        
        if (tappedActionIndex > -1) {
            
            actionType = OSNotificationActionTypeActionTaken;
            
            NSMutableDictionary* userInfo = [messageDict mutableCopy];
            
            // Fixed for iOS 7, which has 'actionbuttons' as a root property of the dict, not in 'os_data'
            if (messageDict[@"os_data"] && !messageDict[@"actionbuttons"]) {
                if ([messageDict[@"os_data"][@"buttons"] isKindOfClass:[NSDictionary class]])
                    userInfo[@"actionSelected"] = messageDict[@"os_data"][@"buttons"][@"o"][tappedActionIndex - 1][@"i"];
                else
                    userInfo[@"actionSelected"] = messageDict[@"os_data"][@"buttons"][tappedActionIndex][@"i"];
            } else if (messageDict[@"buttons"]) {
                 userInfo[@"actionSelected"] = messageDict[@"buttons"][tappedActionIndex][@"i"];
            } else {
                NSMutableDictionary* customDict = userInfo[@"custom"] ? [userInfo[@"custom"] mutableCopy] : [NSMutableDictionary new];
                NSMutableDictionary* additionalData = customDict[@"a"] ? [[NSMutableDictionary alloc] initWithDictionary:customDict[@"a"]] : [NSMutableDictionary new];
                
                if([additionalData[@"actionButtons"] isKindOfClass:[NSArray class]]) {
                    additionalData[@"actionSelected"] = additionalData[@"actionButtons"][tappedActionIndex - 1][@"id"];
                } else if([messageDict[@"o"] isKindOfClass:[NSArray class]]) {
                    additionalData[@"actionSelected"] = messageDict[@"o"][tappedActionIndex][@"i"];
                } else if ([messageDict[@"actionbuttons"] isKindOfClass:[NSArray class]]) {
                    additionalData[@"actionSelected"] = messageDict[@"actionbuttons"][tappedActionIndex][@"i"];
                }
                
                customDict[@"a"] = additionalData;
                userInfo[@"custom"] = customDict;
            }
            
            finalDict = userInfo;
        }
        
        [OneSignal handleNotificationOpened:finalDict foreground:YES isActive:YES actionType:actionType displayType:OSNotificationDisplayTypeInAppAlert];
    }];
    
    // Message received that was displayed (Foreground + InAppAlert is true)
    // Call received callback
    [OneSignalHelper handleNotificationReceived:OSNotificationDisplayTypeInAppAlert fromBackground:NO];
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
    //iOS 7
    if ([OneSignalHelper isIOSVersionLessThan:@"8.0"]) {
        let alertView = [[UIAlertView alloc] initWithTitle:request.title message:request.message delegate:self cancelButtonTitle:request.cancelTitle otherButtonTitles:nil, nil];
        if (request.actionTitles != nil) {
            for (NSString *actionTitle in request.actionTitles) {
                [alertView addButtonWithTitle:actionTitle];
            }
        }
        
        [alertView show];
        
        return;
    }
    
    //iOS 8 and later
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
