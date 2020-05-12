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

#import <Foundation/Foundation.h>
#import "OSInAppMessage.h"
#import "OSInAppMessageViewController.h"
#import "OneSignal.h"
#import "OSTriggerController.h"

NS_ASSUME_NONNULL_BEGIN

@protocol OSMessagingControllerDelegate <NSObject>

- (void)onApplicationDidBecomeActive;

@end

@interface OSMessagingController : NSObject <OSInAppMessageViewControllerDelegate, OSTriggerControllerDelegate, OSMessagingControllerDelegate, UIAlertViewDelegate>

@property (class, readonly) BOOL isInAppMessagingPaused;

// Tracks when an IAM is showing or not, useful for deciding to show or hide an IAM
// Toggled in two places dismissing/displaying
@property (nonatomic) BOOL isInAppMessageShowing;

+ (OSMessagingController *)sharedInstance;
+ (void)removeInstance;
- (void)presentInAppMessage:(OSInAppMessage *)message;
- (void)presentInAppPreviewMessage:(OSInAppMessage *)message;
- (void)updateInAppMessagesFromCache;
- (void)updateInAppMessagesFromOnSession:(NSArray<OSInAppMessage *> *)newMessages;
- (void)messageViewImpressionRequest:(OSInAppMessage *)message;

- (BOOL)isInAppMessagingPaused;
- (void)setInAppMessagingPaused:(BOOL)pause;
- (void)addTriggers:(NSDictionary<NSString *, id> *)triggers;
- (void)removeTriggersForKeys:(NSArray<NSString *> *)keys;
- (NSDictionary<NSString *, id> *)getTriggers;
- (id)getTriggerValueForKey:(NSString *)key;

- (void)setInAppMessageClickHandler:(OSHandleInAppMessageActionClickBlock)actionClickBlock;

@end

@interface DummyOSMessagingController : OSMessagingController @end

NS_ASSUME_NONNULL_END
