/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
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

#import <sys/utsname.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "OneSignalReachability.h"
#import "OneSignalHelper.h"
#import "OSNotificationPayload+Internal.h"
#import "OneSignalTrackFirebaseAnalytics.h"
#import <objc/runtime.h>
#import "OneSignalInternal.h"
#import "NSString+OneSignal.h"
#import "NSURL+OneSignal.h"
#import "OneSignalCommonDefines.h"
#import "OneSignalDialogController.h"
#import "OSMessagingController.h"
#import "OneSignalNotificationCategoryController.h"
#import "OSOutcomesUtils.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalReceiveReceiptsController.h"

#define NOTIFICATION_TYPE_ALL 7
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface OneSignal ()
+ (NSString*)mUserId;
@end

@interface DirectDownloadDelegate : NSObject <NSURLSessionDataDelegate> {
    NSError* error;
    NSURLResponse* response;
    BOOL done;
    NSFileHandle* outputHandle;
}

@property (readonly, getter=isDone) BOOL done;
@property (readonly) NSError* error;
@property (readonly) NSURLResponse* response;

@end

@implementation DirectDownloadDelegate
@synthesize error, response, done;

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [outputHandle writeData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)aResponse completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    response = aResponse;
    long long expectedLength = response.expectedContentLength;
    if (expectedLength > MAX_NOTIFICATION_MEDIA_SIZE_BYTES) { //Enforcing 50 mb limit on media before downloading
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)anError {
    error = anError;
    done = YES;
    
    [outputHandle closeFile];
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)anError {
    done = YES;
    error = anError;
    [outputHandle closeFile];
}

