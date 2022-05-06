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
#import "OneSignalInternal.h"

@implementation OneSignalMobileProvision

/**
 embedded.mobileprovision plist format:
 AppIDName, // string - TextDetective
 ApplicationIdentifierPrefix[],  // [ string - 66PK3K3KEV ]
 CreationData, // date - 2013-01-17T14:18:05Z
 DeveloperCertificates[], // [ data ]
 Entitlements {
 application-identifier // string - 66PK3K3KEV.com.blindsight.textdetective
 get-task-allow // true or false
 keychain-access-groups[] // [ string - 66PK3K3KEV.* ]
 },
 ExpirationDate, // date - 2014-01-17T14:18:05Z
 Name, // string - Barrierefreikommunizieren (name assigned to the provisioning profile used)
 ProvisionedDevices[], // [ string.... ]
 TeamIdentifier[], // [string - HHBT96X2EX ]
 TeamName, // string - The Blindsight Corporation
 TimeToLive, // integer - 365
 UUID, // string - 79F37E8E-CC8D-4819-8C13-A678479211CE
 Version, // integer - 1
 ProvisionsAllDevices // true or false  ***NB: not sure if this is where this is
 
 */

+ (NSDictionary*) getProvision {
    static NSDictionary* provision = nil;
    if (!provision) {
        // iphoneos & iphonesimulator provisioning file is embedded.mobileprovision
        NSString *provisioningPath = [[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
        
        // If embedded.mobileprovision not found, try Mac Catalyst bundle struct and unique filename
        if (!provisioningPath) {
            NSString *bundleURL = [[NSBundle mainBundle] bundleURL].absoluteString;
            provisioningPath = [[[bundleURL componentsSeparatedByString:@"file://"] objectAtIndex:1] stringByAppendingString:@"Contents/embedded.provisionprofile"];
        }
        
        // NSISOLatin1 keeps the binary wrapper from being parsed as unicode and dropped as invalid
        NSString *binaryString = [NSString stringWithContentsOfFile:provisioningPath encoding:NSISOLatin1StringEncoding error:NULL];
        if (!binaryString)
            return nil;
        
        NSScanner *scanner = [NSScanner scannerWithString:binaryString];
        BOOL ok = [scanner scanUpToString:@"<plist" intoString:nil];
        if (!ok) {
            [self logInvalidProvisionError:@"unable to find beginning of plist"];
            return UIApplicationReleaseUnknown;
        }
        NSString *plistString;
        ok = [scanner scanUpToString:@"</plist>" intoString:&plistString];
        if (!ok) {
            [self logInvalidProvisionError:@"unable to find end of plist"];
            return UIApplicationReleaseUnknown;
        }
        plistString = [NSString stringWithFormat:@"%@</plist>",plistString];
        // juggle latin1 back to utf-8!
        NSData *plistdata_latin1 = [plistString dataUsingEncoding:NSISOLatin1StringEncoding];
        //        plistString = [NSString stringWithUTF8String:[plistdata_latin1 bytes]];
        //        NSData *plistdata2_latin1 = [plistString dataUsingEncoding:NSISOLatin1StringEncoding];
        NSError *error = nil;
        provision = [NSPropertyListSerialization propertyListWithData:plistdata_latin1 options:NSPropertyListImmutable format:NULL error:&error];
        if (error) {
            [self logInvalidProvisionError:[NSString stringWithFormat:@"error parsing extracted plist - %@",error]];
            return nil;
        }
    }
    return provision;
}

+ (void)logInvalidProvisionError:(NSString *)message {
    [OneSignal onesignalLog:ONE_S_LL_ERROR message:message];
}

+ (UIApplicationReleaseMode) releaseMode {
    NSDictionary *entitlements = nil;
    NSDictionary *provision = [self getProvision];
    if (provision) {
        [OneSignal onesignalLog:ONE_S_LL_DEBUG message:[NSString stringWithFormat:@"provision: %@", provision]];
        entitlements = [provision objectForKey:@"Entitlements"];
    }
    else
        [OneSignal onesignalLog:ONE_S_LL_DEBUG message:@"provision not found"];
              
    if (!provision) {
        // failure to read other than it simply not existing
        return UIApplicationReleaseUnknown;
    }
    else if (![provision count]) {
#if TARGET_IPHONE_SIMULATOR
        return UIApplicationReleaseSim;
#else
        return UIApplicationReleaseAppStore;
#endif
    }
    else if ([[provision objectForKey:@"ProvisionsAllDevices"] boolValue]) {
        // enterprise distribution contains ProvisionsAllDevices - true
        return UIApplicationReleaseEnterprise;
    }
    else if ([@"development" isEqualToString: entitlements[@"aps-environment"]])
        return UIApplicationReleaseDev;
    else {
        // app store contains no UDIDs (if the file exists at all?)
        return UIApplicationReleaseAppStore;
    }
}

@end
