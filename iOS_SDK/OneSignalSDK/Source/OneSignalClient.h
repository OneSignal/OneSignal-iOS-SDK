//
//  OneSignalClient.h
//  OneSignal
//
//  Created by Brad Hesse on 12/19/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalHelper.h"
#import "OneSignalRequest.h"

#ifndef OneSignalClient_h
#define OneSignalClient_h

@interface OneSignalClient : NSObject
+ (OneSignalClient *)sharedClient;
- (void)executeRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
- (void)executeSynchronousRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock;
@end

#endif
