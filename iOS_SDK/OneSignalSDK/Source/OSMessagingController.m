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
#import "OneSignalUserDefaults.h"
#import "OneSignalHelper.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OneSignalInternal.h"
#import "OSInAppMessageAction.h"
#import "OSInAppMessageController.h"


@interface OSMessagingController ()

@property (strong, nonatomic, nullable) UIWindow *window;
@property (strong, nonatomic, nonnull) NSArray <OSInAppMessage *> *messages;
@property (strong, nonatomic, nonnull) OSTriggerController *triggerController;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessage *> *messageDisplayQueue;

// Tracking already seen IAMs, used to prevent showing an IAM more than once after it has been dismissed
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *seenInAppMessages;

// Tracking for click ids wihtin IAMs so that body, button, and image are only tracked on the dashboard once
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *clickedClickIds;

// Tracking for impessions so that an IAM is only tracked once and not several times if it is reshown
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *impressionedInAppMessages;

// Tracks when an IAM is showing or not, useful for deciding to show or hide an IAM
// Toggled in two places dismissing/displaying
@property (nonatomic) BOOL isInAppMessageShowing;

// Click action block to allow overridden behavior when clicking an IAM
@property (strong, nonatomic, nullable) OSHandleInAppMessageActionClickBlock actionClickBlock;

@property (strong, nullable) OSInAppMessageViewController *viewController;

@end


@implementation OSMessagingController
@synthesize isInAppMessagingPaused = _isInAppMessagingPaused;

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
        self.messages = [NSArray<OSInAppMessage *> new];
        
        self.triggerController = [OSTriggerController new];
        self.triggerController.delegate = self;
        
        self.messageDisplayQueue = [NSMutableArray new];
        
        // Get all cached IAM data from NSUserDefaults for shown, impressions, and clicks
        self.seenInAppMessages = [[NSMutableSet alloc] initWithSet:[OneSignalUserDefaults getSavedSet:OS_IAM_SEEN_SET_KEY]];
        self.clickedClickIds = [[NSMutableSet alloc] initWithSet:[OneSignalUserDefaults getSavedSet:OS_IAM_CLICKED_SET_KEY]];
        self.impressionedInAppMessages = [[NSMutableSet alloc] initWithSet:[OneSignalUserDefaults getSavedSet:OS_IAM_IMPRESSIONED_SET_KEY]];
        
        // BOOL that controls if in-app messaging is paused or not (false by default)
        [self setInAppMessagingPaused:false];
    }
    
    return self;
}

- (BOOL)isInAppMessagingPaused {
    return _isInAppMessagingPaused;
}

- (void)setInAppMessagingPaused:(BOOL)pause {
    _isInAppMessagingPaused = pause;
}

- (void)didUpdateMessagesForSession:(NSArray<OSInAppMessage *> *)newMessages {
    self.messages = newMessages;
    
    [self evaluateMessages];
}

- (void)setInAppMessageClickHandler:(OSHandleInAppMessageActionClickBlock)actionClickBlock {
    self.actionClickBlock = actionClickBlock;
}

- (void)presentInAppMessage:(OSInAppMessage *)message {
    
    // Check if the app disabled IAMs for this device
    if (_isInAppMessagingPaused)
        return;
    
    if (message.variantId == nil) {
        let errorMessage = [NSString stringWithFormat:@"Attempted to display a message with a nil variantId. Current preferred language is %@, supported message variants are %@", NSLocale.preferredLanguages, message.variants];
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:errorMessage];
        return;
    }
    
    // Check if the message already exists in the display queue
    if ([self.messageDisplayQueue containsObject:message])
        return;
    
    @synchronized (self.messageDisplayQueue) {
        [self.messageDisplayQueue addObject:message];
        
        // Return early if an IAM is already showing
        if (self.isInAppMessageShowing)
            return;
        
        [self displayMessage:message];
    };
}

