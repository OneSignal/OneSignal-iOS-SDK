//
//  OneSignalExtensionRequests.m
//  OneSignalExtension
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalExtensionRequests.h"
#import "OSOutcomeEvent.h"
#import "OneSignalRequest.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"
#import <stdlib.h>
#import <stdio.h>
#import <sys/types.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>

@implementation OSRequestReceiveReceipts

+ (instancetype _Nonnull)withPlayerId:(NSString *)playerId notificationId:(NSString *)notificationId appId:(NSString *)appId {
    let request = [OSRequestReceiveReceipts new];
    
    request.parameters = @{@"app_id": appId,
                           @"player_id": playerId ?: [NSNull null],
                           @"device_type": @0};
    request.method = PUT;
    request.path = [NSString stringWithFormat:@"notifications/%@/report_received", notificationId];

    return request;
}

@end
