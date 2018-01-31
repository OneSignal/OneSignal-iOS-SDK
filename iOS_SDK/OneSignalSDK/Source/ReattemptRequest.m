//
//  ReattemptRequest.m
//  OneSignal
//
//  Created by Brad Hesse on 1/31/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "ReattemptRequest.h"

@implementation ReattemptRequest

+(instancetype)withRequest:(OneSignalRequest *)request successBlock:(OSResultSuccessBlock)success failureBlock:(OSFailureBlock)failure {
    let reattempt = [ReattemptRequest new];
    
    reattempt.request = request;
    reattempt.successBlock = success;
    reattempt.failureBlock = failure;
    
    return reattempt;
}

@end
