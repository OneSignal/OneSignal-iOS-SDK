//
//  OneSignalSetEmailParameters.h
//  OneSignal
//
//  Created by Brad Hesse on 2/1/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignal.h"

@interface OneSignalSetEmailParameters : NSObject

+ (instancetype)withEmail:(NSString *)email withAuthToken:(NSString *)authToken withSuccess:(OSResultSuccessBlock)success withFailure:(OSFailureBlock)failure;

@property (strong, nonatomic) NSString *email;
@property (strong, nonatomic) NSString *authToken;
@property (nonatomic) OSResultSuccessBlock successBlock;
@property (nonatomic) OSFailureBlock failureBlock;

@end
