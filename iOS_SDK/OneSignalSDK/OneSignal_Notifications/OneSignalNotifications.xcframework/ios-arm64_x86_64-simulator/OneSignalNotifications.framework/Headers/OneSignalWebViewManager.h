//
//  OneSignalWebViewManager.h
//  OneSignalNotifications
//
//  Created by Elliot Mawby on 11/3/22.
//  Copyright © 2022 Hiptic. All rights reserved.
//

#import <OneSignalNotifications/OneSignalWebView.h>

@interface OneSignalWebViewManager : NSObject
+ (OneSignalWebView *_Nonnull)webVC;
+ (void)displayWebView:(NSURL*_Nonnull)url;
@end
