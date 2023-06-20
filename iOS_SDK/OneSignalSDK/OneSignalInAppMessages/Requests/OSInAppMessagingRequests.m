//
//  OSInAppMessagingRequests.m
//  OneSignal
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

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
