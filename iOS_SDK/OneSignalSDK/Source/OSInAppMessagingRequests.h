//
//  OSInAppMessagingRequests.h
//  OneSignal
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <OneSignalCore/OneSignalCore.h>
#import "OSInAppMessageAction.h"

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
                     withAction:(OSInAppMessageAction * _Nonnull)action;
@end
