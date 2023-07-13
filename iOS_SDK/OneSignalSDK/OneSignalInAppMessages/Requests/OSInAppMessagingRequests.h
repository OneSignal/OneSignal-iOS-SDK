/*
 Modified MIT License

 Copyright 2021 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <OneSignalCore/OneSignalCore.h>
#import "OSInAppMessageClickResult.h"

@interface OSRequestGetInAppMessages : OneSignalRequest
+ (instancetype _Nonnull)withSubscriptionId:(NSString * _Nonnull)subscriptionId;
@end

@interface OSRequestInAppMessageViewed : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withPlayerId:(NSString * _Nonnull)playerId withMessageId:(NSString * _Nonnull)messageId forVariantId:(NSString * _Nonnull)variantId;
@end

@interface OSRequestInAppMessagePageViewed : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withPlayerId:(NSString * _Nonnull)playerId withMessageId:(NSString * _Nonnull)messageId withPageId:(NSString * _Nonnull)pageId forVariantId:(NSString * _Nonnull)variantId;
@end

@interface OSRequestLoadInAppMessageContent : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId withMessageId:(NSString * _Nonnull)messageId withVariantId:(NSString * _Nonnull)variant;
@end

@interface OSRequestLoadInAppMessagePreviewContent : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId previewUUID:(NSString * _Nonnull)previewUUID;
@end

@interface OSRequestInAppMessageClicked : OneSignalRequest
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                      withPlayerId:(NSString * _Nonnull)playerId
                     withMessageId:(NSString * _Nonnull)messageId
                      forVariantId:(NSString * _Nonnull)variantId
                     withAction:(OSInAppMessageClickResult * _Nonnull)action;
@end