- (id)initWithFilePath:(NSString*)path {
    if (self = [super init]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        outputHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    return self;
}
@end

@interface NSURLSession (DirectDownload)
+ (NSString *)downloadItemAtURL:(NSURL *)url toFile:(NSString *)localPath error:(NSError **)error;
@end

@implementation NSURLSession (DirectDownload)

+ (NSString *)downloadItemAtURL:(NSURL *)url toFile:(NSString *)localPath error:(NSError **)error {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    DirectDownloadDelegate *delegate = [[DirectDownloadDelegate alloc] initWithFilePath:localPath];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:delegate delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    
    [task resume];
    
    [session finishTasksAndInvalidate];
    
    while (![delegate isDone]) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    
    NSError *downloadError = [delegate error];
    if (downloadError != nil) {
        if (error)
            *error = downloadError;
        return nil;
    }
    
    return delegate.response.MIMEType;
}

@end

@interface UIApplication (Swizzling)
+(Class)delegateClass;
@end

@implementation OSNotificationAction
@synthesize type = _type, actionID = _actionID;

-(id)initWithActionType:(OSNotificationActionType)type :(NSString*)actionID {
    self = [super init];
    if(self) {
        _type = type;
        _actionID = actionID;
    }
    return self;
}

@end

@implementation OSNotification
@synthesize payload = _payload, shown = _shown, isAppInFocus = _isAppInFocus, silentNotification = _silentNotification, displayType = _displayType, mutableContent = _mutableContent;

- (id)initWithPayload:(OSNotificationPayload *)payload displayType:(OSNotificationDisplayType)displayType {
    self = [super init];
    if (self) {
        _payload = payload;
        
        _displayType = displayType;
        
        _silentNotification = [OneSignalHelper isRemoteSilentNotification:payload.rawPayload];
        
        _mutableContent = payload.rawPayload[@"aps"][@"mutable-content"] && [payload.rawPayload[@"aps"][@"mutable-content"] isEqual: @YES];
        
        _shown = true;
        
        _isAppInFocus = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
        
        //If remote silent -> shown = false
        //If app is active and in-app alerts are not enabled -> shown = false
        if (_silentNotification ||
            (_isAppInFocus && OneSignal.inFocusDisplayType == OSNotificationDisplayTypeNone))
            _shown = false;
        
    }
    return self;
}

- (NSString*)stringify {
    let obj = [NSMutableDictionary new];
    [obj setObject:[NSMutableDictionary new] forKeyedSubscript:@"payload"];
    
    if (self.payload.notificationID)
        [obj[@"payload"] setObject:self.payload.notificationID forKeyedSubscript: @"notificationID"];
    
    if (self.payload.sound)
        [obj[@"payload"] setObject:self.payload.sound forKeyedSubscript: @"sound"];
    
    if (self.payload.title)
        [obj[@"payload"] setObject:self.payload.title forKeyedSubscript: @"title"];
    
    if (self.payload.body)
        [obj[@"payload"] setObject:self.payload.body forKeyedSubscript: @"body"];
    
    if (self.payload.subtitle)
        [obj[@"payload"] setObject:self.payload.subtitle forKeyedSubscript: @"subtitle"];
    
    if (self.payload.additionalData)
        [obj[@"payload"] setObject:self.payload.additionalData forKeyedSubscript: @"additionalData"];
    
    if (self.payload.actionButtons)
        [obj[@"payload"] setObject:self.payload.actionButtons forKeyedSubscript: @"actionButtons"];
    
    if (self.payload.rawPayload)
        [obj[@"payload"] setObject:self.payload.rawPayload forKeyedSubscript: @"rawPayload"];
    
    if (self.payload.launchURL)
        [obj[@"payload"] setObject:self.payload.launchURL forKeyedSubscript: @"launchURL"];
    
    if (self.payload.contentAvailable)
        [obj[@"payload"] setObject:@(self.payload.contentAvailable) forKeyedSubscript: @"contentAvailable"];
    
    if (self.payload.badge)
        [obj[@"payload"] setObject:@(self.payload.badge) forKeyedSubscript: @"badge"];
    
    if (self.displayType)
        [obj setObject:@(self.displayType) forKeyedSubscript: @"displayType"];
    
    
    [obj setObject:@(self.shown) forKeyedSubscript: @"shown"];
    [obj setObject:@(self.isAppInFocus) forKeyedSubscript: @"isAppInFocus"];
    
    if (self.silentNotification)
        [obj setObject:@(self.silentNotification) forKeyedSubscript: @"silentNotification"];
    
    //Convert obj into a serialized
    NSError *err;
    NSData *jsonData = [NSJSONSerialization  dataWithJSONObject:obj options:0 error:&err];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end

@implementation OSNotificationOpenedResult
@synthesize notification = _notification, action = _action;

- (id)initWithNotification:(OSNotification*)notification action:(OSNotificationAction*)action {
    self = [super init];
    if(self) {
        _notification = notification;
        _action = action;
    }
    return self;
}

- (NSString*)stringify {
    
    NSError * jsonError = nil;
    NSData *objectData = [[self.notification stringify] dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *notifDict = [NSJSONSerialization JSONObjectWithData:objectData
                                                              options:NSJSONReadingMutableContainers
                                                                error:&jsonError];
    
    NSMutableDictionary* obj = [NSMutableDictionary new];
    NSMutableDictionary* action = [NSMutableDictionary new];
    [action setObject:self.action.actionID forKeyedSubscript:@"actionID"];
    [obj setObject:action forKeyedSubscript:@"action"];
    [obj setObject:notifDict forKeyedSubscript:@"notification"];
    if(self.action.type)
        [obj[@"action"] setObject:@(self.action.type) forKeyedSubscript: @"type"];
    
    //Convert obj into a serialized
    NSError * err;
    NSData * jsonData = [NSJSONSerialization  dataWithJSONObject:obj options:0 error:&err];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end

@implementation OneSignalHelper

static var lastMessageID = @"";
static NSString *_lastMessageIdFromAction;

+ (void)resetLocals {
    [OneSignalHelper lastMessageReceived:nil];
    _lastMessageIdFromAction = nil;
    lastMessageID = @"";
}

UIBackgroundTaskIdentifier mediaBackgroundTask;

+ (void) beginBackgroundMediaTask {
    mediaBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [OneSignalHelper endBackgroundMediaTask];
    }];
}

+ (void) endBackgroundMediaTask {
    [[UIApplication sharedApplication] endBackgroundTask: mediaBackgroundTask];
    mediaBackgroundTask = UIBackgroundTaskInvalid;
}

OneSignalWebView *webVC;
NSDictionary* lastMessageReceived;
OSHandleNotificationReceivedBlock handleNotificationReceived;
OSHandleNotificationActionBlock handleNotificationAction;

//Passed to the OnFocus to make sure dismissed when coming back into app
+(OneSignalWebView*)webVC {
    return webVC;
}

+ (BOOL)isRemoteSilentNotification:(NSDictionary*)msg {
    //no alert, sound, or badge payload
    if(msg[@"badge"] || msg[@"aps"][@"badge"] || msg[@"m"] || msg[@"o"] || msg[@"s"] || (msg[@"title"] && [msg[@"title"] length] > 0) || msg[@"sound"] || msg[@"aps"][@"sound"] || msg[@"aps"][@"alert"] || msg[@"os_data"][@"buttons"])
        return false;
    return true;
}

+ (void)lastMessageReceived:(NSDictionary*)message {
    lastMessageReceived = message;
}

+(void)setNotificationActionBlock:(OSHandleNotificationActionBlock)block {
    handleNotificationAction = block;
}

+(void)setNotificationReceivedBlock:(OSHandleNotificationReceivedBlock)block {
    handleNotificationReceived = block;
}

+ (NSString*)getAppName {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
}

+ (NSMutableDictionary*)formatApsPayloadIntoStandard:(NSDictionary*)remoteUserInfo identifier:(NSString*)identifier {
    NSMutableDictionary* userInfo, *customDict, *additionalData, *optionsDict;
    BOOL is2dot4Format = false;
    
    if (remoteUserInfo[@"os_data"]) {
        userInfo = [remoteUserInfo mutableCopy];
        additionalData = [NSMutableDictionary dictionary];
        
        if (remoteUserInfo[@"os_data"][@"buttons"]) {
            
            is2dot4Format = [userInfo[@"os_data"][@"buttons"] isKindOfClass:[NSArray class]];
            if (is2dot4Format)
                optionsDict = userInfo[@"os_data"][@"buttons"];
            else
                optionsDict = userInfo[@"os_data"][@"buttons"][@"o"];
        }
    }
    else if (remoteUserInfo[@"custom"]) {
        userInfo = [remoteUserInfo mutableCopy];
        customDict = [userInfo[@"custom"] mutableCopy];
        if (customDict[@"a"])
            additionalData = [[NSMutableDictionary alloc] initWithDictionary:customDict[@"a"]];
        else
            additionalData = [[NSMutableDictionary alloc] init];
        optionsDict = userInfo[@"o"];
    }
    else {
        return nil;
    }
    
    if (optionsDict) {
        NSMutableArray* buttonArray = [[NSMutableArray alloc] init];
        for (NSDictionary* button in optionsDict) {
            [buttonArray addObject: @{@"text" : button[@"n"],
                                      @"id" : (button[@"i"] ? button[@"i"] : button[@"n"])}];
        }
        additionalData[@"actionButtons"] = buttonArray;
    }
    
    if (![@"com.apple.UNNotificationDefaultActionIdentifier" isEqualToString:identifier])
        additionalData[@"actionSelected"] = identifier;
    
    if ([additionalData count] == 0)
        additionalData = nil;
    else if (remoteUserInfo[@"os_data"]) {
        [userInfo addEntriesFromDictionary:additionalData];
        if (!is2dot4Format && userInfo[@"os_data"][@"buttons"])
            userInfo[@"aps"] = @{@"alert" : userInfo[@"os_data"][@"buttons"][@"m"]};
    }
    
    else {
        customDict[@"a"] = additionalData;
        userInfo[@"custom"] = customDict;
        
        if (userInfo[@"m"])
            userInfo[@"aps"] = @{@"alert" : userInfo[@"m"]};
    }
    
    return userInfo;
}


// Prevent the OSNotification blocks from firing if we receive a Non-OneSignal remote push
+ (BOOL)isOneSignalPayload:(NSDictionary *)payload {
    if (!payload)
        return NO;
    return payload[@"custom"][@"i"] || payload[@"os_data"][@"i"];
}

+ (void)handleNotificationReceived:(OSNotificationDisplayType)displayType fromBackground:(BOOL)background {
    if (![self isOneSignalPayload:lastMessageReceived])
        return;
    
    let payload = [OSNotificationPayload parseWithApns:lastMessageReceived];
    if ([self handleIAMPreview:payload])
        return;
    
    // The payload is a valid OneSignal notification payload and is not a preview
    // Proceed and treat as a normal OneSignal notification
    let notification = [[OSNotification alloc] initWithPayload:payload displayType:displayType];

    // Prevent duplicate calls to same receive event
    if ([payload.notificationID isEqualToString:lastMessageID])
        return;
    lastMessageID = payload.notificationID;

    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE
                     message:[NSString stringWithFormat:@"handleNotificationReceived lastMessageID: %@ displayType: %lu",lastMessageID, (unsigned long)displayType]];

    if (handleNotificationReceived)
       handleNotificationReceived(notification);
}

+ (void)handleNotificationAction:(OSNotificationActionType)actionType actionID:(NSString*)actionID displayType:(OSNotificationDisplayType)displayType {
    if (![self isOneSignalPayload:lastMessageReceived])
        return;
    
    OSNotificationAction *action = [[OSNotificationAction alloc] initWithActionType:actionType :actionID];
    OSNotificationPayload *payload = [OSNotificationPayload parseWithApns:lastMessageReceived];
    OSNotification *notification = [[OSNotification alloc] initWithPayload:payload displayType:displayType];
    OSNotificationOpenedResult *result = [[OSNotificationOpenedResult alloc] initWithNotification:notification action:action];
    
    // Prevent duplicate calls to same action
    if ([payload.notificationID isEqualToString:_lastMessageIdFromAction])
        return;
    _lastMessageIdFromAction = payload.notificationID;
    
    [OneSignalTrackFirebaseAnalytics trackOpenEvent:result];
    
    if (!handleNotificationAction)
        return;
    handleNotificationAction(result);
}

+ (BOOL)handleIAMPreview:(OSNotificationPayload *)payload {
    NSString *uuid = [payload additionalData][ONESIGNAL_IAM_PREVIEW];
    if (uuid) {

        [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"IAM Preview Detected, Begin Handling"];
        OSInAppMessage *message = [OSInAppMessage instancePreviewFromPayload:payload];
        [[OSMessagingController sharedInstance] presentInAppPreviewMessage:message];
        return YES;
    }
    return NO;
}

+(NSNumber*)getNetType {
    OneSignalReachability* reachability = [OneSignalReachability reachabilityForInternetConnection];
    NetworkStatus status = [reachability currentReachabilityStatus];
    if (status == ReachableViaWiFi)
        return @0;
    return @1;
}

+ (NSString *)getCurrentDeviceVersion {
    return [[UIDevice currentDevice] systemVersion];
}

+ (BOOL)isIOSVersionGreaterThanOrEqual:(NSString *)version {
    return [[self getCurrentDeviceVersion] compare:version options:NSNumericSearch] != NSOrderedAscending;
}

+ (BOOL)isIOSVersionLessThan:(NSString *)version {
    return [[self getCurrentDeviceVersion] compare:version options:NSNumericSearch] == NSOrderedAscending;
}

+ (NSString*) getSystemInfoMachine {
    // e.g. @"x86_64" or @"iPhone9,3"
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine
                                         encoding:NSUTF8StringEncoding];
}

