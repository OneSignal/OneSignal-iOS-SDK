//
//  OSStubInAppMessages.m
//  OneSignalCore
//
//  Created by Elliot Mawby on 6/21/23.
//  Copyright © 2023 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSInAppMessages.h"
#import "OneSignalLog.h"

@implementation OSStubInAppMessages

+ (Class<OSInAppMessages>)InAppMessages {
    return self;
}

+ (void)addClickListener:(NSObject<OSInAppMessageClickListener> * _Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)addLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> * _Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)addTrigger:(NSString * _Nonnull)key withValue:(NSString * _Nonnull)value {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)addTriggers:(NSDictionary<NSString *,NSString *> * _Nonnull)triggers {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)clearTriggers {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (BOOL)paused {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
    return true;
}

+ (void)paused:(BOOL)pause {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)removeClickListener:(NSObject<OSInAppMessageClickListener> * _Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)removeLifecycleListener:(NSObject<OSInAppMessageLifecycleListener> * _Nullable)listener {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)removeTrigger:(NSString * _Nonnull)key {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

+ (void)removeTriggers:(NSArray<NSString *> * _Nonnull)keys {
    [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:@"OneSignalInAppMessages not found. In order to use OneSignal's In App Messaging features the OneSignalInAppMessages module must be added."];
}

@end
