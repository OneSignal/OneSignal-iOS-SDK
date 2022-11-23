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
#import "OneSignalCommonDefines.h"
#import "OneSignalLog.h"

#define HTTP_HEADER_KEY_OS_VERSION @"SDK-Version"
#define HTTP_HEADER_PREFIX_OS_VERSION @"onesignal/ios/"

@implementation OneSignalRequest

- (id)init {
    if (self = [super init]) {
        
        self.reattemptCount = 0;
        
        // sets default values that are true for most requests
        // the following parameters can be overridden by subclasses
        self.disableLocalCaching = false;
        
        // Most requests in our SDK are API requests that return JSON
        // However some requests want to load non-JSON data like HTML
        // In those cases, `dataRequest` should be true
        self.dataRequest = false;
    }
    
    return self;
}

-(NSMutableURLRequest *)urlRequest {
    //build URL
    NSString *urlString = [OS_API_SERVER_URL stringByAppendingString:self.path];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    
    for (NSString *key in self.additionalHeaders) {
        [request setValue:self.additionalHeaders[key] forHTTPHeaderField:key];
    }
    
    if (!self.dataRequest)
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    [request setValue:OS_API_ACCEPT_HEADER forHTTPHeaderField:@"Accept"];
    
    NSString *versionString = [NSString stringWithFormat:@"%@%@", HTTP_HEADER_PREFIX_OS_VERSION, ONESIGNAL_VERSION];
    [request setValue:versionString forHTTPHeaderField:HTTP_HEADER_KEY_OS_VERSION];
    
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
  if ([self.path containsString:@"apps/"]) {
    NSArray *pathComponents = [self.path componentsSeparatedByString:@"/"];
    NSUInteger x = [pathComponents indexOfObject:@"apps"] + 1; // Find the index that follows "apps" in the path
    return ([pathComponents count] <= x || [[pathComponents objectAtIndex:x] length] == 0 || [[pathComponents objectAtIndex:x] isEqual: @"(null)"]);
  }
   
  return (self.parameters[@"app_id"] == nil || [self.parameters[@"app_id"] length] == 0);
}

-(void)attachBodyToRequest:(NSMutableURLRequest *)request withParameters:(NSDictionary *)parameters {
    if (!self.parameters)
        return;
    
    //to prevent a crash, print error and return before attempting to serialize to JSON data
    if (![NSJSONSerialization isValidJSONObject:self.parameters]) {
        [OneSignalLog onesignalLog:ONE_S_LL_WARN message:[NSString stringWithFormat:@"OneSignal Attempted to make a request with an invalid JSON body: %@", self.parameters]];
        return;
    }
    
    NSError *error;
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&error];
    NSString *requestString = [[NSString alloc] initWithData:requestData encoding:NSUTF8StringEncoding];

    NSRegularExpression *eidRegex = [NSRegularExpression regularExpressionWithPattern:@"(?<=\"external_user_id\":\").*\\/.*?(?=\",|\"\\})" options:0 error:&error];
    NSArray *matches = [eidRegex matchesInString:requestString options:0 range:NSMakeRange(0, [requestString length])];

    if ([matches count] > 0) {
        NSTextCheckingResult *match = matches[0];
        NSString *matched = [requestString substringWithRange:[match range]];
        NSString *unescapedEID = [matched stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        requestString = [requestString stringByReplacingOccurrencesOfString:matched withString:unescapedEID];
    }

    request.HTTPBody = [requestString dataUsingEncoding:NSUTF8StringEncoding];
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
