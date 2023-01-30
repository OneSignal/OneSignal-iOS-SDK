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
#import "OneSignalHelper.h" // need for displayWebView, which can be moved out in the future
#import "UIApplication+OneSignal.h" // Previously imported via "OneSignalHelper.h"
#import "NSDateFormatter+OneSignal.h" // Previously imported via "OneSignalHelper.h"
#import <OneSignalCore/OneSignalCore.h>
#import "OSInAppMessageAction.h"
#import "OSInAppMessageController.h"
#import "OSInAppMessagePrompt.h"
#import "OneSignalDialogController.h"
#import "OSInAppMessagingRequests.h"

@interface OneSignal ()

+ (void)sendClickActionOutcomes:(NSArray<OSInAppMessageOutcome *> *)outcomes;

@end

@interface OSMessagingController ()

@property (strong, nonatomic, nullable) UIWindow *window;
@property (strong, nonatomic, nonnull) NSArray <OSInAppMessageInternal *> *messages;
@property (strong, nonatomic, nonnull) OSTriggerController *triggerController;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessageInternal *> *messageDisplayQueue;

// Tracking already seen IAMs, used to prevent showing an IAM more than once after it has been dismissed
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *seenInAppMessages;

// Tracking IAMs with redisplay, used to enable showing an IAM more than once after it has been dismissed
@property (strong, nonatomic, nonnull) NSMutableDictionary <NSString *, OSInAppMessageInternal *> *redisplayedInAppMessages;

// Tracking for click ids wihtin IAMs so that body, button, and image are only tracked on the dashboard once
// TODO:We should refactor this to be like redisplay logic, save clickId + IAM or by IAM
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *clickedClickIds;

// Tracking for impessions so that an IAM is only tracked once and not several times if it is reshown
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *impressionedInAppMessages;

// Tracking for impessions so that an IAM is only tracked once and not several times if it is reshown
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *viewedPageIDs;

// Click action block to allow overridden behavior when clicking an IAM
@property (strong, nonatomic, nullable) OSInAppMessageClickBlock actionClickBlock;

@property (weak, nonatomic, nullable) NSObject<OSInAppMessageLifecycleHandler> *inAppMessageDelegate;

@property (strong, nullable) OSInAppMessageViewController *viewController;

@property (nonatomic, readwrite) NSTimeInterval (^dateGenerator)(void);

@property (nonatomic, nullable) NSObject<OSInAppMessagePrompt> *currentPromptAction;

@property (nonatomic, nullable) NSArray<NSObject<OSInAppMessagePrompt> *> *currentPromptActions;

@property (nonatomic, nullable) OSInAppMessageInternal *currentInAppMessage;

@property (nonatomic) BOOL isAppInactive;

@property (nonatomic) BOOL calledLoadTags;

@end

@implementation OSMessagingController
@dynamic isInAppMessagingPaused;
// Maximum time decided to save IAM with redisplay on cache - current value: six months in seconds
static long OS_IAM_MAX_CACHE_TIME = 6 * 30 * 24 * 60 * 60;
static OSMessagingController *sharedInstance = nil;
static dispatch_once_t once;
+ (OSMessagingController *)sharedInstance {
    dispatch_once(&once, ^{
        // Make sure only devices with iOS 10 or newer can use IAMs
        if ([self doesDeviceSupportIAM]) {
            sharedInstance = [OSMessagingController new];
        } else {
            sharedInstance = [DummyOSMessagingController new];
        }
    });
    return sharedInstance;
}

+ (void)removeInstance {
    sharedInstance = nil;
    once = 0;
}

+ (void)start {
    OSMessagingController *shared = OSMessagingController.sharedInstance;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wunused-variable"
    OSPushSubscriptionState *_ = [OneSignalUserManagerImpl.sharedInstance addObserver:shared];
    #pragma clang diagnostic pop
}

static BOOL _isInAppMessagingPaused = false;
- (BOOL)isInAppMessagingPaused {
    return _isInAppMessagingPaused;
}
- (void)setInAppMessagingPaused:(BOOL)pause {
    _isInAppMessagingPaused = pause;
    
    // If IAM are not paused, try to evaluate and show IAMs
    if (!pause)
        [self evaluateMessages];
}

+ (BOOL)doesDeviceSupportIAM {
    // We do not support Mac Catalyst as it does not display correctly.
    // We could support in the future after we reslove the display issues.
    if ([@"Mac" isEqualToString:[OSDeviceUtils getDeviceVariant]])
        return false;
    
    // Only support iOS 10 and newer due to Safari 9 WebView issues
    return [OSDeviceUtils isIOSVersionGreaterThanOrEqual:@"10.0"];
}

