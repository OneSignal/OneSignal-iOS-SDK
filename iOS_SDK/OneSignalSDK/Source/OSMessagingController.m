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

#import "OSMessagingController.h"
#import "OneSignalHelper.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OneSignalInternal.h"
#import "OSInAppMessageAction.h"
#import "OSInAppMessageController.h"

@interface OSMessagingController ()
@property (strong, nonatomic, nullable) UIWindow *window;
@property (weak, nonatomic, nullable) OSInAppMessageViewController *messageViewController;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessageDelegate> *delegates;
@property (strong, nonatomic, nonnull) NSArray <OSInAppMessage *> *messages;
@property (strong, nonatomic, nonnull) OSTriggerController *triggerController;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessage *> *messageDisplayQueue;
@end

@implementation OSMessagingController

+ (OSMessagingController *)sharedInstance {
    static OSMessagingController *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [OSMessagingController new];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.delegates = [NSMutableArray<OSInAppMessageDelegate> new];
        self.messages = [NSArray<OSInAppMessage *> new];
        
        self.triggerController = [OSTriggerController new];
        self.triggerController.delegate = self;
        
        self.messageDisplayQueue = [NSMutableArray new];
    }
    
    return self;
}

- (void)didUpdateMessagesForSession:(NSArray<OSInAppMessage *> *)newMessages {
    self.messages = newMessages;
    
    [self evaluateMessages];
}

- (void)addMessageDelegate:(id<OSInAppMessageDelegate>)delegate {
    [self.delegates addObject:delegate];
}

-(void)presentInAppMessage:(OSInAppMessage *)message {
    @synchronized (self.messageDisplayQueue) {
        [self.messageDisplayQueue addObject:message];
        
        // if > 1 it means we are already presenting a message.
        if (self.messageDisplayQueue.count > 1)
            return;
        
        [self displayMessage:message];
        
        let metricsRequest = [OSRequestInAppMessageViewed withAppId:OneSignal.app_id
                                                     withPlayerId:OneSignal.currentSubscriptionState.userId
                                                     withMessageId:message.messageId
                                                     forVariantId:message.variantId];
        
        [OneSignalClient.sharedClient executeRequest:metricsRequest onSuccess:nil onFailure:nil];
    };
}

- (void)displayMessage:(OSInAppMessage *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) {
            self.window = [[UIWindow alloc] init];
            self.window.windowLevel = UIWindowLevelAlert;
            self.window.frame = [[UIScreen mainScreen] bounds];
        }
        
        let viewController = [[OSInAppMessageViewController alloc] initWithMessage:message];
        viewController.delegate = self;
        self.messageViewController = viewController;
        
        self.window.rootViewController = self.messageViewController;
        self.window.backgroundColor = [UIColor clearColor];
        self.window.opaque = true;
        [self.window makeKeyAndVisible];
    });
}

// checks to see if any messages should be shown now
- (void)evaluateMessages {
    for (OSInAppMessage *message in self.messages) {
        if ([self.triggerController messageMatchesTriggers:message]) {
            // we should show the message
            [self presentInAppMessage:message];
        }
    }
}

- (void)handleMessageActionWithURL:(OSInAppMessageAction *)action {
    switch (action.urlActionType) {
            case OSInAppMessageActionUrlTypeSafari:
            [[UIApplication sharedApplication] openURL:action.actionUrl options:@{} completionHandler:^(BOOL success) {}];
            break;
        case OSInAppMessageActionUrlTypeWebview:
            [OneSignalHelper displayWebView:action.actionUrl];
            break;
        case OSInAppMessageActionUrlTypeReplaceContent:
            // this case is handled by the in-app message view controller.
            break;
    }
}

#pragma mark Trigger Methods
- (void)setTriggers:(NSDictionary<NSString *, id> *)triggers {
    [self.triggerController addTriggers:triggers];
}

- (void)removeTriggersForKeys:(NSArray<NSString *> *)keys {
    [self.triggerController removeTriggersForKeys:keys];
}

- (NSDictionary<NSString *, id> *)getTriggers {
    return self.triggerController.getTriggers;
}

- (id)getTriggerValueForKey:(NSString *)key {
    return [self.triggerController getTriggerValueForKey:key];
}

#pragma mark OSInAppMessageViewControllerDelegate Methods
-(void)messageViewControllerWasDismissed {
    @synchronized (self.messageDisplayQueue) {
        [self.messageDisplayQueue removeObjectAtIndex:0];
        
        if (self.messageDisplayQueue.count > 0) {
            [self displayMessage:self.messageDisplayQueue.firstObject];
            return;
        } else {
            self.window.hidden = true;
            
            [UIApplication.sharedApplication.delegate.window makeKeyWindow];
            
            //nullify our reference to the window to ensure there are no leaks
            self.window = nil;
        }
    }
}

- (void)messageViewDidSelectAction:(OSInAppMessageAction *)action withMessageId:(NSString *)messageId forVariantId:(NSString *)variantId {
    if (action.actionUrl)
        [self handleMessageActionWithURL:action];
    
    for (id<OSInAppMessageDelegate> delegate in self.delegates)
        [delegate handleMessageAction:action];
  
    let metricsRequest = [OSRequestInAppMessageOpened withAppId:OneSignal.app_id
                                                 withPlayerId:OneSignal.currentSubscriptionState.userId
                                                 withMessageId:messageId
                                                 forVariantId: variantId
                                                 withActionId:action.actionId];
    
    [OneSignalClient.sharedClient executeRequest:metricsRequest onSuccess:nil onFailure:nil];
}

#pragma mark OSTriggerControllerDelegate Methods
-(void)triggerConditionChanged {
    // we should re-evaluate all in-app messages
    [self evaluateMessages];
}

@end
