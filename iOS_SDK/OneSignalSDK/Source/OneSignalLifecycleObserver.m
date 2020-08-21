/**
Modified MIT License

Copyright 2020 OneSignal

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
#import "OneSignalLifecycleObserver.h"
#import "OneSignal.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalTracker.h"
#import "OneSignalLocation.h"
#import "OSMessagingController.h"
#import "UIApplication+OneSignal.h"

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
    if ([UIApplication isAppUsingUIScene]) {
        [self registerLifecycleObserverAsUIScene];
    } else {
        [self registerLifecycleObserverAsUIApplication];
    }
}

+ (void)registerLifecycleObserverAsUIScene {
    if (@available(iOS 13.0, *)) {
        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"registering for Scene Lifecycle notifications"];
        [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(didEnterBackground) name:@"UISceneDidEnterBackgroundNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(didBecomeActive) name:@"UISceneDidActivateNotification" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:[OneSignalLifecycleObserver sharedInstance] selector:@selector(willResignActive) name:@"UISceneWillDeactivateNotification" object:nil];
    }
}

+ (void)registerLifecycleObserverAsUIApplication {
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
    
    if ([OneSignal appId]) {
        [OneSignalTracker onFocus:NO];
        [OneSignalLocation onFocus:YES];
        [[OSMessagingController sharedInstance] onApplicationDidBecomeActive];
    }
}

- (void)willResignActive {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"application/scene willResignActive"];
    
    if ([OneSignal appId])
        [OneSignalTracker onFocus:YES];
}

- (void)didEnterBackground {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"application/scene didEnterBackground"];
    
    if ([OneSignal appId])
        [OneSignalLocation onFocus:NO];
}

- (void)dealloc {
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"lifecycle observer deallocated"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
