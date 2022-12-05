//
//  AppDelegate.h
//  OneSignalDevAppClip
//
//  Created by Elliot Mawby on 7/21/20.
//  Copyright © 2020 OneSignal. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OneSignal/OneSignal.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, OSPermissionObserver, OSSubscriptionObserver>

@property (strong, nonatomic) UIWindow *window;

+ (NSString*)getOneSignalAppId;
+ (void) setOneSignalAppId:(NSString*)onesignalAppId;

@end


