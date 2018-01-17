//
//  OneSignalClientOverrider.h
//  OneSignal
//
//  Created by Brad Hesse on 12/19/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

//when mocking a networking request with a delay, this setting determines how long to delay the completion block for
#define EXECUTION_DELAY 0.01

@interface OneSignalClientOverrider : NSObject
+(void)reset:(XCTestCase*)testInstance;
+(void)setLastHTTPRequest:(NSDictionary*)value;
+(NSDictionary*)lastHTTPRequest;
+(int)networkRequestCount;
+(void)setLastUrl:(NSString*)value;
+(NSString*)lastUrl;
+(void)setShouldExecuteInstantaneously:(BOOL)instant;
+ (dispatch_queue_t)getHTTPQueue;
@end

