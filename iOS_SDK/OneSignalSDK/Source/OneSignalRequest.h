/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "OneSignalCommonDefines.h"


#ifndef OneSignalRequest_h
#define OneSignalRequest_h

@interface OneSignalRequest : NSObject

@property (nonatomic) BOOL disableLocalCaching;
@property (nonatomic) HTTPMethod method;
@property (strong, nonatomic, nonnull) NSString *path;
@property (strong, nonatomic, nullable) NSDictionary *parameters;
@property (nonatomic) int reattemptCount;
@property (nonatomic) BOOL dataRequest; //false for JSON based requests
-(BOOL)missingAppId; //for requests that don't require an appId parameter, the subclass should override this method and return false
-(NSMutableURLRequest * _Nonnull )urlRequest;

@end

#endif
