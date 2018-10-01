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
#import "OneSignalDialogController.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSDialogRequest : NSObject

@property (strong, nonatomic, nonnull) NSString *title;
@property (strong, nonatomic, nonnull) NSString *message;
@property (strong, nonatomic, nullable) NSString *actionTitle;
@property (strong, nonatomic, nonnull) NSString *cancelTitle;
@property (nonatomic, nullable) OSDialogActionCompletion completion;

- (instancetype _Nonnull)initWithTitle:(NSString * _Nonnull)title withMessage:(NSString * _Nonnull)message withActionTitle:(NSString * _Nullable)actionTitle withCancelTitle:(NSString * _Nonnull)cancelTitle withCompletion:(OSDialogActionCompletion _Nullable)completion;

@end

NS_ASSUME_NONNULL_END