// This will get real device model if it is a real iOS device (Example iPhone8,2)
// If an iOS Simulator it will return "Simulator iPhone" or "Simulator iPad"
// If a macOS Catalyst app, return "Mac"
+ (NSString*)getDeviceVariant {
    let systemInfoMachine = [self getSystemInfoMachine];

    // x86_64 could mean an iOS Simulator or Catalyst app on macOS
    if ([systemInfoMachine isEqualToString:@"x86_64"]) {
        let systemName = UIDevice.currentDevice.systemName;
        if ([systemName isEqualToString:@"iOS"]) {
            let model = UIDevice.currentDevice.model;
            return [@"Simulator " stringByAppendingString:model];
        } else {
            return @"Mac";
        }
    }

    return systemInfoMachine;
}

// Can call currentUserNotificationSettings
+ (BOOL) canGetNotificationTypes {
    return [self isIOSVersionGreaterThanOrEqual:@"8.0"];
}

// For iOS 8 and 9
+ (UILocalNotification*)createUILocalNotification:(OSNotificationPayload*)payload {
    let notification = [UILocalNotification new];
    
    let category = [UIMutableUserNotificationCategory new];
    [category setIdentifier:@"__dynamic__"];
    
    NSMutableArray* actionArray = [NSMutableArray new];
    for (NSDictionary* button in payload.actionButtons) {
        let action = [UIMutableUserNotificationAction new];
        action.title = button[@"text"];
        action.identifier = button[@"id"];
        action.activationMode = UIUserNotificationActivationModeForeground;
        action.destructive = false;
        action.authenticationRequired = false;
        
        [actionArray addObject:action];
        // iOS 8 shows notification buttons in reverse in all cases but alerts.
        //   This flips it so the frist button is on the left.
        if (actionArray.count == 2)
            [category setActions:@[actionArray[1], actionArray[0]]
                      forContext:UIUserNotificationActionContextMinimal];
    }
    
    [category setActions:actionArray forContext:UIUserNotificationActionContextDefault];
    
    var currentCategories = [[[UIApplication sharedApplication] currentUserNotificationSettings] categories];
    if (currentCategories)
        currentCategories = [currentCategories setByAddingObject:category];
    else
        currentCategories = [NSSet setWithObject:category];
    
    let notificationSettings = [UIUserNotificationSettings
                                settingsForTypes:NOTIFICATION_TYPE_ALL
                                categories:currentCategories];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    notification.category = [category identifier];
    
    return notification;
}

