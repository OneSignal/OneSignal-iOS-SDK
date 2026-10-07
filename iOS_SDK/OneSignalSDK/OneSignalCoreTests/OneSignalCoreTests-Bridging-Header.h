//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <OneSignalCore/OneSignalClient.h>

/// The client's log sites, exposed so tests can read what they print without a network round trip.
@interface OneSignalClient (LoggingTests)
- (BOOL)validRequest:(OneSignalRequest *)request;
- (void)handleJSONNSURLResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error isAsync:(BOOL)async withRequest:(OneSignalRequest *)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSClientFailureBlock)failureBlock;
@end
