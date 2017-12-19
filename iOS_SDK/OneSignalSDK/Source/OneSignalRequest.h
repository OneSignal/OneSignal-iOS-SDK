//
//  OneSignalRequest.h
//  OneSignal
//
//  Created by Brad Hesse on 12/19/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {GET, POST, HEAD, PUT, DELETE, OPTIONS, CONNECT, TRACE} HTTPMethod;
#define httpMethodString(enum) [@[@"GET", @"POST", @"HEAD", @"PUT", @"DELETE", @"OPTIONS", @"CONNECT", @"TRACE"] objectAtIndex:enum]


#ifndef OneSignalRequest_h
#define OneSignalRequest_h

@interface OneSignalRequest : NSObject

@property (nonatomic) HTTPMethod method;
@property (nonatomic, nonnull) NSString *path;
@property (nonatomic, nullable) NSDictionary *parameters;
-(NSMutableURLRequest * _Nonnull )request;
-(BOOL)hasAppId;
@end

#endif
