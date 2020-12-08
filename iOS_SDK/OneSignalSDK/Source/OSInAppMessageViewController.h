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
#import <UIKit/UIKit.h>
#import "OSInAppMessage.h"
#import "OSInAppMessageView.h"
#import "OSInAppMessageAction.h"
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol OSInAppMessageViewControllerDelegate <NSObject>

- (void)messageViewDidSelectAction:(OSInAppMessage *)message withAction:(OSInAppMessageAction *)action;
- (void)messageViewControllerWasDismissed;
- (void)webViewContentFinishedLoading;

@end


@interface OSInAppMessageViewController : UIViewController <OSInAppMessageViewDelegate, WKScriptMessageHandler>

@property (weak, nonatomic, nullable) id<OSInAppMessageViewControllerDelegate> delegate;
@property (strong, nonatomic, nonnull) OSInAppMessage *message;

- (instancetype _Nonnull)initWithMessage:(OSInAppMessage *)inAppMessage delegate:(id<OSInAppMessageViewControllerDelegate>)delegate;
- (void)dismissCurrentInAppMessage;

@end

NS_ASSUME_NONNULL_END