- (instancetype)init {
    if (self = [super init]) {
        self.dateGenerator = ^ NSTimeInterval {
            return [[NSDate date] timeIntervalSince1970];
        };
        self.messages = [OneSignalUserDefaults.initStandard getSavedCodeableDataForKey:OS_IAM_MESSAGES_ARRAY
                                                                                          defaultValue:[NSArray<OSInAppMessageInternal *> new]];
        [self initializeTriggerController];
        self.messageDisplayQueue = [NSMutableArray new];
        
        let standardUserDefaults = OneSignalUserDefaults.initStandard;
        
        // Get all cached IAM data from NSUserDefaults for shown, impressions, and clicks
        self.seenInAppMessages = [[NSMutableSet alloc] initWithSet:[standardUserDefaults getSavedSetForKey:OS_IAM_SEEN_SET_KEY defaultValue:nil]];
        self.redisplayedInAppMessages = [[NSMutableDictionary alloc] initWithDictionary:[standardUserDefaults getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:[NSMutableDictionary new]]];
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"init redisplayedInAppMessages with: %@", [_redisplayedInAppMessages description]]];
        self.clickedClickIds = [[NSMutableSet alloc] initWithSet:[standardUserDefaults getSavedSetForKey:OS_IAM_CLICKED_SET_KEY defaultValue:nil]];
        self.impressionedInAppMessages = [[NSMutableSet alloc] initWithSet:[standardUserDefaults getSavedSetForKey:OS_IAM_IMPRESSIONED_SET_KEY defaultValue:nil]];
        self.viewedPageIDs = [[NSMutableSet alloc] initWithSet:[standardUserDefaults getSavedSetForKey:OS_IAM_PAGE_IMPRESSIONED_SET_KEY defaultValue:nil]];
        self.currentPromptAction = nil;
        self.isAppInactive = NO;
        // BOOL that controls if in-app messaging is paused or not (false by default)
        _isInAppMessagingPaused = false;
    }
    
    return self;
}

- (void)initializeTriggerController {
    self.triggerController = [OSTriggerController new];
    self.triggerController.delegate = self;
    NSString *timeSinceLastMessage = [OneSignalUserDefaults.initShared getSavedStringForKey:OS_IAM_TIME_SINCE_LAST_MESSAGE_KEY defaultValue:nil];
    [self.triggerController timeSinceLastMessage:[[NSDateFormatter iso8601DateFormatter]
                                                  dateFromString:timeSinceLastMessage]];
}

- (void)updateInAppMessagesFromCache {
    self.messages = [OneSignalUserDefaults.initStandard getSavedCodeableDataForKey:OS_IAM_MESSAGES_ARRAY defaultValue:[NSArray new]];
    [self evaluateMessages];
}

- (void)getInAppMessagesFromServer:(NSString *)subscriptionId {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"getInAppMessagesFromServer"];

    if (!subscriptionId) {
        [self updateInAppMessagesFromCache];
        return;
    }
    
    OSRequestGetInAppMessages *request = [OSRequestGetInAppMessages withSubscriptionId:subscriptionId];
    [OneSignalClient.sharedClient executeRequest:request onSuccess:^(NSDictionary *result) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"getInAppMessagesFromServer success"];
            if (result[@"in_app_messages"]) { // when there are no IAMs, will this still be there?
                let messages = [NSMutableArray new];
                
                for (NSDictionary *messageJson in result[@"in_app_messages"]) {
                    let message = [OSInAppMessageInternal instanceWithJson:messageJson];
                    if (message) {
                        [messages addObject:message];
                    }
                }
                
                [self updateInAppMessagesFromServer:messages];
                return;
            }
            
            // TODO: Check this request and response. If no IAMs returned, should we really get from cache?
            // This is the existing implementation but it could mean this user has no IAMs?
            
            // Default is using cached IAMs in the messaging controller
            [self updateInAppMessagesFromCache];
        });
    } onFailure:^(NSError *error) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"getInAppMessagesFromServer failure: %@", error.localizedDescription]];
        [self updateInAppMessagesFromCache];
    }];
}

- (void)updateInAppMessagesFromServer:(NSArray<OSInAppMessageInternal *> *)newMessages {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"updateInAppMessagesFromServer"];
    self.messages = newMessages;
    
    // Cache if messages passed in are not null, this method is called from on_session for
    //  new messages and cached when foregrounding app
    if (self.messages)
        [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_MESSAGES_ARRAY withValue:self.messages];

    self.calledLoadTags = NO;
    [self resetRedisplayMessagesBySession];
    [self evaluateMessages];
    [self deleteOldRedisplayedInAppMessages];
}

- (void)resetRedisplayMessagesBySession {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"resetRedisplayMessagesBySession with redisplayedInAppMessages: %@", [_redisplayedInAppMessages description]]];

    for (NSString *messageId in _redisplayedInAppMessages) {
        [_redisplayedInAppMessages objectForKey:messageId].isDisplayedInSession = false;
    }
}

- (void)deleteInactiveMessage:(OSInAppMessageInternal *)message {
    let deleteMessage = [NSString stringWithFormat:@"Deleting inactive in-app message from cache: %@", message.messageId];
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:deleteMessage];
    NSMutableArray *newMessagesArray = [NSMutableArray arrayWithArray:self.messages];
    [newMessagesArray removeObject: message];
    self.messages = newMessagesArray;
    if (self.messages) {
        [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_MESSAGES_ARRAY withValue:self.messages];
    } else {
        [OneSignalUserDefaults.initStandard removeValueForKey:OS_IAM_MESSAGES_ARRAY];
    }
}

/*
 Part of redisplay logic
 Remove IAMs that the last display time was six month ago
 */