// iOS 8 and 9
+ (UILocalNotification*)prepareUILocalNotification:(OSNotificationPayload*)payload {
    let notification = [self createUILocalNotification:payload];
    
    // alertTitle was added in iOS 8.2
    if ([notification respondsToSelector:@selector(alertTitle)])
        notification.alertTitle = payload.title;
    
    notification.alertBody = payload.body;
    
    notification.userInfo = payload.rawPayload;
    
    notification.soundName = payload.sound;
    if (notification.soundName == nil)
        notification.soundName = UILocalNotificationDefaultSoundName;
    
    notification.applicationIconBadgeNumber = payload.badge;
    
    return notification;
}

//Shared instance as OneSignal is delegate of UNUserNotificationCenterDelegate and CLLocationManagerDelegate
static OneSignal* singleInstance = nil;
+(OneSignal*)sharedInstance {
    @synchronized( singleInstance ) {
        if (!singleInstance )
            singleInstance = [OneSignal new];
    }
    
    return singleInstance;
}

+(NSString*)randomStringWithLength:(int)length {
    let letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let randomString = [[NSMutableString alloc] initWithCapacity:length];
    for(var i = 0; i < length; i++) {
        let ln = (uint32_t)letters.length;
        let rand = arc4random_uniform(ln);
        [randomString appendFormat:@"%C", [letters characterAtIndex:rand]];
    }
    return randomString;
}

