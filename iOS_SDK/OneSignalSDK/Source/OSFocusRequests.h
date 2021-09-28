//
//  OSFocusRequests.h
//  OneSignal
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import "OSFocusInfluenceParam.h"
#import <OneSignalCore/OneSignalCore.h>

@interface OSRequestOnFocus : OneSignalRequest
+ (instancetype _Nonnull)withUserId:(NSString * _Nonnull)userId
                              appId:(NSString * _Nonnull)appId
                         activeTime:(NSNumber * _Nonnull)activeTime
                            netType:(NSNumber * _Nonnull)netType
                         deviceType:(NSNumber * _Nonnull)deviceType
                    influenceParams:(NSArray<OSFocusInfluenceParam *> * _Nonnull)influenceParams;
@end