- (void)deleteOldRedisplayedInAppMessages {
    NSMutableSet <NSString *> *messagesIdToRemove = [NSMutableSet new];

    let maxCacheTime = self.dateGenerator() - OS_IAM_MAX_CACHE_TIME;
    for (NSString *messageId in _redisplayedInAppMessages) {
        if ([_redisplayedInAppMessages objectForKey:messageId].displayStats.lastDisplayTime < maxCacheTime) {
            [messagesIdToRemove addObject:messageId];
        }
    }

    if ([messagesIdToRemove count] > 0) {
        NSMutableDictionary <NSString *, OSInAppMessageInternal *> * newRedisplayDictionary = [_redisplayedInAppMessages mutableCopy];
        for (NSString * messageId in messagesIdToRemove) {
            [newRedisplayDictionary removeObjectForKey:messageId];
        }

        [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:newRedisplayDictionary];
    }
}

- (void)setInAppMessageClickHandler:(OSInAppMessageClickBlock)actionClickBlock {
    self.actionClickBlock = actionClickBlock;
}

- (void)setInAppMessageDelegate:(NSObject<OSInAppMessageLifecycleHandler> *_Nullable)delegate {
    _inAppMessageDelegate = delegate;
}

- (void)onWillDisplayInAppMessage:(OSInAppMessageInternal *)message {
    if (self.inAppMessageDelegate &&
        [self.inAppMessageDelegate respondsToSelector:@selector(onWillDisplayInAppMessage:)]) {
        [self.inAppMessageDelegate onWillDisplayInAppMessage:message];
    }
}

- (void)onDidDisplayInAppMessage:(OSInAppMessageInternal *)message {
    if (self.inAppMessageDelegate &&
        [self.inAppMessageDelegate respondsToSelector:@selector(onDidDisplayInAppMessage:)]) {
        [self.inAppMessageDelegate onDidDisplayInAppMessage:message];
    }
}

- (void)onWillDismissInAppMessage:(OSInAppMessageInternal *)message {
    if (self.inAppMessageDelegate &&
        [self.inAppMessageDelegate respondsToSelector:@selector(onWillDismissInAppMessage:)]) {
        [self.inAppMessageDelegate onWillDismissInAppMessage:message];
    }
}

- (void)onDidDismissInAppMessage:(OSInAppMessageInternal *)message {
    if (self.inAppMessageDelegate &&
        [self.inAppMessageDelegate respondsToSelector:@selector(onDidDismissInAppMessage:)]) {
        [self.inAppMessageDelegate onDidDismissInAppMessage:message];
    }
}

- (void)presentInAppMessage:(OSInAppMessageInternal *)message {
    if (!message.variantId) {
        let errorMessage = [NSString stringWithFormat:@"Attempted to display a message with a nil variantId. Current preferred language is %@, supported message variants are %@", OneSignalUserManagerImpl.sharedInstance.language, message.variants];
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:errorMessage];
        return;
    }
    
    @synchronized (self.messageDisplayQueue) {
        // Add the message to the messageDisplayQueue, if it hasn't been added yet
        if (![self isMessageInDisplayQueue:message.messageId])
            [self.messageDisplayQueue addObject:message];
        
        // Return early if an IAM is already showing
        if (self.isInAppMessageShowing) {
            return;
        }
        // Return early if the app is not active
        if (![UIApplication applicationIsActive]) {
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Pause IAMs display due to app inactivity"];
            _isAppInactive = YES;
            return;
        }
        [self displayMessage:message];
    };
}

- (BOOL)isMessageInDisplayQueue:(NSString *)messageId {
    for (OSInAppMessageInternal *message in self.messageDisplayQueue) {
        if ([message.messageId isEqualToString:messageId]) {
            return true;
        }
    }
    return false;
}

/*
 If an IAM is currently showing add the preview right behind it in the messageDisplayQueue and then dismiss the current IAM
 Otherwise, Add it to the front of the messageDisplayQueue and call displayMessage
 */
- (void)presentInAppPreviewMessage:(OSInAppMessageInternal *)message {
    @synchronized (self.messageDisplayQueue) {
        if (self.isInAppMessageShowing) {
            // Add preview second in messageDisplayQueue
            [self.messageDisplayQueue insertObject:message atIndex:1];
            [self.viewController dismissCurrentInAppMessage];
        } else {
            // Add preview to front of messageDisplayQueue
            [self.messageDisplayQueue insertObject:message atIndex:0];
            [self displayMessage:message];
        }
    };
}

- (void)displayMessage:(OSInAppMessageInternal *)message {
    // Check if the app disabled IAMs for this device before showing an IAM
    if (_isInAppMessagingPaused && !message.isPreview) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"In app messages will not show while paused"];
        return;
    }
    self.isInAppMessageShowing = true;
    [self showMessage:message];
}

- (void)showMessage:(OSInAppMessageInternal *)message {
    self.viewController = [[OSInAppMessageViewController alloc] initWithMessage:message delegate:self];
    if (message.hasLiquid && !self.calledLoadTags) {
        self.viewController.waitForTags = YES;
        [self loadTags];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self.viewController view] setNeedsLayout];
    });
}

- (void)sendMessageImpression:(OSInAppMessageInternal *)message {
    if ([self shouldSendImpression:message]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self messageViewImpressionRequest:message];
        });
    }
}