+ (void)registerAsUNNotificationCenterDelegate {
    let curNotifCenter = [UNUserNotificationCenter currentNotificationCenter];
    
    /*
        Sets the OneSignal shared instance as a delegate of UNUserNotificationCenter
        OneSignal does not implement the delegate methods, we simply set it as a delegate
        in order to swizzle the UNUserNotificationCenter methods in case the developer
        does not set a UNUserNotificationCenter delegate themselves
    */
    
    if (!curNotifCenter.delegate)
        curNotifCenter.delegate = (id)[self sharedInstance];
}

+(UNNotificationRequest*)prepareUNNotificationRequest:(OSNotificationPayload*)payload {
    let content = [UNMutableNotificationContent new];
    
    [self addActionButtons:payload toNotificationContent:content];
    
    content.title = payload.title;
    content.subtitle = payload.subtitle;
    content.body = payload.body;
    
    content.userInfo = payload.rawPayload;
    
    if (payload.sound)
        content.sound = [UNNotificationSound soundNamed:payload.sound];
    else
        content.sound = UNNotificationSound.defaultSound;
    
    if (payload.badge != 0)
        content.badge = [NSNumber numberWithInteger:payload.badge];
    
    // Check if media attached    
    [self addAttachments:payload toNotificationContent:content];
    
    let trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.25 repeats:NO];
    let identifier = [self randomStringWithLength:16];
    return [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
}