- (void)presentInAppPreviewMessage:(OSInAppMessage *)message {
    @synchronized (self.messageDisplayQueue) {
        
        // If an IAM is currently showing add the preview right behind it in the messageDisplayQueue and then dismiss the current IAM
        // Otherwise, Add it to the front of the messageDisplayQueue and call displayMessage
        if (self.isInAppMessageShowing) {
            
            // Add preview behind current displaying IAM in messageDisplayQueue
            [self.messageDisplayQueue insertObject:message atIndex:1];
            // Get current OSInAppMessageViewController and dismiss current IAM showing using dismissMessageWithDirection method
            [self.viewController dismissCurrentInAppMessage];
        } else {
            
            // Add preview to front of messageDisplayQueue
            [self.messageDisplayQueue insertObject:message atIndex:0];
            // Show new IAM preview
            [self displayMessage:message];
        }
    };
}

- (void)displayMessage:(OSInAppMessage *)message {
    self.isInAppMessageShowing = true;
    self.viewController = [[OSInAppMessageViewController alloc] initWithMessage:message];
    self.viewController.delegate = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self.viewController view] setNeedsLayout];
    });
    
    [self messageViewImpressionRequest:message];
}

/*
 Make an impression POST to track that the IAM has been
 Request should only be made for IAMs that are not previews and have not been impressioned yet
 */
- (void)messageViewImpressionRequest:(OSInAppMessage *)message {
    
    // Make sure no tracking is performed for previewed IAMs
    // If the messageId exists in cached impressionedInAppMessages return early so the impression is not tracked again
    if (message.isPreview ||
        [self.impressionedInAppMessages containsObject:message.messageId])
        return;
    
    // Add messageId to impressionedInAppMessages
    [self.impressionedInAppMessages addObject:message.messageId];
    
    // Create the request and attach a payload to it
    let metricsRequest = [OSRequestInAppMessageViewed withAppId:OneSignal.app_id
                                                   withPlayerId:OneSignal.currentSubscriptionState.userId
                                                  withMessageId:message.messageId
                                                   forVariantId:message.variantId];
    
    [OneSignalClient.sharedClient executeRequest:metricsRequest
                                       onSuccess:^(NSDictionary *result) {
                                           NSString *successMessage = [NSString stringWithFormat:@"In App Message with id: %@, successful POST impression update with result: %@", message.messageId, result];
                                           [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:successMessage];
                                           
                                           // If the post was successful, save the updated impressionedInAppMessages set
                                           [OneSignalUserDefaults saveSet:self.impressionedInAppMessages withKey:OS_IAM_IMPRESSIONED_SET_KEY];
                                       }
                                       onFailure:^(NSError *error) {
                                           NSString *errorMessage = [NSString stringWithFormat:@"In App Message with id: %@, failed POST impression update with error: %@", message.messageId, error];
                                           [OneSignal onesignal_Log:ONE_S_LL_ERROR message:errorMessage];
                                           
                                           // If the post failed, remove the messageId from the impressionedInAppMessages set
                                           [self.impressionedInAppMessages removeObject:message.messageId];
                                       }];
}

/*
 Checks to see if any messages should be shown now
 */
- (void)evaluateMessages {
    for (OSInAppMessage *message in self.messages) {
        // Should we show the in app message
        if ([self shouldShowInAppMessage:message]) {
            [self presentInAppMessage:message];
        }
    }
}

/*
 Method to check whether or not to show an IAM
 Checks if the IAM matches any triggers or if it exists in cached seenInAppMessages set
 */
- (BOOL)shouldShowInAppMessage:(OSInAppMessage *)message {
    return ![self.seenInAppMessages containsObject:message.messageId] &&
    [self.triggerController messageMatchesTriggers:message];
}