- (void)loadTags {
    self.calledLoadTags = YES;
    // TODO: should we always pull new tags?
    // For now we aren't pulling new tags and we are just using what is already on the user
    // I am leaving the logic for waiting for tags to be pulled in case this changes
    self.viewController.waitForTags = NO;
}
- (void)messageViewPageImpressionRequest:(OSInAppMessageInternal *)message withPageId:(NSString *)pageId {
    if (message.isPreview) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Not sending page impression for preview message. ID: %@",pageId]];
        return;
    }
    
    if (!pageId) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Attempting to send page impression for nil page id"]];
        return;
    }
    
    NSString *messagePrefixedPageId = [message.messageId stringByAppendingString:pageId];
    
    if ([self.viewedPageIDs containsObject:messagePrefixedPageId]) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Page Impression already sent. id: %@",pageId]];
        return;
    }

    [self.viewedPageIDs addObject:messagePrefixedPageId];
    
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Page Impression Request page id: %@",pageId]];
    // Create the request and attach a payload to it
    let metricsRequest = [OSRequestInAppMessagePageViewed withAppId:OneSignal.appId
                                                       withPlayerId:OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId
                                                      withMessageId:message.messageId
                                                         withPageId:pageId
                                                       forVariantId:message.variantId];

    [OneSignalClient.sharedClient executeRequest:metricsRequest
                                       onSuccess:^(NSDictionary *result) {
        NSString *successMessage = [NSString stringWithFormat:@"In App Message with message id: %@ and page id: %@, successful POST page impression update with result: %@", message.messageId, pageId, result];
                                           [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:successMessage];
                                            // If the post was successful, save the updated viewedPageIds set
                                            [OneSignalUserDefaults.initStandard saveSetForKey:OS_IAM_PAGE_IMPRESSIONED_SET_KEY withValue:self.viewedPageIDs];
                                       }
                                       onFailure:^(NSError *error) {
        NSString *errorMessage = [NSString stringWithFormat:@"In App Message with message id: %@ and page id: %@, failed POST page impression update with error: %@", message.messageId, pageId, error];
                                            [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:errorMessage];
                                            if (message) {
                                                [self.viewedPageIDs removeObject:messagePrefixedPageId];
                                            }
                                       }];
}

- (BOOL)shouldSendImpression:(OSInAppMessageInternal *)message {
    return !(message.isPreview || [self.impressionedInAppMessages containsObject:message.messageId]);
}

/*
 Make an impression POST to track that the IAM has been
 Request should only be made for IAMs that are not previews and have not been impressioned yet
 */
- (void)messageViewImpressionRequest:(OSInAppMessageInternal *)message {
    // Make sure no tracking is performed for previewed IAMs
    // If the messageId exists in cached impressionedInAppMessages return early so the impression is not tracked again
    if (![self shouldSendImpression:message])
        return;
    
    // Add messageId to impressionedInAppMessages
    [self.impressionedInAppMessages addObject:message.messageId];
    
    // Create the request and attach a payload to it
    let metricsRequest = [OSRequestInAppMessageViewed withAppId:OneSignal.appId
                                                   withPlayerId:OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId
                                                  withMessageId:message.messageId
                                                   forVariantId:message.variantId];
    
    [OneSignalClient.sharedClient executeRequest:metricsRequest
                                       onSuccess:^(NSDictionary *result) {
                                           NSString *successMessage = [NSString stringWithFormat:@"In App Message with id: %@, successful POST impression update with result: %@", message.messageId, result];
                                           [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:successMessage];
                                           
                                           // If the post was successful, save the updated impressionedInAppMessages set
                                           [OneSignalUserDefaults.initStandard saveSetForKey:OS_IAM_IMPRESSIONED_SET_KEY withValue:self.impressionedInAppMessages];
                                       }
                                       onFailure:^(NSError *error) {
                                           NSString *errorMessage = [NSString stringWithFormat:@"In App Message with id: %@, failed POST impression update with error: %@", message.messageId, error];
                                           [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:errorMessage];
                                           
                                           // If the post failed, remove the messageId from the impressionedInAppMessages set
                                           [self.impressionedInAppMessages removeObject:message.messageId];
                                       }];
}

/*
 Checks to see if any messages should be shown now
 */
- (void)evaluateMessages {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Evaluating in app messages"];
    for (OSInAppMessageInternal *message in self.messages) {
        if ([self.triggerController messageMatchesTriggers:message]) {
            // Make changes to IAM if redisplay available
            [self setDataForRedisplay:message];
            // Should we show the in app message
            if ([self shouldShowInAppMessage:message]) {
                [self presentInAppMessage:message];
            }
        }
    }
}