+ (void)addActionButtons:(OSNotificationPayload*)payload
   toNotificationContent:(UNMutableNotificationContent*)content {
    if (!payload.actionButtons || payload.actionButtons.count == 0)
        return;
    
    let actionArray = [NSMutableArray new];
    for(NSDictionary* button in payload.actionButtons) {
        let action = [UNNotificationAction actionWithIdentifier:button[@"id"]
                                                          title:button[@"text"]
                                                        options:UNNotificationActionOptionForeground];
        [actionArray addObject:action];
    }
    
    NSArray* finalActionArray;
    if (actionArray.count == 2)
        finalActionArray = [[actionArray reverseObjectEnumerator] allObjects];
    else
        finalActionArray = actionArray;
    
    // Get a full list of categories so we don't replace any exisiting ones.
    var allCategories = OneSignalNotificationCategoryController.sharedInstance.existingCategories;
    
    let newCategoryIdentifier = [OneSignalNotificationCategoryController.sharedInstance registerNotificationCategoryForNotificationId:payload.notificationID];
    let category = [UNNotificationCategory categoryWithIdentifier:newCategoryIdentifier
                                                          actions:finalActionArray
                                                intentIdentifiers:@[]
                                                          options:UNNotificationCategoryOptionCustomDismissAction];

    if (allCategories) {
        let newCategorySet = [NSMutableSet new];
        for(UNNotificationCategory *existingCategory in allCategories) {
            if (![existingCategory.identifier isEqualToString:newCategoryIdentifier])
                [newCategorySet addObject:existingCategory];
        }

        [newCategorySet addObject:category];
        allCategories = newCategorySet;
    }
    else
        allCategories = [[NSMutableSet alloc] initWithArray:@[category]];

    [UNUserNotificationCenter.currentNotificationCenter setNotificationCategories:allCategories];
    
    // List Categories again so iOS refreshes it's internal list.
    // Required otherwise buttons will not display or won't update.
    // This is a blackbox assumption, the delay on the main thread this call creates might be giving
    //   some iOS background thread time to flush to disk.
    allCategories = OneSignalNotificationCategoryController.sharedInstance.existingCategories;
    
    content.categoryIdentifier = newCategoryIdentifier;
}

+ (void)addAttachments:(OSNotificationPayload*)payload
 toNotificationContent:(UNMutableNotificationContent*)content {
    if (!payload.attachments)
        return;
    
    let unAttachments = [NSMutableArray new];
    
    for(NSString* key in payload.attachments) {
        let URI = [OneSignalHelper trimURLSpacing:[payload.attachments valueForKey:key]];
        
        let nsURL = [NSURL URLWithString:URI];
        
        // Remote media attachment */
        if (nsURL && [self isWWWScheme:nsURL]) {
            // Synchroneously download file and chache it
            let name = [OneSignalHelper downloadMediaAndSaveInBundle:URI];
            
            if (!name)
                continue;
            
            let paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            let filePath = [paths[0] stringByAppendingPathComponent:name];
            let url = [NSURL fileURLWithPath:filePath];
            NSError* error;
            let attachment = [UNNotificationAttachment
                              attachmentWithIdentifier:key
                              URL:url
                              options:0
                              error:&error];
            if (attachment)
                [unAttachments addObject:attachment];
        }
        // Local in bundle resources
        else {
            let files = [[NSMutableArray<NSString*> alloc] initWithArray:[URI componentsSeparatedByString:@"."]];
            if (files.count < 2)
                continue;
            
            let extension = [files lastObject];
            [files removeLastObject];
            let name = [files componentsJoinedByString:@"."];
            
            //Make sure resource exists
            let url = [[NSBundle mainBundle] URLForResource:name withExtension:extension];
            if (url) {
                NSError *error;
                id attachment = [UNNotificationAttachment
                                 attachmentWithIdentifier:key
                                 URL:url
                                 options:0
                                 error:&error];
                if (attachment)
                    [unAttachments addObject:attachment];
            }
        }
    }
    
    content.attachments = unAttachments;
}