- (void)handleMessageActionWithURL:(OSInAppMessageAction *)action {
    switch (action.urlActionType) {
        case OSInAppMessageActionUrlTypeSafari:
            [[UIApplication sharedApplication] openURL:action.clickUrl options:@{} completionHandler:^(BOOL success) {}];
            break;
        case OSInAppMessageActionUrlTypeWebview:
            [OneSignalHelper displayWebView:action.clickUrl];
            break;
        case OSInAppMessageActionUrlTypeReplaceContent:
            // This case is handled by the in-app message view controller.
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
- (void)messageViewControllerWasDismissed {
    @synchronized (self.messageDisplayQueue) {
        self.isInAppMessageShowing = false;
      
        // Reset time since last IAM
        [self.triggerController timeSinceLastMessage:[NSDate new]];

        // Null the current IAM viewController to prepare for next IAM if one exists
        self.viewController = nil;
        
        // Add current dismissed messageId to seenInAppMessages set and save it to NSUserDefaults
        [self.seenInAppMessages addObject:self.messageDisplayQueue.firstObject.messageId];
        [OneSignalUserDefaults saveSet:self.seenInAppMessages withKey:OS_IAM_SEEN_SET_KEY];
        
        // Remove dismissed IAM from messageDisplayQueue
        [self.messageDisplayQueue removeObjectAtIndex:0];
        
        if (self.messageDisplayQueue.count > 0) {
            // Show next IAM in queue
            [self displayMessage:self.messageDisplayQueue.firstObject];
            return;
        } else {
            // Hide and null our reference to the window to ensure there are no leaks
            self.window.hidden = true;
            [UIApplication.sharedApplication.delegate.window makeKeyWindow];
            self.window = nil;
            
            // Evaulate any IAMs (could be new or have now satisfied trigger conditions)
            [self evaluateMessages];
        }
    }
}

- (void)messageViewDidSelectAction:(OSInAppMessage *)message withAction:(OSInAppMessageAction *)action {
    // Assign firstClick BOOL based on message being clicked previously or not
    action.firstClick = [message takeActionAsUnique];
    
    if (action.clickUrl)
        [self handleMessageActionWithURL:action];
    
    if (self.actionClickBlock)
        self.actionClickBlock(action);
  
    // Make sure no click tracking is performed for IAM previews
    // If the IAM clickId exists within the cached clickedClickIds return early so the click is not tracked
    // Handles body, button, or image clicks
    if (message.isPreview ||
        [self.clickedClickIds containsObject:action.clickId])
        return;
    
    // Add clickId to clickedClickIds
    [self.clickedClickIds addObject:action.clickId];
    
    let metricsRequest = [OSRequestInAppMessageClicked withAppId:OneSignal.app_id
                                                    withPlayerId:OneSignal.currentSubscriptionState.userId
                                                   withMessageId:message.messageId
                                                    forVariantId:message.variantId
                                                      withAction:action];
    
    [OneSignalClient.sharedClient executeRequest:metricsRequest
                                       onSuccess:^(NSDictionary *result) {
                                           NSString *successMessage = [NSString stringWithFormat:@"In App Message with id: %@, successful POST click update for click id: %@, with result: %@", message.messageId, action.clickId,  result];
                                           [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:successMessage];
                                           
                                           // Save the updated clickedClickIds since click was tracked successfully
                                           [OneSignalUserDefaults saveSet:self.clickedClickIds withKey:OS_IAM_CLICKED_SET_KEY];
                                       }
                                       onFailure:^(NSError *error) {
                                           NSString *errorMessage = [NSString stringWithFormat:@"In App Message with id: %@, failed POST click update for click id: %@, with error: %@", message.messageId, action.clickId, error];
                                           [OneSignal onesignal_Log:ONE_S_LL_ERROR message:errorMessage];
                                           
                                           // Remove clickId from local clickedClickIds since click was not tracked
                                           [self.clickedClickIds removeObject:action.clickId];
                                       }];
}

/*
 This method must be called on the Main thread
 */
- (void)webViewContentFinishedLoading {
    if (!self.viewController) {
        [self evaluateMessages];
        return;
    }
    
    if (!self.window) {
        self.window = [[UIWindow alloc] init];
        self.window.windowLevel = UIWindowLevelAlert;
        self.window.frame = [[UIScreen mainScreen] bounds];
    }
    
    self.window.rootViewController = _viewController;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.opaque = true;
    self.window.clipsToBounds = true;
    [self.window makeKeyAndVisible];
}

#pragma mark OSTriggerControllerDelegate Methods
- (void)triggerConditionChanged {
    // We should re-evaluate all in-app messages
    [self evaluateMessages];
}

@end
