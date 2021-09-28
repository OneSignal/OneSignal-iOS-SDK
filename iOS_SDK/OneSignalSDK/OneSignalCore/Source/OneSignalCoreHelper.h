//
//  OneSignalCoreHelper.h
//  OneSignalCore
//
//  Created by Elliot Mawby on 9/28/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

@interface OneSignalCoreHelper : NSObject
// Threading
+ (void)runOnMainThread:(void(^)())block;
+ (void)dispatch_async_on_main_queue:(void(^)())block;
+ (void)performSelector:(SEL)aSelector onMainThreadOnObject:(id)targetObj withObject:(id)anArgument afterDelay:(NSTimeInterval)delay;

+ (NSString*)hashUsingSha1:(NSString*)string;
+ (NSString*)hashUsingMD5:(NSString*)string;
+ (NSString*)trimURLSpacing:(NSString*)url;
@end