+ (void)addNotificationRequest:(OSNotificationPayload*)payload
             completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    // Start background thread to download media so we don't lock the main UI thread.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [OneSignalHelper beginBackgroundMediaTask];
        
        let notificationRequest = [OneSignalHelper prepareUNNotificationRequest:payload];
        [[UNUserNotificationCenter currentNotificationCenter]
         addNotificationRequest:notificationRequest
         withCompletionHandler:^(NSError * _Nullable error) {}];
        if (completionHandler)
            completionHandler(UIBackgroundFetchResultNewData);
        
        [OneSignalHelper endBackgroundMediaTask];
    });

}

/*
 Synchroneously downloads an attachment
 On success returns bundle resource name, otherwise returns nil
*/
+ (NSString *)downloadMediaAndSaveInBundle:(NSString*)urlString {
    
    let url = [NSURL URLWithString:urlString];
     
    //Download the file
    var name = [self randomStringWithLength:10];
        
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* filePath = [paths[0] stringByAppendingPathComponent:name];
    
    //guard against situations where for example, available storage is too low
    
    @try {
        NSError* error;
        let mimeType = [NSURLSession downloadItemAtURL:url toFile:filePath error:&error];
        
        if (error) {
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error while attempting to download file with URL: %@", error]];
            return nil;
        }

        NSString *extension = [OneSignalHelper getSupportedFileExtensionFromURL:url mimeType:mimeType];
        if (!extension || [extension isEqualToString:@""])
            return nil;
        
        name = [NSString stringWithFormat:@"%@.%@", name, extension];
        
        let newPath = [paths[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", name]];
        
        [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newPath error:&error];
        
        if (error) {
            [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error while attempting to download file with URL: %@", error]];
            return nil;
        }
         
        let standardUserDefaults = OneSignalUserDefaults.initStandard;
         
        NSArray* cachedFiles = [standardUserDefaults getSavedObjectForKey:OSUD_TEMP_CACHED_NOTIFICATION_MEDIA defaultValue:nil];
        NSMutableArray* appendedCache;
        if (cachedFiles) {
            appendedCache = [[NSMutableArray alloc] initWithArray:cachedFiles];
            [appendedCache addObject:name];
        }
        else
            appendedCache = [[NSMutableArray alloc] initWithObjects:name, nil];
         
        [standardUserDefaults saveObjectForKey:OSUD_TEMP_CACHED_NOTIFICATION_MEDIA withValue:appendedCache];
        return name;
    } @catch (NSException *exception) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"OneSignal encountered an exception while downloading file (%@), exception: %@", url, exception.description]];
        
        return nil;
    }
}


/*
 The preference order for file type determination is as follows:
    1. URL Query parameter called 'filename', such as test.jpg. The SDK will extract the file extension from it
    2. MIME type
    3. File extension in the actual URL
    4. A file extension extracted by searching through all URL Query parameters
 */
+ (NSString *)getSupportedFileExtensionFromURL:(NSURL *)url mimeType:(NSString *)mimeType {
    //Try to get extension from the filename parameter
    NSString* extension = [[url valueFromQueryParameter:@"filename"]
                            supportedFileExtension];
    if (extension && [ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES containsObject:extension]) {
        return extension;
    }
    //Use the MIME type for the extension
    if (mimeType != nil && ![mimeType isEqualToString:@""]) {
        extension = mimeType.fileExtensionForMimeType;
        if (extension && [ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES containsObject:extension]) {
            return extension;
        }
    }
    //Try using url.pathExtension
    extension =  url.pathExtension;
    if (extension && [ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES containsObject:extension]) {
        return extension;
    }
    //Try getting an extension from the query
    extension = url.supportedFileExtensionFromQueryItems;
    if (extension && [ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES containsObject:extension]) {
        return extension;
    }
    return nil;
}

// TODO: Add back after testing
+ (void)clearCachedMedia {
    /*
    if (!NSClassFromString(@"UNUserNotificationCenter"))
      return;
     
    NSArray* cachedFiles = [[NSUserDefaults standardUserDefaults] objectForKey:OSUD_TEMP_CACHED_NOTIFICATION_MEDIA];
    if (cachedFiles) {
        NSArray * paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        for (NSString* file in cachedFiles) {
            NSString* filePath = [paths[0] stringByAppendingPathComponent:file];
            NSError* error;
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        }
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:OSUD_TEMP_CACHED_NOTIFICATION_MEDIA];
    }
     */
}

