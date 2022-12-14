//
//  OneSignalWebViewManager.m
//  OneSignalNotifications
//
//  Created by Elliot Mawby on 11/3/22.
//  Copyright © 2022 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalWebViewManager.h"

@implementation OneSignalWebViewManager : NSObject

OneSignalWebView *_webVC;
+ (OneSignalWebView * _Nonnull)webVC {
    if (!_webVC) {
        _webVC = [[OneSignalWebView alloc] init];
    }
    return _webVC;
}

+ (void)displayWebView:(NSURL *_Nonnull)url {
    [self webVC].url = url;
    [[self webVC] showInApp];
}


@end