/*
 Part of redisplay logic

 In order to redisplay an IAM, the following conditions must be satisfied:
     1. IAM has redisplay property
     2. Time delay between redisplay satisfied
     3. Has more redisplays
     4. An IAM trigger was satisfied

 For redisplay, the message need to be removed from the arrays that track the display/impression
 For click counting, every message has it click id array
*/
- (void)setDataForRedisplay:(OSInAppMessageInternal *)message {
    if (!message.displayStats.isRedisplayEnabled) {
        return;
    }

    BOOL messageDismissed = [_seenInAppMessages containsObject:message.messageId];
    let redisplayMessageSavedData = [_redisplayedInAppMessages objectForKey:message.messageId];

    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Redisplay dismissed: %@ and data: %@", messageDismissed ? @"YES" : @"NO", redisplayMessageSavedData.jsonRepresentation.description]];

    if (messageDismissed && redisplayMessageSavedData) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Redisplay IAM: %@", message.jsonRepresentation.description]];
        
        message.displayStats.displayQuantity = redisplayMessageSavedData.displayStats.displayQuantity;
        message.displayStats.lastDisplayTime = redisplayMessageSavedData.displayStats.lastDisplayTime;

        // Message that don't have triggers should display only once per session
        BOOL triggerHasChanged = [self hasMessageTriggerChanged:message];

        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"setDataForRedisplay with message: %@ \ntriggerHasChanged: %@ \nno triggers: %@ \ndisplayed in session saved: %@", message, message.isTriggerChanged ? @"YES" : @"NO", [message.triggers count] == 0 ? @"YES" : @"NO", redisplayMessageSavedData.isDisplayedInSession  ? @"YES" : @"NO"]];
        // Check if conditions are correct for redisplay
        if (triggerHasChanged &&
            [message.displayStats isDelayTimeSatisfied:self.dateGenerator()] &&
            [message.displayStats shouldDisplayAgain]) {
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"setDataForRedisplay clear arrays"];

            [self.seenInAppMessages removeObject:message.messageId];
            [self.impressionedInAppMessages removeObject:message.messageId];
            [self.viewedPageIDs removeAllObjects];
            [OneSignalUserDefaults.initStandard saveSetForKey:OS_IAM_PAGE_IMPRESSIONED_SET_KEY withValue:self.viewedPageIDs];
            [message clearClickIds];
            return;
        }
    }
}

- (BOOL)hasMessageTriggerChanged:(OSInAppMessageInternal *)message {
    // Message that only have dynamic trigger should display only once per session
    BOOL messageHasOnlyDynamicTrigger = [self.triggerController messageHasOnlyDynamicTriggers:message];
    if (messageHasOnlyDynamicTrigger)
        return !message.isDisplayedInSession;

    // Message that don't have triggers should display only once per session
    BOOL shouldMessageDisplayInSession = !message.isDisplayedInSession && [message.triggers count] == 0;

    return message.isTriggerChanged || shouldMessageDisplayInSession;
}

/*
 Method to check whether or not to show an IAM
 Checks if the IAM matches any triggers or if it exists in cached seenInAppMessages set
 */
- (BOOL)shouldShowInAppMessage:(OSInAppMessageInternal *)message {
    return ![self.seenInAppMessages containsObject:message.messageId] &&
           [self.triggerController messageMatchesTriggers:message] &&
           ![message isFinished] &&
           OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId != nil;
    return true;
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

/*
 * Part of redisplay logic
 *
 * Make all messages with redisplay available if:
 *   - Already displayed
 *   - At least one Trigger has changed
 */
- (void)evaluateRedisplayedInAppMessages:(NSArray<NSString *> *)newTriggersKeys {
    for (OSInAppMessageInternal *message in _messages) {
        if ([_redisplayedInAppMessages objectForKey:message.messageId] &&
            [self.triggerController hasSharedTriggers:message newTriggersKeys:newTriggersKeys]) {
              message.isTriggerChanged = true;
        }
    }
}

#pragma mark Trigger Methods
- (void)addTriggers:(NSDictionary<NSString *, id> *)triggers {
    [self evaluateRedisplayedInAppMessages:triggers.allKeys];
    [self.triggerController addTriggers:triggers];
}

- (void)removeTriggersForKeys:(NSArray<NSString *> *)keys {
    [self evaluateRedisplayedInAppMessages:keys];
    [self.triggerController removeTriggersForKeys:keys];
}

- (void)clearTriggers {
    NSDictionary<NSString *, id> *allTriggers = [self getTriggers];
    [self removeTriggersForKeys:allTriggers.allKeys];
}

- (NSDictionary<NSString *, id> *)getTriggers {
    return self.triggerController.getTriggers;
}

- (id)getTriggerValueForKey:(NSString *)key {
    return [self.triggerController getTriggerValueForKey:key];
}

#pragma mark OSInAppMessageViewControllerDelegate Methods
- (void)messageViewControllerDidDisplay:(OSInAppMessageInternal *)message {
    [self onDidDisplayInAppMessage:message];
}

- (void)messageViewControllerWillDismiss:(OSInAppMessageInternal *)message {
    [self onWillDismissInAppMessage:message];
}

- (void)messageViewControllerWasDismissed:(OSInAppMessageInternal *)message displayed:(BOOL)displayed {
    @synchronized (self.messageDisplayQueue) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Dismissing IAM and preparing to show next IAM"];
        // Remove DIRECT influence due to ClickHandler of ClickAction outcomes
        [[OSSessionManager sharedSessionManager] onDirectInfluenceFromIAMClickFinished];

        // Add current dismissed messageId to seenInAppMessages set and save it to NSUserDefaults
        if (self.isInAppMessageShowing) {
            if (displayed) {
                [self onDidDismissInAppMessage:message];
            }
            OSInAppMessageInternal *showingIAM = self.messageDisplayQueue.firstObject;
            [self.seenInAppMessages addObject:showingIAM.messageId];
            [OneSignalUserDefaults.initStandard saveSetForKey:OS_IAM_SEEN_SET_KEY withValue:self.seenInAppMessages];
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Dismissing IAM save seenInAppMessages: %@", _seenInAppMessages]];
            // Remove dismissed IAM from messageDisplayQueue
            [self.messageDisplayQueue removeObjectAtIndex:0];
            [self persistInAppMessageForRedisplay:showingIAM];
        }
        // Reset the IAM viewController to prepare for next IAM if one exists
        self.viewController = nil;
        // Reset time since last IAM
        [self setAndPersistTimeSinceLastMessage];

        if (!_currentPromptAction) {
            [self evaluateMessageDisplayQueue];
        } else { //do nothing prompt is handling the re-showing
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Stop evaluateMessageDisplayQueue because prompt is currently displayed"];
        }
    }
}

