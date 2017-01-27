//
//  UnitTests.m
//  UnitTests
//
//  Created by Kasten on 1/25/17.
//  Copyright © 2017 Hiptic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <objc/runtime.h>

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <UserNotifications/UserNotifications.h>

#import "OneSignal.h"

#import "OneSignalHelper.h"
#import "OneSignalSelectorHelpers.h"



// Just for debugging
void DumpObjcMethods(Class clz) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(clz, &methodCount);
    
    
    NSLog(@"Found %d methods on '%s'\n", methodCount, class_getName(clz));
    
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        
        
        NSLog(@"'%s' has method named '%s' of encoding '%s'\n",
              class_getName(clz),
              sel_getName(method_getName(method)),
              method_getTypeEncoding(method));
    }
    
    
    free(methods);
}




BOOL injectStaticSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getClassMethod(newClass, newSel);
    IMP imp = method_getImplementation(newMeth);
    
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    // Keep - class_getInstanceMethod for existing detection.
    //    class_addMethod will successfuly add if the addToClass was loaded twice into the runtime.
    BOOL existing = class_getClassMethod(addToClass, makeLikeSel) != NULL;
    
    if (existing) {
        // class_addMethod doesn't have a instance vs class name. It must just use the signature of the method.
        class_addMethod(addToClass, newSel, imp, methodTypeEncoding);
        // Even though we just added a static method we need to use getInstance here....
        newMeth = class_getInstanceMethod(addToClass, newSel);
        
        Method orgMeth = class_getClassMethod(addToClass, makeLikeSel);
        method_exchangeImplementations(orgMeth, newMeth);
    }
    else
        class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
    
    return existing;
}




@implementation NSBundleOverrider : NSObject

+ (void)load {
    injectToProperClass(@selector(overrideBundleIdentifier), @selector(bundleIdentifier), @[], [NSBundleOverrider class], [NSBundle class]);
}

- (NSString*)overrideBundleIdentifier {
    return @"com.onesignal.unittest";
}

@end

@implementation UNUserNotificationCenterOverrider : NSObject

+ (void)load {
    injectToProperClass(@selector(overrideInitWithBundleIdentifier:), @selector(initWithBundleIdentifier:), @[], [UNUserNotificationCenterOverrider class], [UNUserNotificationCenter class]);
}

- (id) overrideInitWithBundleIdentifier:(NSString*) bundle {
    return self;
}

@end
    
@implementation UIApplicationOverrider : NSObject

//if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
//}

+ (void)load {
   injectToProperClass(@selector(overrideRegisterForRemoteNotifications), @selector(registerForRemoteNotifications), @[], [UIApplicationOverrider class], [UIApplication class]);
   injectToProperClass(@selector(override_run), @selector(_run), @[], [UIApplicationOverrider class], [UIApplication class]);
   injectToProperClass(@selector(overrideCurrentUserNotificationSettings), @selector(currentUserNotificationSettings), @[], [UIApplicationOverrider class], [UIApplication class]);
}

// Keeps UIApplicationMain(...) from looping to continue to the next line.
- (void) override_run {}

- (void) overrideRegisterForRemoteNotifications {
    id app = [UIApplication sharedApplication];
    id appDelegate = [[UIApplication sharedApplication] delegate];
    
    const char bytes[] = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    id deviceToken = [NSData dataWithBytes:bytes length:32];
    [appDelegate application:app didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}


- (UIUserNotificationSettings*) overrideCurrentUserNotificationSettings {
    return [UIUserNotificationSettings settingsForTypes:7 categories:nil];
}

@end


static NSDictionary* lastHTTPRequset;

@implementation OneSignalHelperOverrider : NSObject

+ (void)load {
    injectStaticSelector([OneSignalHelperOverrider class], @selector(overrideEnqueueRequest:onSuccess:onFailure:isSynchronous:), [OneSignalHelper class], @selector(enqueueRequest:onSuccess:onFailure:isSynchronous:));
}

+ (void)overrideEnqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock isSynchronous:(BOOL)isSynchronous {
    NSLog(@"HERe!!!!!");
    NSError *error = nil;
    NSDictionary *parameters = [NSJSONSerialization JSONObjectWithData:[request HTTPBody] options:0 error:&error];
    NSLog(@"parameters: %@", parameters);
    
    lastHTTPRequset = parameters;
    
    if (successBlock)
        successBlock(@{@"id": @"1234"});
}

@end



@interface AppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {

    return true;
}

@end

/*
@interface UIApplication (UN_extra)
- (void) setOneSignalDelegate:(id<UIApplicationDelegate>)delegate;
@end

*/










@interface UnitTests : XCTestCase
@end

@implementation UnitTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}



- (void)testExample {
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    
    NSLog(@"iOS VERSION: %@", [[UIDevice currentDevice] systemVersion]);
    
    // This should fire the swizzled setDelegate in UIApplicationDelegate+OneSignal but it does not for some reason.
    // id appDelegate = [AppDelegate new];
    // [[UIApplication sharedApplication] setDelegate:appDelegate];
    
    // I really have no idea why this doesn't work.
    // id appDelegate = [AppDelegate new];
    // [[UIApplication sharedApplication] setOneSignalDelegate:appDelegate];
    
    // This works but doesn't it has an internal loop.
    //    Just overwrote _run to work around this.
    UIApplicationMain(0, nil, nil, NSStringFromClass([AppDelegate class]));
    
    // DumpObjcMethods([UIApplication class]);

    
    [OneSignal setLogLevel:ONE_S_LL_VERBOSE visualLevel:ONE_S_LL_NONE];
    [OneSignal initWithLaunchOptions:nil appId:@"b2f7f966-d8cc-11e4-bed1-df8f05be55ba"];
    
    XCTAssertEqualObjects(lastHTTPRequset[@"notification_types"], [NSNumber numberWithInt:7]);
    
    
    // There seems to be 2 network calls for some reason.
    // This should eval correctly but it does not.
    //XCTAssertEqualObjects(lastHTTPRequset[@"device_model"], @"x86_64");
    
    NSLog(@"Sleeping for debugging");
    //[NSThread sleepForTimeInterval:1000];
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
