/*
 Modified MIT License

 Copyright 2022 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "OSNetworkingUtils.h"
#import "OneSignalReachability.h"

@implementation OSNetworkingUtils

+ (NSNumber *)getNetType {
    OneSignalReachability* reachability = [OneSignalReachability reachabilityForInternetConnection];
    NetworkStatus status = [reachability currentReachabilityStatus];
    if (status == ReachableViaWiFi)
        return @0;
    return @1;
}

+ (OSResponseStatusType)getResponseStatusType:(NSInteger)statusCode {
    if (statusCode == 400 || statusCode == 402) {
        return OSResponseStatusInvalid;
    } else if (statusCode == 401 || statusCode == 403) {
        return OSResponseStatusUnauthorized;
    } else if (statusCode == 404 || statusCode == 410) {
        return OSResponseStatusMissing;
    } else if (statusCode == 409) {
        return OSResponseStatusConflict;
    } else {
        return OSResponseStatusRetryable;
    }
}

@end
