//
//  OneSignalExtensionRequests.h
//  OneSignalExtension
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <OneSignalCore/OneSignalCore.h>

@interface OSRequestReceiveReceipts : OneSignalRequest
+ (instancetype _Nonnull)withPlayerId:(NSString * _Nullable)playerId notificationId:(NSString * _Nonnull)notificationId appId:(NSString * _Nonnull)appId;
@end
