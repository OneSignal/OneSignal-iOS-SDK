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

@interface OneSignalClientOverrider : NSObject
+(void)reset:(XCTestCase*)testInstance;
+(void)setLastHTTPRequest:(NSDictionary*)value;
+(NSDictionary*)lastHTTPRequest;
+(int)networkRequestCount;
+(void)setLastUrl:(NSString*)value;
+(NSString*)lastUrl;
+(void)setShouldExecuteInstantaneously:(BOOL)instant;
+ (dispatch_queue_t)getHTTPQueue;
+(void)runBackgroundThreads;
+(NSString *)lastHTTPRequestType;
+(void)setRequiresEmailAuth:(BOOL)required;
@end

