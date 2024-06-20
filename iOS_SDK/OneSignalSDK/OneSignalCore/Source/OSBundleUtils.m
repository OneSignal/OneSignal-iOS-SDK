//
//  OSBundleUtils.m
//  OneSignalCore
//
//  Created by Elliot Mawby on 6/17/24.
//  Copyright © 2024 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSBundleUtils.h"
@implementation OSBundleUtils

+ (BOOL)isAppUsingUIScene {
    if (@available(iOS 13.0, *)) {
        return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"] != nil;
    }
    return NO;
}

@end
