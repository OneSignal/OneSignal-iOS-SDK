//
//  OneSignalLifecycleObserver.m
//  OneSignal
//
//  Created by Elliot Mawby on 7/30/20.
//  Copyright © 2020 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalLifecycleObserver.h"
#import "OneSignal.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalTracker.h"
#import "OneSignalLocation.h"
#import "OSMessagingController.h"

@implementation OneSignalLifecycleObserver

static OneSignalLifecycleObserver* _instance = nil;

+(OneSignalLifecycleObserver*) sharedInstance {
    @synchronized( _instance ) {
        if( !_instance ) {
            _instance = [[OneSignalLifecycleObserver alloc] init];
        }
    }
    
    return _instance;
}

+ (void)registerLifecycleObserver {
    // Replace swizzled lifecycle selectors with notification center observers for scene based Apps
    [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    
    if (@available(iOS 13.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(sceneDidEnterBackground) name:UISceneDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(sceneDidBecomeActive) name:UISceneDidActivateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(sceneWillResignActive) name:UISceneWillDeactivateNotification object:nil];
    }
}

+ (void)removeObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:[OneSignalLifecycleObserver sharedInstance]];
}

- (void)sceneDidBecomeActive {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"ecm sceneDidBecomeActive"];
    
    if ([OneSignal app_id]) {
        [OneSignalTracker onFocus:NO];
        [OneSignalLocation onFocus:YES];
        [[OSMessagingController sharedInstance] onApplicationDidBecomeActive];
    }
}
     
- (void)applicationDidBecomeActive {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"ecm applicationDidBecomeActive"];
    
    if ([OneSignal app_id]) {
        [OneSignalTracker onFocus:NO];
        [OneSignalLocation onFocus:YES];
        [[OSMessagingController sharedInstance] onApplicationDidBecomeActive];
    }
}

- (void)sceneWillResignActive {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"ecm sceneWillResignActive"];
    
    if ([OneSignal app_id])
            [OneSignalTracker onFocus:YES];
}

- (void)applicationWillResignActive {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"ecm applicationWillResignActive"];
    
    if ([OneSignal app_id])
            [OneSignalTracker onFocus:YES];
}

- (void)sceneDidEnterBackground {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"ecm sceneDidEnterBackground"];
    
    if ([OneSignal app_id])
        [OneSignalLocation onFocus:NO];
}

- (void)applicationDidEnterBackground {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"ecm applicationDidEnterBackground"];
    
    if ([OneSignal app_id])
        [OneSignalLocation onFocus:NO];
}

- (void)dealloc {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"lifecycle observer deallocated"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