+ (BOOL)verifyURL:(NSString *)urlString {
    if (urlString) {
        NSURL* url = [NSURL URLWithString:urlString];
        if (url)
            return YES;
    }
    
    return NO;
}

+ (BOOL)isWWWScheme:(NSURL*)url {
    NSString* urlScheme = [url.scheme lowercaseString];
    return [urlScheme isEqualToString:@"http"] || [urlScheme isEqualToString:@"https"];
}

+ (void) displayWebView:(NSURL*)url {
    // Check if in-app or safari
    __block BOOL inAppLaunch = [OneSignalUserDefaults.initStandard getSavedBoolForKey:OSUD_NOTIFICATION_OPEN_LAUNCH_URL defaultValue:true];
    
    // If the URL contains itunes.apple.com, it's an app store link
    // that should be opened using sharedApplication openURL
    if ([[url absoluteString] rangeOfString:@"itunes.apple.com"].location != NSNotFound) {
        inAppLaunch = NO;
    }
    
    __block let openUrlBlock = ^void(BOOL shouldOpen) {
        if (!shouldOpen)
            return;
        
        [OneSignalHelper dispatch_async_on_main_queue: ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (inAppLaunch && [self isWWWScheme:url]) {
                    if (!webVC)
                        webVC = [[OneSignalWebView alloc] init];
                    webVC.url = url;
                    [webVC showInApp];
                }
                else {
                    // Keep dispatch_async. Without this the url can take an extra 2 to 10 secounds to open.
                    [[UIApplication sharedApplication] openURL:url];
                }
            });
        }];
    };
    
    if ([OneSignal shouldPromptToShowURL]) {
        let message = NSLocalizedString(([NSString stringWithFormat:@"Would you like to open %@://%@", url.scheme, url.host]), @"Asks whether the user wants to open the URL");
        let title = NSLocalizedString(@"Open Website?", @"A title asking if the user wants to open a URL/website");
        let openAction = NSLocalizedString(@"Open", @"Allows the user to open the URL/website");
        let cancelAction = NSLocalizedString(@"Cancel", @"The user won't open the URL/website");
        
        [[OneSignalDialogController sharedInstance] presentDialogWithTitle:title withMessage:message withAction:openAction cancelTitle:cancelAction withActionCompletion:^(BOOL tappedAction) {
            openUrlBlock(tappedAction);
        }];
    } else {
        openUrlBlock(true);
    }
        
}

+ (void) runOnMainThread:(void(^)())block {
    if ([NSThread isMainThread])
        block();
    else
        dispatch_sync(dispatch_get_main_queue(), block);
}

+ (void) dispatch_async_on_main_queue:(void(^)())block {
    dispatch_async(dispatch_get_main_queue(), block);
}

+ (void)performSelector:(SEL)aSelector onMainThreadOnObject:(nullable id)targetObj withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay {
    [self dispatch_async_on_main_queue:^{
        [targetObj performSelector:aSelector withObject:anArgument afterDelay:delay];
    }];
}

+ (BOOL) isValidEmail:(NSString*)email {
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@((\\[[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\])|(([a-zA-Z\\-0-9]+\\.)+[a-zA-Z]{2,}))$"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:&error];
    NSUInteger numberOfMatches = [regex numberOfMatchesInString:email
                                                        options:0
                                                          range:NSMakeRange(0, [email length])];
    return numberOfMatches != 0;
}

+ (NSString*)hashUsingSha1:(NSString*)string {
    const char *cstr = [string UTF8String];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(cstr, (CC_LONG)strlen(cstr), digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}

+ (NSString*)hashUsingMD5:(NSString*)string {
    const char *cstr = [string UTF8String];
    uint8_t digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}

+ (NSString*)trimURLSpacing:(NSString*)url {
    if (!url)
        return url;
    
    return [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

+ (BOOL)isTablet {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

#pragma clang diagnostic pop
#pragma clang diagnostic pop
#pragma clang diagnostic pop
@end
