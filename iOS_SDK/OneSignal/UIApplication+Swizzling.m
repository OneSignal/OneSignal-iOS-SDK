/**
 * Modified MIT License
 *
 * Copyright 2016 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <UIKit/UIKit.h>

#import <objc/runtime.h>

#import "OneSignal.h"
#import "OneSignalLocation.h"
#import "OneSignalTracker.h"
#import "OneSignalHelper.h"
#import "NSObject+Extras.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static BOOL checkIfInstanceOverridesSelector(Class instance, SEL selector) {
    Class instSuperClass = [instance superclass];
    return [instance instanceMethodForSelector: selector] != [instSuperClass instanceMethodForSelector: selector];
}


static Class getClassWithProtocolInHierarchy(Class searchClass, Protocol* protocolToFind) {
    if (!class_conformsToProtocol(searchClass, protocolToFind)) {
        if ([searchClass superclass] == nil)
            return nil;
        Class foundClass = getClassWithProtocolInHierarchy([searchClass superclass], protocolToFind);
        if (foundClass)
            return foundClass;
        return searchClass;
    }
    return searchClass;
}

static void injectSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getInstanceMethod(newClass, newSel);
    IMP imp = method_getImplementation(newMeth);
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    BOOL successful = class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
    
    if (!successful) {
        class_addMethod(addToClass, newSel, imp, methodTypeEncoding);
        newMeth = class_getInstanceMethod(addToClass, newSel);
        Method orgMeth = class_getInstanceMethod(addToClass, makeLikeSel);
        method_exchangeImplementations(orgMeth, newMeth);
    }
}

//Try to find out which class to inject to
static void injectToProperClass(SEL newSel, SEL makeLikeSel, NSArray* delegateSubclasses, Class myClass, Class delegateClass) {
    
    // Find out if we should inject in delegateClass or one of its subclasses.
    //CANNOT use the respondsToSelector method as it returns TRUE to both implementing and inheriting a method
    //We need to make sure the class actually implements the method (overrides) and not inherits it to properly perform the call
    //Start with subclasses then the delegateClass
    
    for(Class subclass in delegateSubclasses)
        if(checkIfInstanceOverridesSelector(subclass, makeLikeSel)) {
            injectSelector(myClass, newSel, subclass, makeLikeSel);
            return;
        }
    
    //No subclass overrides the method, try to inject in delegate class
    injectSelector(myClass, newSel, delegateClass, makeLikeSel);
    
}

static NSArray* ClassGetSubclasses(Class parentClass) {
    
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = NULL;
    
    classes = (Class *)malloc(sizeof(Class) * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 0; i < numClasses; i++) {
        Class superClass = classes[i];
        do {
            superClass = class_getSuperclass(superClass);
        } while(superClass && superClass != parentClass);
        
        if (superClass == nil) continue;
        [result addObject:classes[i]];
    }
    
    free(classes);
    
    return result;
}

@interface OneSignal ()
+ (void)didRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)token;
+ (void) remoteSilentNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo;
+ (void) updateNotificationTypes:(int)notificationTypes;
+ (void) notificationOpened:(NSDictionary*)messageDict isActive:(BOOL)isActive;
+ (void) processLocalActionBasedNotification:(UILocalNotification*) notification identifier:(NSString*)identifier;
+ (void) setErrorNotificationType;
@end

@interface OneSignalTracker ()
+ (void)onFocus:(BOOL)toBackground;
@end

@implementation UIApplication (Swizzling)
static Class delegateClass = nil;

// Store an array of all UIAppDelegate subclasses to iterate over in cases where UIAppDelegate swizzled methods are not overriden in main AppDelegate
//But rather in one of the subclasses
static NSArray* delegateSubclasses = nil;

+(Class)delegateClass {
    return delegateClass;
}

- (void)oneSignalDidRegisterForRemoteNotifications:(UIApplication*)app deviceToken:(NSData*)inDeviceToken {
    
    if([OneSignal app_id])
        [OneSignal didRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
    
    if ([self respondsToSelector:@selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:)])
        [self oneSignalDidRegisterForRemoteNotifications:app deviceToken:inDeviceToken];
}

- (void)oneSignalDidFailRegisterForRemoteNotification:(UIApplication*)app error:(NSError*)err {
    
    if(err.code == 3000 && [(NSString*)[err.userInfo objectForKey:NSLocalizedDescriptionKey] containsString:@"no valid 'aps-environment'"]) {
        //User did not enable push notification capability
        [OneSignal setErrorNotificationType];
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"'Push Notification' capability not turned on. Make sure it is enabled by going to your Project Target -> Capability."];
    }
    
    else if([OneSignal app_id])
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat: @"Error registering for Apple push notifications. Error: %@", err]];
    
    if ([self respondsToSelector:@selector(oneSignalDidFailRegisterForRemoteNotification:error:)])
        [self oneSignalDidFailRegisterForRemoteNotification:app error:err];
}

- (void)oneSignalDidRegisterUserNotifications:(UIApplication*)application settings:(UIUserNotificationSettings*)notificationSettings {
    
    if([OneSignal app_id])
        [OneSignal updateNotificationTypes:notificationSettings.types];
    
    if ([self respondsToSelector:@selector(oneSignalDidRegisterUserNotifications:settings:)])
        [self oneSignalDidRegisterUserNotifications:application settings:notificationSettings];
}


// Notification opened! iOS 6 ONLY!
- (void)oneSignalReceivedRemoteNotification:(UIApplication*)application userInfo:(NSDictionary*)userInfo {
    
    if([OneSignal app_id])
        [OneSignal notificationOpened:userInfo isActive:[application applicationState] == UIApplicationStateActive];
    
    if ([self respondsToSelector:@selector(oneSignalReceivedRemoteNotification:userInfo:)])
        [self oneSignalReceivedRemoteNotification:application userInfo:userInfo];
}

// User Tap on Notification while app was in background - OR - Notification received (silent or not, foreground or background) on iOS 7+
- (void) oneSignalRemoteSilentNotification:(UIApplication*)application UserInfo:(NSDictionary*)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult)) completionHandler {
    
    if([OneSignal app_id]) {
    
    //Call notificationAction if app is active -> not a silent notification but rather user tap on notification
        //Unless iOS 10+ then call remoteSilentNotification instead.
    if([UIApplication sharedApplication].applicationState == UIApplicationStateActive && userInfo[@"aps"][@"alert"])
        [OneSignal notificationOpened:userInfo isActive:YES];
    else [OneSignal remoteSilentNotification:application UserInfo:userInfo];
        
    }
    
    if ([self respondsToSelector:@selector(oneSignalRemoteSilentNotification:UserInfo:fetchCompletionHandler:)]) {
        [self oneSignalRemoteSilentNotification:application UserInfo:userInfo fetchCompletionHandler:completionHandler];
        return;
    }

    //Make sure not a cold start from tap on notification (OS doesn't call didReceiveRemoteNotification)
    if ([self respondsToSelector:@selector(oneSignalReceivedRemoteNotification:userInfo:)] && ![[OneSignal valueForKey:@"coldStartFromTapOnNotification"] boolValue])
        [self oneSignalReceivedRemoteNotification:application userInfo:userInfo];
    
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void) oneSignalLocalNotificationOpened:(UIApplication*)application handleActionWithIdentifier:(NSString*)identifier forLocalNotification:(UILocalNotification*)notification completionHandler:(void(^)()) completionHandler {
    
    if([OneSignal app_id])
        [OneSignal processLocalActionBasedNotification:notification identifier:identifier];
    
    if ([self respondsToSelector:@selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:)])
        [self oneSignalLocalNotificationOpened:application handleActionWithIdentifier:identifier forLocalNotification:notification completionHandler:completionHandler];

    completionHandler();
}

- (void)oneSignalLocalNotificationOpened:(UIApplication*)application notification:(UILocalNotification*)notification {
    
    if([OneSignal app_id])
        [OneSignal processLocalActionBasedNotification:notification identifier:@"__DEFAULT__"];
    
    if([self respondsToSelector:@selector(oneSignalLocalNotificationOpened:notification:)])
        [self oneSignalLocalNotificationOpened:application notification:notification];
}

- (void)oneSignalApplicationWillResignActive:(UIApplication*)application {
    
    if([OneSignal app_id])
        [OneSignalTracker onFocus:YES];
    
    if ([self respondsToSelector:@selector(oneSignalApplicationWillResignActive:)])
        [self oneSignalApplicationWillResignActive:application];
}

- (void) oneSignalApplicationDidEnterBackground:(UIApplication*)application {
    
    if([OneSignal app_id])
        [OneSignalLocation onfocus:NO];
    
    if ([self respondsToSelector:@selector(oneSignalApplicationDidEnterBackground:)])
        [self oneSignalApplicationDidEnterBackground:application];
}

- (void)oneSignalApplicationDidBecomeActive:(UIApplication*)application {
    
    if([OneSignal app_id]) {
        [OneSignalTracker onFocus:NO];
        [OneSignalLocation onfocus:YES];
    }
    
    if ([self respondsToSelector:@selector(oneSignalApplicationDidBecomeActive:)])
        [self oneSignalApplicationDidBecomeActive:application];
}

-(void)oneSignalApplicationWillTerminate:(UIApplication *)application {
    
    if([OneSignal app_id])
        [OneSignalTracker onFocus:YES];
    
    if ([self respondsToSelector:@selector(oneSignalApplicationWillTerminate:)])
        [self oneSignalApplicationWillTerminate:application];
}

#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)
+ (void)load {

    if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(@"7.0"))
        return;
    
    //Swizzle App delegate
    method_exchangeImplementations(class_getInstanceMethod(self, @selector(setDelegate:)), class_getInstanceMethod(self, @selector(setOneSignalDelegate:)));
}

- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate {
    
    if (delegateClass) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    delegateClass = getClassWithProtocolInHierarchy([delegate class], @protocol(UIApplicationDelegate));
    delegateSubclasses = ClassGetSubclasses(delegateClass);

    injectToProperClass(@selector(oneSignalRemoteSilentNotification:UserInfo:fetchCompletionHandler:),
                   @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:), delegateSubclasses, self.class, delegateClass);
    
    injectToProperClass(@selector(oneSignalLocalNotificationOpened:handleActionWithIdentifier:forLocalNotification:completionHandler:),
                        @selector(application:handleActionWithIdentifier:forLocalNotification:completionHandler:), delegateSubclasses, self.class, delegateClass);
    
    injectToProperClass(@selector(oneSignalDidFailRegisterForRemoteNotification:error:),
                        @selector(application:didFailToRegisterForRemoteNotificationsWithError:), delegateSubclasses, self.class, delegateClass);
    
    injectToProperClass(@selector(oneSignalDidRegisterUserNotifications:settings:),
                        @selector(application:didRegisterUserNotificationSettings:), delegateSubclasses, self.class, delegateClass);
    
    if (NSClassFromString(@"CoronaAppDelegate")) {
        [self setOneSignalDelegate:delegate];
        return;
    }
    
    injectToProperClass(@selector(oneSignalReceivedRemoteNotification:userInfo:), @selector(application:didReceiveRemoteNotification:), delegateSubclasses, self.class, delegateClass);
    
    injectToProperClass(@selector(oneSignalDidRegisterForRemoteNotifications:deviceToken:), @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:), delegateSubclasses, self.class, delegateClass);
    
    injectToProperClass(@selector(oneSignalLocalNotificationOpened:notification:), @selector(application:didReceiveLocalNotification:), delegateSubclasses, self.class, delegateClass);
    
    injectToProperClass(@selector(oneSignalApplicationWillResignActive:), @selector(applicationWillResignActive:), delegateSubclasses, self.class, delegateClass);
    
    //Required for background location
    injectToProperClass(@selector(oneSignalApplicationDidEnterBackground:), @selector(applicationDidEnterBackground:), delegateSubclasses, self.class, delegateClass);
    
    injectToProperClass(@selector(oneSignalApplicationDidBecomeActive:), @selector(applicationDidBecomeActive:), delegateSubclasses, self.class, delegateClass);
    
    //Used to track how long the app has been closed
    injectToProperClass(@selector(oneSignalApplicationWillTerminate:), @selector(applicationWillTerminate:), delegateSubclasses, self.class, delegateClass);
    
    
    /* iOS 10.0: UNUserNotificationCenterDelegate instead of UIApplicationDelegate for methods handling opening app from notification
     Make sure AppDelegate does not conform to this protocol */
    #if XC8_AVAILABLE
    if([OneSignalHelper isiOS10Plus])
        [OneSignalHelper conformsToUNProtocol];
    #endif
    
    [self setOneSignalDelegate:delegate];
}

+(UIViewController*)topmostController:(UIViewController*)base {
    
    UINavigationController *baseNav = (UINavigationController*) base;
    UITabBarController *baseTab = (UITabBarController*) base;
    if (baseNav)
        return [UIApplication topmostController:baseNav.visibleViewController];
    
    else if (baseTab.selectedViewController)
        return [UIApplication topmostController:baseTab.selectedViewController];
    
    else if (base.presentedViewController)
        return [UIApplication topmostController:baseNav.presentedViewController];
    
    return base;
}

#pragma clang diagnostic pop
@end
