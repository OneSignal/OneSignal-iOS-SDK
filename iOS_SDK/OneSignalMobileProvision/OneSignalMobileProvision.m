//
//  OneSignalMobileProvision.m
//  Renamed from UIApplication+BSMobileProvision.m to prevent conflicts
//
//  Created by kaolin fire on 2013-06-24.
//  Copyright (c) 2013 The Blindsight Corporation. All rights reserved.
//  Released under the BSD 2-Clause License (see LICENSE)
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "OneSignalMobileProvision.h"
#import "TargetConditionals.h"
#import "OneSignal.h"

@implementation OneSignalMobileProvision

+ (NSDictionary*)getMobileProvision {
	static NSDictionary* mobileProvision = nil;
	if (!mobileProvision) {
		NSString *provisioningPath = [[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
        if (!provisioningPath) {
			return @{};
        }

		// NSISOLatin1 keeps the binary wrapper from being parsed as unicode and dropped as invalid
		NSString *binaryString = [NSString stringWithContentsOfFile:provisioningPath encoding:NSISOLatin1StringEncoding error:NULL];
        if (!binaryString) {
			return nil;
        }

		NSScanner *scanner = [NSScanner scannerWithString:binaryString];
		BOOL ok = [scanner scanUpToString:@"<plist" intoString:nil];
        if (!ok) {
            return UIApplicationReleaseUnknown;
        }

        NSString *plistString;
		ok = [scanner scanUpToString:@"</plist>" intoString:&plistString];
		if (!ok) {
            return UIApplicationReleaseUnknown;
        }

        plistString = [NSString stringWithFormat:@"%@</plist>",plistString];
		// Juggle latin1 back to utf-8!
		NSData *plistdata_latin1 = [plistString dataUsingEncoding:NSISOLatin1StringEncoding];
        NSError *error = nil;
		mobileProvision = [NSPropertyListSerialization propertyListWithData:plistdata_latin1 options:NSPropertyListImmutable format:NULL error:&error];
		if (error) {
			NSLog(@"error parsing extracted plist - %@",error);
			return nil;
		}
	}
	return mobileProvision;
}

+ (UIApplicationReleaseMode)releaseMode {
	NSDictionary *mobileProvision = [self getMobileProvision];

	if (!mobileProvision) {
        [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:@"mobileProvision not found"];
        return UIApplicationReleaseUnknown;
    }

    [OneSignal onesignal_Log:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"mobileProvision: %@", mobileProvision]];

    if (![mobileProvision count]) {
#if TARGET_IPHONE_SIMULATOR
        return UIApplicationReleaseSim;
#else
        return UIApplicationReleaseAppStore;
#endif
	}

    // Enterprise distribution contains ProvisionsAllDevices - true
    if ([[mobileProvision objectForKey:@"ProvisionsAllDevices"] boolValue]) {
		return UIApplicationReleaseEnterprise;
    }

    // If missing ProvisionedDevices return UIApplicationReleaseAppStore
    if (![mobileProvision objectForKey:@"ProvisionedDevices"]) {
        return UIApplicationReleaseAppStore;
    }

    NSDictionary *entitlements = [mobileProvision objectForKey:@"Entitlements"];
    if (![[entitlements objectForKey:@"get-task-allow"] boolValue]) {
        return UIApplicationReleaseAdHoc;
    }

    if (entitlements[@"application-identifier"] && [entitlements[@"application-identifier"] hasSuffix:@"*"]) {
        return UIApplicationReleaseWildcard;
    } else {
        return UIApplicationReleaseDev;
    }
}

@end
