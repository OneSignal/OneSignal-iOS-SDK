/**
Modified MIT License

Copyright 2021 OneSignal

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


#import <Foundation/Foundation.h>
#import "OSUserState.h"

@implementation OSUserState

- (NSDictionary*)toDictionary {
    NSMutableDictionary *dataDic = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                   _appId, @"app_id",
                   _deviceOs, @"device_os",
                   _timezone, @"timezone",
                   _timezoneId, @"timezone_id",
                   _deviceType, @"device_type",
                   _adId, @"ad_id",
                   _sdk, @"sdk",
                   nil];
    
    if (_externalUserId)
        dataDic[@"external_user_id"] = _externalUserId;
    if (_externalUserIdHash)
        dataDic[@"external_user_id_auth_hash"] = _externalUserIdHash;
    if (_deviceModel)
        dataDic[@"device_model"] = _deviceModel;
    if (_gameVersion)
        dataDic[@"game_version"] = _gameVersion;
    if (self.isRooted)
        dataDic[@"rooted"] = @YES;
    
    dataDic[@"net_type"] = _netType;
    
    if (_sdk)
        dataDic[@"sdk_type"] = _sdk;
    if (_iOSBundle)
        dataDic[@"ios_bundle"] = _iOSBundle;
    if (_language)
        dataDic[@"language"] = _language;
    
    dataDic[@"notification_types"] = _notificationTypes;
    
    if (_carrier)
        dataDic[@"carrier"] = _carrier;
    if (_testType)
        dataDic[@"test_type"] = _testType;
    if (_tags)
        dataDic[@"tags"] = _tags;
    if (_locationState)
        [dataDic addEntriesFromDictionary:_locationState.toDictionary];
    
    return dataDic;
}

@end
