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
    // Replacing swizzled lifecycle selectors with notification center observers for scene based Apps
    if (@available(iOS 13.0, *)) {
        NSDictionary *sceneManifest = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIApplicationSceneManifest"];
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"registering for Scene Lifecycle notifications"];
        if (sceneManifest) {
            [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(didEnterBackground) name:UISceneDidEnterBackgroundNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(didBecomeActive) name:UISceneDidActivateNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(willResignActive) name:UISceneWillDeactivateNotification object:nil];
            return;
        }
    }
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"registering for Application Lifecycle notifications"];
    [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
}

+ (void)removeObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:[OneSignalLifecycleObserver sharedInstance]];
}
     
- (void)didBecomeActive {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"application/scene didBecomeActive"];
    
    if ([OneSignal app_id]) {
        [OneSignalTracker onFocus:NO];
        [OneSignalLocation onFocus:YES];
        [[OSMessagingController sharedInstance] onApplicationDidBecomeActive];
    }
}

- (void)willResignActive {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"application/scene willResignActive"];
    
    if ([OneSignal app_id])
        [OneSignalTracker onFocus:YES];
}

- (void)didEnterBackground {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"application/scene didEnterBackground"];
    
    if ([OneSignal app_id])
        [OneSignalLocation onFocus:NO];
}

- (void)dealloc {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"lifecycle observer deallocated"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
