/**
 * Modified MIT License
 *
 * Copyright 2019 OneSignal
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
#import "OSFocusCallParams.h"

@implementation OSFocusCallParams

- (id)initWithParamsAppId:(NSString *)appId userId:(NSString *)userId emailUserId:(NSString *)emailUserId emailAuthToken:(NSString *)emailAuthToken netType:(NSNumber *)netType timeElapsed:(NSTimeInterval)timeElapsed notificationIds:(NSArray *)notificationIds direct:(BOOL)direct {
    _appId = appId;
    _userId = userId;
    _emailUserId = emailUserId;
    _emailAuthToken = emailAuthToken;
    _netType = netType;
    _timeElapsed = timeElapsed;
    _notificationIds = notificationIds;
    _direct = direct;
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"OSFocusCallParams appId: %@ userId: %@ emailUserId: %@ emailAuthToken: %@ netType: %@ timeElapsed: %f notificationIds: %@ isDirect: %@", _appId, _userId, _emailUserId, _emailAuthToken, _netType, _timeElapsed, _notificationIds, _direct ? @"YES" : @"NO"];
}
@end
