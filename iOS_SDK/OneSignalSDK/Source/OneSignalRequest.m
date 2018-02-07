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

#import "OneSignalRequest.h"
#import "OneSignalHelper.h"
#import "OneSignal.h"
#import "Requests.h"
#import "OneSignalCommonDefines.h"

@implementation OneSignalRequest
- (id)init {
    if (self = [super init]) {
        self.reattemptCount = 0;
    }
    
    return self;
}

-(NSMutableURLRequest *)request {
    //build URL
    let urlString = [[SERVER_URL stringByAppendingString:API_VERSION] stringByAppendingString:self.path];
    
    let request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setHTTPMethod:httpMethodString(self.method)];
    
    switch (self.method) {
        case GET:
        case DELETE:
            [self attachQueryParametersToRequest:request withParameters:self.parameters];
            break;
        case POST:
        case PUT:
            [self attachBodyToRequest:request withParameters:self.parameters];
            break;
        default:
            break;
    }
    
    return request;
}

-(BOOL)missingAppId {
    return self.parameters[@"app_id"] == nil || [self.parameters[@"app_id"] length] == 0;
}

-(void)attachBodyToRequest:(NSMutableURLRequest *)request withParameters:(NSDictionary *)parameters {
    if (!self.parameters)
        return;
    
    //to prevent a crash, print error and return before attempting to serialize to JSON data
    if (![NSJSONSerialization isValidJSONObject:self.parameters]) {
        [OneSignal onesignal_Log:ONE_S_LL_WARN message:[NSString stringWithFormat:@"OneSignal Attempted to make a request with an invalid JSON body: %@", self.parameters]];
        return;
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:&error];
    
    request.HTTPBody = jsonData;
}

-(void)attachQueryParametersToRequest:(NSMutableURLRequest *)request withParameters:(NSDictionary *)parameters {
    if (!parameters)
        return;
    
    NSString *urlString = [request.URL absoluteString];
    
    NSString *queryString = [self queryStringForParameters:parameters];
    
    if (queryString && queryString.length > 0) {
        urlString = [urlString stringByAppendingString:@"?"];
        urlString = [urlString stringByAppendingString:queryString];
    }
    
    request.URL = [NSURL URLWithString:urlString];
}

-(NSString *)queryStringForParameters:(NSDictionary *)parameters {
    NSEnumerator *enumerator = [parameters keyEnumerator];
    id key;
    NSString *result = @"";
    while (key = [enumerator nextObject]) {
        result = [result stringByAppendingFormat:@"%@=%@&", key, [parameters objectForKey:key]];
    }
    result = [result substringToIndex:result.length - 1];
    return [result stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

@end
