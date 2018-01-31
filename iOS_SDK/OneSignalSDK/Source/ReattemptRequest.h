//
//  ReattemptRequest.h
//  OneSignal
//
//  Created by Brad Hesse on 1/31/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignal.h"
#import "OneSignalHelper.h"
#import "OneSignalRequest.h"

@interface ReattemptRequest : NSObject

@property (strong, nonatomic) OneSignalRequest *request;
@property (nonatomic) OSResultSuccessBlock successBlock;
@property (nonatomic) OSFailureBlock failureBlock;

+(instancetype)withRequest:(OneSignalRequest *)request successBlock:(OSResultSuccessBlock)success failureBlock:(OSFailureBlock)failure;

@end
