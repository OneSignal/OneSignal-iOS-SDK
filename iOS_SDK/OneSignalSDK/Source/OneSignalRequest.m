//
//  OneSignalRequest.m
//  OneSignal
//
//  Created by Brad Hesse on 12/19/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import "OneSignalRequest.h"
#import "OneSignalHelper.h"
#import "Requests.h"

#define API_VERSION @"api/v1/"
#define SERVER_URL @"https://onesignal.com/"

@implementation OneSignalRequest
- (id)init {
    self = [super init];
    
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
    
    NSLog(@"BUILT %@ HTTP REQUEST: \nURL: %@\nMETHOD: %@\nPARAMETERS: %@\nHEADER FIELDS: %@", NSStringFromClass([self class]), request.URL.absoluteString, request.HTTPMethod, self.parameters, request.allHTTPHeaderFields);
    
    return request;
}

-(BOOL)hasAppId {
    return self.parameters[@"app_id"] != nil && [self.parameters[@"app_id"] length] > 0;
}

-(void)attachBodyToRequest:(NSMutableURLRequest *)request withParameters:(NSDictionary *)parameters {
    if (!self.parameters)
        return;
    
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
