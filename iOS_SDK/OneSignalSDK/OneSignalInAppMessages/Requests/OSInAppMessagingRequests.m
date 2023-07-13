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
#import <Foundation/Foundation.h>
#import "OSInAppMessagingRequests.h"

@implementation OSRequestGetInAppMessages
+ (instancetype _Nonnull)withSubscriptionId:(NSString * _Nonnull)subscriptionId {
    let request = [OSRequestGetInAppMessages new];
    request.method = GET;
    NSString *appId = [OneSignalConfigManager getAppId];
    request.path = [NSString stringWithFormat:@"apps/%@/subscriptions/%@/iams", appId, subscriptionId];
    return request;
}
@end

@implementation OSRequestInAppMessageViewed
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                      withPlayerId:(NSString * _Nonnull)playerId
                     withMessageId:(NSString * _Nonnull)messageId
                      forVariantId:(NSString *)variantId {
    let request = [OSRequestInAppMessageViewed new];

    request.parameters = @{
       @"device_type": @0,
       @"player_id": playerId,
       @"app_id": appId,
       @"variant_id": variantId
    };

    request.method = POST;
    request.path = [NSString stringWithFormat:@"in_app_messages/%@/impression", messageId];

    return request;
}
@end

@implementation OSRequestInAppMessagePageViewed
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                      withPlayerId:(NSString * _Nonnull)playerId
                     withMessageId:(NSString * _Nonnull)messageId
                        withPageId:(NSString * _Nonnull)pageId
                      forVariantId:(NSString *)variantId {
    let request = [OSRequestInAppMessagePageViewed new];

    request.parameters = @{
       @"device_type": @0,
       @"player_id": playerId,
       @"app_id": appId,
       @"variant_id": variantId,
       @"page_id": pageId
    };

    request.method = POST;
    request.path = [NSString stringWithFormat:@"in_app_messages/%@/pageImpression", messageId];

    return request;
}
@end

@implementation OSRequestInAppMessageClicked
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                      withPlayerId:(NSString * _Nonnull)playerId
                     withMessageId:(NSString * _Nonnull)messageId
                      forVariantId:(NSString * _Nonnull)variantId
                     withAction:(OSInAppMessageClickResult * _Nonnull)action {
    let request = [OSRequestInAppMessageClicked new];

    request.parameters = @{
       @"app_id": appId,
       @"device_type": @0,
       @"player_id": playerId,
       @"click_id": action.clickId ?: @"",
       @"variant_id": variantId,
       @"first_click": @(action.firstClick)
    };

    request.method = POST;
    request.path = [NSString stringWithFormat:@"in_app_messages/%@/click", messageId];

    return request;
}
@end

@implementation OSRequestLoadInAppMessageContent
+ (instancetype _Nonnull)withAppId:(NSString * _Nonnull)appId
                     withMessageId:(NSString * _Nonnull)messageId
                     withVariantId:(NSString * _Nonnull)variantId {
    let request = [OSRequestLoadInAppMessageContent new];

    request.method = GET;
    request.parameters = @{@"app_id": appId};
    request.path = [NSString stringWithFormat:@"in_app_messages/%@/variants/%@/html", messageId, variantId];
    request.disableLocalCaching = true;

    return request;
}
@end

@implementation OSRequestLoadInAppMessagePreviewContent

+ (instancetype)withAppId:(NSString *)appId previewUUID:(NSString *)previewUUID {
    let request = [OSRequestLoadInAppMessagePreviewContent new];

    request.method = GET;
    request.parameters = @{
      @"preview_id": previewUUID,
      @"app_id": appId
    };

    request.path = @"in_app_messages/device_preview";
    request.disableLocalCaching = true;
    
    return request;
}
@end
