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
#import "OSPrivacyConsentController.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalLog.h"
#import "OSRemoteParamController.h"

@implementation OSPrivacyConsentController

+ (void)setRequiresPrivacyConsent:(BOOL)required {
    OSRemoteParamController *remoteParamController = [OSRemoteParamController sharedController];

    // Already set by remote params
    if ([remoteParamController hasPrivacyConsentKey])
        return;

    if ([self requiresUserPrivacyConsent] && !required) {
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"Cannot change requiresUserPrivacyConsent() from TRUE to FALSE"];
        return;
    }

    [remoteParamController savePrivacyConsentRequired:required];
}

+ (BOOL)requiresUserPrivacyConsent {
    BOOL shouldRequireUserConsent = [OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_REQUIRES_USER_PRIVACY_CONSENT defaultValue:NO];
    // if the plist key does not exist default to true
    // the plist value specifies whether GDPR privacy consent is required for this app
    // if required and consent has not been previously granted, return false
    BOOL requiresConsent = [[[NSBundle mainBundle] objectForInfoDictionaryKey:ONESIGNAL_REQUIRE_PRIVACY_CONSENT] boolValue] ?: false;
    if (requiresConsent || shouldRequireUserConsent)
        return ![OneSignalUserDefaults.initStandard getSavedBoolForKey:GDPR_CONSENT_GRANTED defaultValue:false];
    
    return false;
}

+ (void)consentGranted:(BOOL)granted {
    [OneSignalUserDefaults.initStandard saveBoolForKey:GDPR_CONSENT_GRANTED withValue:granted];
}

+ (BOOL)getPrivacyConsent {
    // The default is the inverse of privacy consent required
    BOOL defaultValue = ![OneSignalUserDefaults.initShared getSavedBoolForKey:OSUD_REQUIRES_USER_PRIVACY_CONSENT defaultValue:NO];
    return [OneSignalUserDefaults.initStandard getSavedBoolForKey:GDPR_CONSENT_GRANTED defaultValue:defaultValue];
}

+ (BOOL)shouldLogMissingPrivacyConsentErrorWithMethodName:(NSString *)methodName {
    if ([self requiresUserPrivacyConsent]) {
        if (methodName) {
            [OneSignalLog onesignalLog:ONE_S_LL_WARN message:[NSString stringWithFormat:@"Your application has called %@ before the user granted privacy permission. Please call `consentGranted(bool)` in order to provide user privacy consent", methodName]];
        }
        return true;
    }
    
    return false;
}

@end