- (void)setAndPersistTimeSinceLastMessage {
    NSDate *timeSinceLastMessage = [NSDate new];
    [self.triggerController timeSinceLastMessage:timeSinceLastMessage];
    NSString *stringTimeSinceLastMessage = [[NSDateFormatter iso8601DateFormatter]
                                            stringFromDate:timeSinceLastMessage];
    [OneSignalUserDefaults.initShared saveStringForKey:OS_IAM_TIME_SINCE_LAST_MESSAGE_KEY
                                             withValue:stringTimeSinceLastMessage];
}

- (void)evaluateMessageDisplayQueue {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Evaluating message display queue"];
    // No IAMs are showing currently
    self.isInAppMessageShowing = false;

    if (self.messageDisplayQueue.count > 0) {
        // Show next IAM in queue
        [self displayMessage:self.messageDisplayQueue.firstObject];
        return;
    } else {
        [self hideWindow];
        // Evaulate any IAMs (could be new IAM or added trigger conditions)
        [self evaluateMessages];
    }
}

/*
 Hide the top level IAM window
 After the IAM window is hidden, iOS will automatically promote the main window
 This also re-shows the keyboard automatically if it had focus in a text input
*/
- (void)hideWindow {
    self.window.hidden = true;
}

- (void)persistInAppMessageForRedisplay:(OSInAppMessageInternal *)message {
    // If the IAM doesn't have the re display prop or is a preview IAM there is no need to save it
    if (![message.displayStats isRedisplayEnabled] || message.isPreview) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"not persisting %@",message.displayStats]];
        return;
    }

    let displayTimeSeconds = self.dateGenerator();
    message.displayStats.lastDisplayTime = displayTimeSeconds;
    [message.displayStats incrementDisplayQuantity];
    message.isTriggerChanged = false;
    message.isDisplayedInSession = true;

    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"redisplayedInAppMessages: %@", [_redisplayedInAppMessages description]]];

    // Update the data to enable future re displays
    // Avoid calling the userdefault data again
    [_redisplayedInAppMessages setObject:message forKey:message.messageId];

    [OneSignalUserDefaults.initStandard saveCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY withValue:_redisplayedInAppMessages];
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"persistInAppMessageForRedisplay: %@ \nredisplayedInAppMessages: %@", [message description], _redisplayedInAppMessages]];

    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    let redisplayedInAppMessages = [[NSMutableDictionary alloc] initWithDictionary:[standardUserDefaults getSavedCodeableDataForKey:OS_IAM_REDISPLAY_DICTIONARY defaultValue:[NSMutableDictionary new]]];

    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"persistInAppMessageForRedisplay saved redisplayedInAppMessages: %@", [redisplayedInAppMessages description]]];
}

- (void)handlePromptActions:(NSArray<NSObject<OSInAppMessagePrompt> *> *)promptActions withMessage:(OSInAppMessageInternal *)inAppMessage {
    _currentPromptAction = nil;
    for (NSObject<OSInAppMessagePrompt> *promptAction in promptActions) {
        // Don't show prompt twice
        if (!promptAction.hasPrompted) {
            _currentPromptAction = promptAction;
            break;
        }
    }

    if (_currentPromptAction) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"IAM prompt to handle: %@", [_currentPromptAction description]]];
        _currentPromptAction.hasPrompted = YES;
        [_currentPromptAction handlePrompt:^(PromptActionResult result) {
            [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"IAM prompt to handle finished accepted: %u", result]];
            if (inAppMessage.isPreview && result == LOCATION_PERMISSIONS_MISSING_INFO_PLIST) {
                [self showAlertDialogMessage:inAppMessage promptActions:promptActions];
            } else {
                [self handlePromptActions:promptActions withMessage:inAppMessage];
            }
        }];
    } else if (!_viewController) { // IAM dismissed by action
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"IAM with prompt dismissed from actionTaken"];
        _currentInAppMessage = nil;
        _currentPromptActions = nil;
        [self evaluateMessageDisplayQueue];
    }
}

- (void)showAlertDialogMessage:(OSInAppMessageInternal *)inAppMessage
                 promptActions:(NSArray<NSObject<OSInAppMessagePrompt> *> *)promptActions  {
    _currentInAppMessage = inAppMessage;
    _currentPromptActions = promptActions;

    let message = NSLocalizedString(@"Looks like this app doesn't have location services configured. Please see OneSignal docs for more information.", @"An alert message indicating that the application is not configured to use have location services.");
    let title = NSLocalizedString(@"Location Not Available", @"An alert title indicating that the location service is unavailable.");
    let okAction = NSLocalizedString(@"OK", @"Allows the user to acknowledge and dismiss the alert");
    [[OSDialogInstanceManager sharedInstance] presentDialogWithTitle:title withMessage:message withActions:nil cancelTitle:okAction withActionCompletion:^(int tappedActionIndex) {
        //completion is called on the main thread
        [self handlePromptActions:_currentPromptActions withMessage:_currentInAppMessage];
    }];
}

