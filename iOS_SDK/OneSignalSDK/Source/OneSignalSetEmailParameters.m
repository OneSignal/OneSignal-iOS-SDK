//
//  OneSignalSetEmailParameters.m
//  OneSignal
//
//  Created by Brad Hesse on 2/1/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import "OneSignalSetEmailParameters.h"

@implementation OneSignalSetEmailParameters

+ (instancetype)withEmail:(NSString *)email withAuthToken:(NSString *)authToken withSuccess:(OSResultSuccessBlock)success withFailure:(OSFailureBlock)failure {
    OneSignalSetEmailParameters *parameters = [OneSignalSetEmailParameters new];
    
    parameters.email = email;
    parameters.authToken = authToken;
    parameters.successBlock = success;
    parameters.failureBlock = failure;
    
    return parameters;
}

@end
