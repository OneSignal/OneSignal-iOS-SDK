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

#import "OSLocationState.h"

@interface OSUserState : NSObject

@property (strong, nonatomic, readwrite, nullable) NSString *appId;
@property (strong, nonatomic, readwrite, nullable) NSString *deviceOs;
@property (strong, nonatomic, readwrite, nullable) NSNumber *timezone;
@property (strong, nonatomic, readwrite, nullable) NSString *timezoneId;
//This property is no longer being populated with vendor id
@property (strong, nonatomic, readwrite, nullable) NSString *adId;
@property (strong, nonatomic, readwrite, nullable) NSString *sdk;
@property (strong, nonatomic, readwrite, nullable) NSString *sdkType;
@property (strong, nonatomic, readwrite, nullable) NSString *externalUserId;
@property (strong, nonatomic, readwrite, nullable) NSString *externalUserIdHash;
@property (strong, nonatomic, readwrite, nullable) NSString *deviceModel;
@property (strong, nonatomic, readwrite, nullable) NSString *gameVersion;
@property (nonatomic, readwrite) BOOL isRooted;
@property (strong, nonatomic, readwrite, nullable) NSNumber *netType;
@property (strong, nonatomic, readwrite, nullable) NSString *iOSBundle;
@property (strong, nonatomic, readwrite, nullable) NSString *language;
@property (strong, nonatomic, readwrite, nullable) NSNumber *notificationTypes;
@property (strong, nonatomic, readwrite, nullable) NSString *carrier;
@property (strong, nonatomic, readwrite, nullable) NSNumber *testType;
@property (strong, nonatomic, readwrite, nullable) NSDictionary* tags;
@property (strong, nonatomic, readwrite, nullable) OSLocationState *locationState;

- (NSDictionary *_Nonnull)toDictionary;

@end