- (void)messageViewDidSelectAction:(OSInAppMessageInternal *)message withAction:(OSInAppMessageAction *)action {
    // Assign firstClick BOOL based on message being clicked previously or not
    action.firstClick = [message takeActionAsUnique];
    
    if (action.clickUrl)
        [self handleMessageActionWithURL:action];
    
    if (action.promptActions && action.promptActions.count > 0)
        [self handlePromptActions:action.promptActions withMessage:message];

    if (self.actionClickBlock) {
        // Any outcome sent on this callback should count as DIRECT from this IAM
        [[OSSessionManager sharedSessionManager] onDirectInfluenceFromIAMClick:message.messageId];
        self.actionClickBlock(action);
    }

    if (message.isPreview) {
        [self processPreviewInAppMessage:message withAction:action];
        return;
    }

    // The following features are for non preview IAM
    // Make sure no click, outcome, tag tracking is performed for IAM previews
    [self sendClickRESTCall:message withAction:action];
    [self sendTagCallWithAction:action];
    [self sendOutcomes:action.outcomes forMessageId:message.messageId];
}

- (void)messageViewDidDisplayPage:(OSInAppMessageInternal *)message withPageId:(NSString *)pageId {
    dispatch_async(dispatch_get_main_queue(), ^{
           [self messageViewPageImpressionRequest:message withPageId:pageId];
    });
}

- (void)messageIsNotActive:(OSInAppMessageInternal *)message {
    [self deleteInactiveMessage:message];
}

- (void)messageWillDisplay:(nonnull OSInAppMessageInternal *)message {
    [self onWillDisplayInAppMessage:message];
}

/*
* Show the developer what will happen with a non IAM preview
 */
- (void)processPreviewInAppMessage:(OSInAppMessageInternal *)message withAction:(OSInAppMessageAction *)action {
     if (action.tags)
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Tags detected inside of the action click payload, ignoring because action came from IAM preview\nTags: %@", action.tags.jsonRepresentation]];

    if (action.outcomes.count > 0) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"Outcomes detected inside of the action click payload, ignoring because action came from IAM preview: %@", [action.outcomes description]]];
    }
}

/*
* Checks if a click being available:
* 1. Redisplay is enabled and click is available within message
* 2. Click clickId should not be inside of the clickedClickIds set
*/
- (BOOL)isClickAvailable:(OSInAppMessageInternal *)message withClickId:(NSString *)clickId {
    // If IAM has redisplay the clickId may be available
    return ([message.displayStats isRedisplayEnabled] && [message isClickAvailable:clickId]) || ![_clickedClickIds containsObject:clickId];
}

- (void)sendClickRESTCall:(OSInAppMessageInternal *)message withAction:(OSInAppMessageAction *)action {
    let clickId = action.clickId;
    // If the IAM clickId exists within the cached clickedClickIds return early so the click is not tracked
    // unless that click is from an IAM with redisplay
    // Handles body, button, or image clicks
    if (![self isClickAvailable:message withClickId:clickId])
        return;
    // Add clickId to clickedClickIds
    [self.clickedClickIds addObject:clickId];
    // Track clickId per IAM
    [message addClickId:clickId];
    
    let metricsRequest = [OSRequestInAppMessageClicked withAppId:OneSignal.appId
                                                    withPlayerId:OneSignalUserManagerImpl.sharedInstance.pushSubscriptionId
                                                   withMessageId:message.messageId
                                                    forVariantId:message.variantId
                                                      withAction:action];

   [OneSignalClient.sharedClient executeRequest:metricsRequest
                                      onSuccess:^(NSDictionary *result) {
                                          NSString *successMessage = [NSString stringWithFormat:@"In App Message with id: %@, successful POST click update for click id: %@, with result: %@", message.messageId, action.clickId,  result];
                                          [OneSignalLog onesignalLog:ONE_S_LL_DEBUG message:successMessage];

                                          // Save the updated clickedClickIds since click was tracked successfully
                                          [OneSignalUserDefaults.initStandard saveSetForKey:OS_IAM_CLICKED_SET_KEY withValue:self.clickedClickIds];
                                      }
                                      onFailure:^(NSError *error) {
                                          NSString *errorMessage = [NSString stringWithFormat:@"In App Message with id: %@, failed POST click update for click id: %@, with error: %@", message.messageId, action.clickId, error];
                                          [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:errorMessage];

                                          // Remove clickId from local clickedClickIds since click was not tracked
                                          [self.clickedClickIds removeObject:action.clickId];
                                      }];
}

- (void)sendTagCallWithAction:(OSInAppMessageAction *)action {
    if (action.tags) {
        OSInAppMessageTag *tag = action.tags;
        if (tag.tagsToAdd)
            [OneSignal.User addTags:tag.tagsToAdd];
        if (tag.tagsToRemove)
            [OneSignal.User removeTags:tag.tagsToRemove];
    }
}

- (void)sendOutcomes:(NSArray<OSInAppMessageOutcome *>*)outcomes forMessageId:(NSString *) messageId {
    if (outcomes.count == 0)
        return;
    [[OSSessionManager sharedSessionManager] onDirectInfluenceFromIAMClick:messageId];
    [OneSignal sendClickActionOutcomes:outcomes];
}

