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
#import "Requests.h"
#import "OneSignalHelper.h"
#import "OSMessagingController.h"

// The displayMessage method is private, we'll expose it here
@interface OSMessagingController ()
@property (strong, nonatomic, nonnull) NSArray <OSInAppMessage *> *messages;
@property (strong, nonatomic, nonnull) OSTriggerController *triggerController;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessage *> *messageDisplayQueue;
@end

@implementation OSMessagingController (Tests)

- (void)resetState {
    self.messages = @[];
    self.triggerController = [OSTriggerController new];
    self.triggerController.delegate = self;
    self.messageDisplayQueue = [NSMutableArray new];
}

@end

@implementation OSMessagingControllerOverrider

static NSMutableArray<OSInAppMessage *> *_displayedMessages;

+ (void)load {
    injectToProperClass(@selector(overrideDisplayMessage:), @selector(displayMessage:), @[], [OSMessagingControllerOverrider class], [OSMessagingController class]);
    
    _displayedMessages = [NSMutableArray new];
}

- (void)overrideDisplayMessage:(OSInAppMessage *)message {
    [_displayedMessages addObject:message];
    
    [OSMessagingController.sharedInstance messageViewImpressionRequest:message];
}

+ (void)reset {
    [_displayedMessages removeAllObjects];
}

+(NSArray *)messageDisplayQueue {
    return _displayedMessages;
}

+(void)setMessageDisplayQueue:(NSArray *)displayedMessages {
    _displayedMessages = [displayedMessages mutableCopy];
}

@end
