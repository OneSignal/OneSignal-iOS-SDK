//
//  AppDelegate.h
//  OneSignalDevAppClip
//
//  Created by Elliot Mawby on 7/21/20.
//  Copyright © 2020 OneSignal. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OneSignalFramework/OneSignalFramework.h>

// TODO: Add subscription observer
@interface AppDelegate : UIResponder <UIApplicationDelegate, OSNotificationPermissionObserver>

@property (strong, nonatomic) UIWindow *window;

+ (NSString*)getOneSignalAppId;
+ (void) setOneSignalAppId:(NSString*)onesignalAppId;

@end


