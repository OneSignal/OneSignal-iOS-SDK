/**
 * Modified MIT License
 *
 * Copyright 2018 OneSignal
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

#import "OSMessagingControllerOverrider.h"
#import "OSMessagingController.h"
#import "OneSignalSelectorHelpers.h"
#import "TestHelperFunctions.h"
#import "NSTimerOverrider.h"
#import "OSTriggerController.h"
#import "OneSignalClientOverrider.h"
#import "OSRequests.h"
#import "OneSignalHelper.h"
#import "OSMessagingController.h"

// The displayMessage method is private, we'll expose it here
@interface OSMessagingController ()
@property (strong, nonatomic, nonnull) NSArray <OSInAppMessageInternal *> *messages;
@property (strong, nonatomic, nonnull) OSTriggerController *triggerController;
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *seenInAppMessages;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessageInternal *> *messageDisplayQueue;
@property (strong, nonatomic, nonnull) NSMutableDictionary <NSString *, OSInAppMessageInternal *> *redisplayedInAppMessages;
@property (strong, nonatomic, nonnull) NSMutableSet <NSString *> *clickedClickIds;
@property (nonatomic, readwrite) NSTimeInterval (^dateGenerator)(void);
@property (nonatomic, nullable) NSObject<OSInAppMessagePrompt>*currentPromptAction;
@end


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation OSMessagingController (Tests)
#pragma clang diagnostic pop
- (void)resetState {
    self.messages = @[];
    self.redisplayedInAppMessages = [NSMutableDictionary new];
    self.triggerController = [OSTriggerController new];
    self.triggerController.delegate = self;
    self.messageDisplayQueue = [NSMutableArray new];
    self.clickedClickIds = [NSMutableSet new];
    self.isInAppMessageShowing = false;
    self.currentPromptAction = nil;
}

- (void)setLastTimeGenerator:(NSTimeInterval(^)(void))dateGenerator {
    self.dateGenerator = dateGenerator;
}

- (NSArray<OSInAppMessageInternal *> *)getInAppMessages {
    return self.messages;
}

- (NSMutableDictionary <NSString *, OSInAppMessageInternal *> *)getRedisplayedInAppMessages {
    return self.redisplayedInAppMessages;
}

- (NSMutableArray<OSInAppMessageInternal *> *)getDisplayedMessages {
    return self.messageDisplayQueue;
}

@end

@implementation OSMessagingControllerOverrider

+ (void)load {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wundeclared-selector"
    injectSelector(
        [OSMessagingController class],
        @selector(showMessage:),
        [OSMessagingControllerOverrider class],
        @selector(overrideShowMessage:)
    );
    injectSelector(
        [OSMessagingController class],
        @selector(webViewContentFinishedLoading:),
        [OSMessagingControllerOverrider class],
        @selector(overrideWebViewContentFinishedLoading:)
    );
    #pragma clang diagnostic pop
}

- (void)overrideShowMessage:(OSInAppMessageInternal *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        let viewController = [[OSInAppMessageViewController alloc] initWithMessage:message delegate:OSMessagingController.sharedInstance];
        [viewController viewDidLoad];
        [OSMessagingController.sharedInstance webViewContentFinishedLoading:message];
    });
}

- (void)overrideWebViewContentFinishedLoading:(OSInAppMessageInternal *)message {
    if (message) {
        [OSMessagingController.sharedInstance messageViewImpressionRequest:message];
    }
}

+ (void)dismissCurrentMessage {
    [OSMessagingController.sharedInstance messageViewControllerWasDismissed: self.messageDisplayQueue.firstObject displayed:YES];
}

+ (BOOL)isInAppMessageShowing {
    return OSMessagingController.sharedInstance.isInAppMessageShowing;
}

+ (NSArray *)messageDisplayQueue {
    return [OSMessagingController.sharedInstance getDisplayedMessages];
}

+ (NSMutableDictionary <NSString *, OSInAppMessageInternal *> *)messagesForRedisplay {
    return [OSMessagingController.sharedInstance getRedisplayedInAppMessages];
}

+ (void)setMessagesForRedisplay:(NSMutableDictionary <NSString *, OSInAppMessageInternal *> *)messagesForRedisplay {
    [OSMessagingController.sharedInstance setRedisplayedInAppMessages:messagesForRedisplay];
}

+ (void)setSeenMessages:(NSMutableSet <NSString *> *)seenMessages {
    [OSMessagingController.sharedInstance setSeenInAppMessages:seenMessages];
}

+ (void)setMockDateGenerator:(NSTimeInterval (^)(void))testDateGenerator {
    [OSMessagingController.sharedInstance setLastTimeGenerator:testDateGenerator];
}

@end