/*
 This method must be called on the Main thread
 */
- (void)webViewContentFinishedLoading:(OSInAppMessageInternal *)message {
    if (!self.viewController) {
        [self evaluateMessages];
        return;
    }
    
    if (message) {
        [self sendMessageImpression:message];
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

    [self addKeySceneToWindow:self.window];

    [self.window makeKeyAndVisible];
}

// Required to display if the app is using a Scene
// See https://github.com/OneSignal/OneSignal-iOS-SDK/issues/648
- (void)addKeySceneToWindow:(UIWindow*)window {
    if (@available(iOS 13.0, *)) {
        // The below lines can be replace with this single line once Xcode 10 support is dropped
        // window.windowScene = UIApplication.sharedApplication.keyWindow.windowScene;
        UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
        id windowScene = [keyWindow performSelector:@selector(windowScene)];
        [window performSelector:@selector(setWindowScene:) withObject:windowScene];
    }
}

- (void)dynamicTriggerCompleted:(NSString *)triggerId {
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:[NSString stringWithFormat:@"messageDynamicTriggerCompleted called with triggerId: %@", triggerId]];
    [self makeRedisplayMessagesAvailableWithTriggers:@[triggerId]];
}

- (void)makeRedisplayMessagesAvailableWithTriggers:(NSArray<NSString *> *)triggerIds {
    for (OSInAppMessageInternal *message in self.messages) {
        if ([self.redisplayedInAppMessages objectForKey:message.messageId]
            && [_triggerController hasSharedTriggers:message newTriggersKeys:triggerIds]) {
            message.isTriggerChanged = YES;
        }
    }
}

#pragma mark OSTriggerControllerDelegate Methods

- (void)triggerConditionChanged {
    // We should re-evaluate all in-app messages
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Trigger condition changed"];
    [self evaluateMessages];
}

#pragma mark OSMessagingControllerDelegate Methods
- (void)onApplicationDidBecomeActive {
    // To avoid excesive message evaluation
    // we should re-evaluate all in-app messages only if it was paused by inactive
    if (_isAppInactive) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"Evaluating messages due to inactive app"];
        _isAppInactive = NO;
        [self evaluateMessages];
    }
}

#pragma mark OSPushSubscriptionObserver Methods
- (void)onOSPushSubscriptionChangedWithStateChanges:(OSPushSubscriptionStateChanges * _Nonnull)stateChanges {
    // Don't pull IAMs if the new subscription ID is nil
    if (stateChanges.to.id == nil) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"OSMessagingController onOSPushSubscriptionChangedWithStateChanges: changed to nil subscription id"];
        return;
    }
    // Don't pull IAMs if the subscription ID has not changed
    if (stateChanges.from.id != nil &&
        [stateChanges.to.id isEqualToString:stateChanges.from.id]) {
        [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"OSMessagingController onOSPushSubscriptionChangedWithStateChanges: changed to the same subscription id"];
        return;
    }

    // Pull new IAMs when the subscription id changes to a new valid subscription id
    [OneSignalLog onesignalLog:ONE_S_LL_VERBOSE message:@"OSMessagingController onOSPushSubscriptionChangedWithStateChanges: changed to new valid subscription id"];
    [self getInAppMessagesFromServer:stateChanges.to.id];
}

@end

@implementation DummyOSMessagingController

+ (OSMessagingController *)sharedInstance {return nil; }
- (instancetype)init { self = [super init]; return self; }
- (BOOL)isInAppMessagingPaused { return false; }
- (void)setInAppMessagingPaused:(BOOL)pause {}
- (void)getInAppMessagesFromServer {}
- (void)setInAppMessageClickHandler:(OSInAppMessageClickBlock)actionClickBlock {}
- (void)presentInAppMessage:(OSInAppMessageInternal *)message {}
- (void)presentInAppPreviewMessage:(OSInAppMessageInternal *)message {}
- (void)displayMessage:(OSInAppMessageInternal *)message {}
- (void)messageViewImpressionRequest:(OSInAppMessageInternal *)message {}
- (void)evaluateMessages {}
- (BOOL)shouldShowInAppMessage:(OSInAppMessageInternal *)message { return false; }
- (void)handleMessageActionWithURL:(OSInAppMessageAction *)action {}
#pragma mark Trigger Methods
- (void)addTriggers:(NSDictionary<NSString *, id> *)triggers {}
- (void)removeTriggersForKeys:(NSArray<NSString *> *)keys {}
- (void)clearTriggers {}
- (NSDictionary<NSString *, id> *)getTriggers { return @{}; }
- (id)getTriggerValueForKey:(NSString *)key { return 0; }
#pragma mark OSInAppMessageViewControllerDelegate Methods
- (void)messageViewControllerWasDismissed {}
- (void)messageViewDidSelectAction:(OSInAppMessageInternal *)message withAction:(OSInAppMessageAction *)action {}
- (void)webViewContentFinishedLoading:(OSInAppMessageInternal *)message {}
#pragma mark OSTriggerControllerDelegate Methods
- (void)triggerConditionChanged {}
- (void)dynamicTriggerCompleted:(NSString *)triggerId {}

@end
