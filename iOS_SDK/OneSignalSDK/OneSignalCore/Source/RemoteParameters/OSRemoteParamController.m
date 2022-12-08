/**
Modified MIT License

Copyright 2020 OneSignal

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
#import "OSRemoteParamController.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalUserDefaults.h"
#import "OSPrivacyConsentController.h"
//@interface OneSignal ()
//
//+ (void)startLocationSharedWithFlag:(BOOL)enable;
//
//@end

@implementation OSRemoteParamController

static OSRemoteParamController *_sharedController;
+ (OSRemoteParamController *)sharedController {
    return _sharedController;
}

- (void)saveRemoteParams:(NSDictionary *)params {
    _remoteParams = params;
    
    if ([self hasLocationKey]) {
        BOOL shared = [params[IOS_LOCATION_SHARED] boolValue];
        //[OneSignal startLocationSharedWithFlag:shared];
    }
    
    if ([self hasPrivacyConsentKey]) {
        BOOL required = [params[IOS_REQUIRES_USER_PRIVACY_CONSENT] boolValue];
        [self savePrivacyConsentRequired:required];
        [OSPrivacyConsentController setRequiresPrivacyConsent:required];
    }
}

- (BOOL)hasLocationKey {
    return _remoteParams && _remoteParams[IOS_LOCATION_SHARED];
}

- (BOOL)hasPrivacyConsentKey {
    return _remoteParams && _remoteParams[IOS_REQUIRES_USER_PRIVACY_CONSENT];
}

- (BOOL)isLocationShared {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_LOCATION_ENABLED defaultValue:YES];
}

- (void)saveLocationShared:(BOOL)shared {
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_LOCATION_ENABLED withValue:shared];
}

- (BOOL)isPrivacyConsentRequired {
    return [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_REQUIRES_USER_PRIVACY_CONSENT defaultValue:NO];
}

- (void)savePrivacyConsentRequired:(BOOL)required {
    [OneSignalUserDefaults.initShared saveBoolForKey:OSUD_REQUIRES_USER_PRIVACY_CONSENT withValue:required];
}

@end
