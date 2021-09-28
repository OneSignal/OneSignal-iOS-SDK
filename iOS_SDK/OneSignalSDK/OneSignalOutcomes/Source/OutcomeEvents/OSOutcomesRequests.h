//
//  OSOutcomesRequests.h
//  OneSignalOutcomes
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OneSignalCore/OneSignalCore.h>
#import "OSOutcomeEvent.h"


@interface OSRequestSendOutcomesV1ToServer : OneSignalRequest
+ (instancetype _Nonnull)directWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                     appId:(NSString * _Nonnull)appId
                                deviceType:(NSNumber * _Nonnull)deviceType;

+ (instancetype _Nonnull)indirectWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                       appId:(NSString * _Nonnull)appId
                                  deviceType:(NSNumber * _Nonnull)deviceType;

+ (instancetype _Nonnull)unattributedWithOutcome:(OSOutcomeEvent * _Nonnull)outcome
                                           appId:(NSString * _Nonnull)appId
                                      deviceType:(NSNumber * _Nonnull)deviceType;
@end

@interface OSRequestSendOutcomesV2ToServer : OneSignalRequest
+ (instancetype _Nonnull)measureOutcomeEvent:(OSOutcomeEventParams * _Nonnull)outcome
                                     appId:(NSString * _Nonnull)appId
                                deviceType:(NSNumber * _Nonnull)deviceType;

@end
