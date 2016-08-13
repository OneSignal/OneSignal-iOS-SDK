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

#import "OneSignalReachability.h"
#import "OneSignalHelper.h"
#import "NSObject+Extras.h"
#import "OneSignalWebView.h"

#import <objc/runtime.h>

#define NOTIFICATION_TYPE_ALL 7
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

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

@implementation OSNotificationPayload
@synthesize actionButtons = _actionButtons, additionalData = _additionalData, badge = _badge, body = _body, contentAvailable = _contentAvailable, notificationID = _notificationID, launchURL = _launchURL, rawPayload = _rawPayload, sound = _sound, subtitle = _subtitle, title = _title, attachments = _attachments;

- (id)initWithRawMessage:(NSDictionary*)message {
    self = [super init];
    if(self && message) {
        _rawPayload = [NSDictionary dictionaryWithDictionary:message];;
        
        if(_rawPayload[@"aps"][@"content-available"])
            _contentAvailable = (BOOL)_rawPayload[@"aps"][@"content-available"];
        else _contentAvailable = NO;
        
        if(_rawPayload[@"aps"][@"badge"])
            _badge = (int)_rawPayload[@"aps"][@"badge"];
        else _badge = (int)_rawPayload[@"badge"];
        
        _actionButtons = _rawPayload[@"o"];
        if(!_actionButtons)
            _actionButtons = _rawPayload[@"os_data"][@"buttons"][@"o"];
        
        if(_rawPayload[@"aps"][@"sound"])
            _sound = _rawPayload[@"aps"][@"sound"];
        else if(_rawPayload[@"s"])
            _sound = _rawPayload[@"s"];
        else _sound = _rawPayload[@"os_data"][@"buttons"][@"s"];
        
        if(_rawPayload[@"custom"]) {
            NSDictionary * custom = _rawPayload[@"custom"];
            if(custom[@"a"])
                _additionalData = [custom[@"a"] copy];
            if(custom[@"at"])
                _attachments = [custom[@"at"] copy];
            _notificationID = custom[@"i"];
            _launchURL = custom[@"u"];
        }
        else if(_rawPayload[@"os_data"]) {
            NSDictionary * os_data = _rawPayload[@"os_data"];
            
            NSMutableDictionary *additional = [_rawPayload mutableCopy];
            [additional removeObjectForKey:@"aps"];
            [additional removeObjectForKey:@"os_data"];
            _additionalData = [[NSDictionary alloc] initWithDictionary:additional];
            
            _notificationID = os_data[@"i"];
            _launchURL = os_data[@"u"];
            
            if(os_data[@"at"])
                _attachments = [os_data[@"at"] copy];
        }
        
        if(_rawPayload[@"m"]) {
            NSDictionary * m = _rawPayload[@"m"];
            _body = m[@"body"];
            _title = m[@"title"];
            _subtitle = m[@"subtitle"];
        }
        else if(_rawPayload[@"aps"][@"alert"]) {
            id a = message[@"aps"][@"alert"];
            if([a isKindOfClass:[NSDictionary class]]) {
                _body = a[@"body"];
                _title = a[@"title"];
                _subtitle = a[@"subtitle"];
            }
            else _title = a;
        }
        else if(_rawPayload[@"os_data"][@"buttons"][@"m"]) {
            NSDictionary * m = _rawPayload[@"os_data"][@"buttons"][@"m"];
            _body = m[@"body"];
            _title = m[@"title"];
            _subtitle = m[@"subtitle"];
        }
    }
    return self;
}
@end

@implementation OSNotification
@synthesize payload = _payload, shown = _shown, silentNotification = _silentNotification, displayType = _displayType;
- (id)initWithPayload:(OSNotificationPayload *)payload displayType:(OSNotificationDisplayType)displayType {
    self = [super init];
    if (self) {
        _payload = payload;
        
        _displayType = displayType;
        
        _silentNotification = [OneSignalHelper isRemoteSilentNotification:payload.rawPayload];
        
        _shown = true;
        
        BOOL isActive = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;
        
        //If remote silent -> shown = false
        //If app is active and in-app alerts are not enabled -> shown = false
        if(_silentNotification || (isActive && ![[NSUserDefaults standardUserDefaults] boolForKey:@"ONESIGNAL_INAPP_ALERT"]))
            _shown = false;
        
    }
    return self;
}

@end

@implementation OSNotificationResult
@synthesize notification = _notification, action = _action;

- (id)initWithNotification:(OSNotification*)notification action:(OSNotificationAction*)action {
    self = [super init];
    if(self) {
        _notification = notification;
        _action = action;
    }
    return self;
}

@end

@implementation OneSignalHelper

OneSignalWebView *webVC;
NSDictionary* lastMessageReceived;
OSHandleNotificationReceivedBlock handleNotificationReceived;
OSHandleNotificationActionBlock handleNotificationAction;



+ (BOOL) isRemoteSilentNotification:(NSDictionary*)msg {
    //no alert, sound, or badge payload
    if(msg[@"badge"] || msg[@"aps"][@"badge"] || msg[@"m"] || msg[@"o"] || msg[@"s"] || msg[@"title"] || msg[@"sound"] || msg[@"aps"][@"sound"] || msg[@"aps"][@"alert"] || msg[@"os_data"][@"buttons"])
        return false;
    return true;
}

+ (void)lastMessageReceived:(NSDictionary*)message {
    lastMessageReceived = message;
}

+ (void)notificationBlocks:(OSHandleNotificationReceivedBlock)receivedBlock :(OSHandleNotificationActionBlock)actionBlock {
    handleNotificationReceived = receivedBlock;
    handleNotificationAction = actionBlock;
}

+ (NSString*)md5:(NSString *)text {
    return NULL;
}

+ (NSArray*)getActionButtons {
    
    if(!lastMessageReceived) return NULL;
    
    if(lastMessageReceived[@"os_data"] && [lastMessageReceived[@"os_data"] isKindOfClass:[NSDictionary class]]) {
        return lastMessageReceived[@"os_data"][@"buttons"][@"o"];
    }
    
    return lastMessageReceived[@"o"];
}

+ (NSArray<NSString*>*)getPushTitleBody:(NSDictionary*)messageDict {
    
    NSString *title  = messageDict[@"m"][@"title"];
    NSString *body  = messageDict[@"m"][@"body"];
    if(!title) {
        if([messageDict[@"aps"][@"alert"] isKindOfClass:[NSDictionary class]])
            title = messageDict[@"aps"][@"alert"][@"title"];
        else title = messageDict[@"aps"][@"alert"];
    }
    
    if(!title)
        title = messageDict[@"os_data"][@"buttons"][@"m"][@"title"];
    if(!title)
        title = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
    if(!title) title = @"";
    
    if(!body && [messageDict[@"aps"][@"alert"] isKindOfClass:[NSDictionary class]])
        body = messageDict[@"aps"][@"alert"][@"body"];
    if(!body)
        body = messageDict[@"os_data"][@"buttons"][@"m"][@"body"];
    if(!body)
        body = @"";
    
    return @[title, body];
}

// Prevent the OSNotification blocks from firing if we receive a Non-OneSignal remote push
+ (BOOL)isOneSignalPayload {
    if(!lastMessageReceived) return NO;
    return lastMessageReceived[@"custom"][@"i"] || lastMessageReceived[@"os_data"][@"i"];
}

+ (void)handleNotificationReceived:(OSNotificationDisplayType)displayType {
    if (!handleNotificationReceived || ![self isOneSignalPayload]) return;
    
    
    OSNotificationPayload *payload = [[OSNotificationPayload alloc] initWithRawMessage:lastMessageReceived];
    OSNotification *notification = [[OSNotification alloc] initWithPayload:payload displayType:displayType];
    
    //Prevent duplicate calls to same action
    static NSString* lastMessageID = @"";
    if([payload.notificationID isEqualToString:lastMessageID]) return;
    lastMessageID = payload.notificationID;
    
    handleNotificationReceived(notification);
}

+ (void)handleNotificationAction:(OSNotificationActionType)actionType actionID:(NSString*)actionID displayType:(OSNotificationDisplayType)displayType {
    if (!handleNotificationAction || ![self isOneSignalPayload]) return;
    
    OSNotificationAction *action = [[OSNotificationAction alloc] initWithActionType:actionType :actionID];
    OSNotificationPayload *payload = [[OSNotificationPayload alloc] initWithRawMessage:lastMessageReceived];
    OSNotification *notification = [[OSNotification alloc] initWithPayload:payload displayType:displayType];
    OSNotificationResult * result = [[OSNotificationResult alloc] initWithNotification:notification action:action];
    
    //Prevent duplicate calls to same action
    static NSString* lastMessageID = @"";
    if([payload.notificationID isEqualToString:lastMessageID]) return;
    lastMessageID = payload.notificationID;
    
    handleNotificationAction(result);
}

+(NSNumber*)getNetType {
    OneSignalReachability* reachability = [OneSignalReachability reachabilityForInternetConnection];
    NetworkStatus status = [reachability currentReachabilityStatus];
    if (status == ReachableViaWiFi)
        return @0;
    return @1;
}

+ (BOOL) isCapableOfGettingNotificationTypes {
    return [[UIApplication sharedApplication] respondsToSelector:@selector(currentUserNotificationSettings)];
}

+ (UILocalNotification*)createUILocalNotification:(NSDictionary*)data {
    
    UILocalNotification * notification = [[UILocalNotification alloc] init];
    
    id category = [[NSClassFromString(@"UIMutableUserNotificationCategory") alloc] init];
    [category setIdentifier:@"__dynamic__"];
    
    Class UIMutableUserNotificationActionClass = NSClassFromString(@"UIMutableUserNotificationAction");
    NSMutableArray* actionArray = [[NSMutableArray alloc] init];
    for (NSDictionary* button in data[@"o"]) {
        id action = [[UIMutableUserNotificationActionClass alloc] init];
        [action setTitle:button[@"n"]];
        [action setIdentifier:button[@"i"] ? button[@"i"] : [action title]];
        [action setActivationMode:UIUserNotificationActivationModeForeground];
        [action setDestructive:NO];
        [action setAuthenticationRequired:NO];
        
        [actionArray addObject:action];
        // iOS 8 shows notification buttons in reverse in all cases but alerts. This flips it so the frist button is on the left.
        if (actionArray.count == 2)
            [category setActions:@[actionArray[1], actionArray[0]] forContext:UIUserNotificationActionContextMinimal];
    }
    
    [category setActions:actionArray forContext:UIUserNotificationActionContextDefault];
    
    Class uiUserNotificationSettings = NSClassFromString(@"UIUserNotificationSettings");
    NSUInteger notificationTypes = NOTIFICATION_TYPE_ALL;
    
    NSSet* currentCategories = [[[UIApplication sharedApplication] currentUserNotificationSettings] categories];
    if(currentCategories)
        currentCategories = [currentCategories setByAddingObject:category];
    else currentCategories = [NSSet setWithObject:category];
    
    [[UIApplication sharedApplication] registerUserNotificationSettings:[uiUserNotificationSettings settingsForTypes:notificationTypes categories:currentCategories]];
    notification.category = [category identifier];
    return notification;
}

+ (UILocalNotification*)prepareUILocalNotification:(NSDictionary*)data :(NSDictionary*)userInfo {
    
    UILocalNotification * notification = [self createUILocalNotification:data];
    
    if ([data[@"m"] isKindOfClass:[NSDictionary class]]) {
        if ([notification respondsToSelector:NSSelectorFromString(@"alertTitle")])
            [notification setValue:data[@"m"][@"title"] forKey:@"alertTitle"]; // Using reflection for pre-Xcode 6.2 support.
        notification.alertBody = data[@"m"][@"body"];
    }
    else
        notification.alertBody = data[@"m"];
    
    notification.userInfo = userInfo;
    notification.soundName = data[@"s"];
    if (notification.soundName == nil)
        notification.soundName = UILocalNotificationDefaultSoundName;
    if (data[@"b"])
        notification.applicationIconBadgeNumber = [data[@"b"] intValue];
    
    return notification;
}

+ (id)currentNotificationCenter {
    return [NSClassFromString(@"UNUserNotificationCenter") performSelector:@selector(currentNotificationCenter)];
}

//Shared instance as OneSignal is delegate of UNUserNotificationCenterDelegate and CLLocationManagerDelegate
static OneSignal* singleInstance = nil;
+(OneSignal*) sharedInstance {
    @synchronized( singleInstance ) {
        if( !singleInstance ) {
            singleInstance = [[OneSignal alloc] init];
        }
    }
    
    return singleInstance;
}

+ (void)registerAsUNNotificationCenterDelegate {
    
    if(!NSClassFromString(@"UNUserNotificationCenter")) return;
    [[self currentNotificationCenter] setValue:[self sharedInstance] forKey:@"delegate"];

}

+ (void)addnotificationRequest:(NSDictionary *)data :(NSDictionary *)userInfo {
    if(!NSClassFromString(@"UNUserNotificationCenter")) return;
    
    id notificationRequest = [OneSignalHelper prepareUNNotificationRequest:data :userInfo];
    
    
    [[OneSignalHelper currentNotificationCenter] performSelector:@selector(addNotificationRequest:withCompletionHandler:) withObject:notificationRequest withObject:^(NSError * _Nullable error) {}];
}

+ (void)requestAuthorization {
    [[OneSignalHelper currentNotificationCenter] performSelector:@selector(requestAuthorizationWithOptions:completionHandler:) withObject:@7 withObject:^(BOOL granted, NSError * _Nullable error) {}];
}

+ (void)conformsToUNProtocol {
    if (class_conformsToProtocol([UIApplication delegateClass], NSProtocolFromString(@"UNUserNotificationCenterDelegate"))) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:@"Implementing iOS 10's UNUserNotificationCenterDelegate protocol will result in unexpected outcome. Instead, conform to our similar OSUserNotificationCenterDelegate protocol."];
    }
}

//Synchroneously downloads a media
//On success returns bundle resource name, otherwise returns nil
+(NSString*) downloadMediaAndSaveInBundle:(NSString*) url {
    
    NSArray<NSString*>* supportedExtensions = @[@"aiff", @"wav", @"mp3", @"mp4", @"jpg", @"jpeg", @"png", @"gif", @"mpeg", @"mpg", @"avi", @"m4a", @"m4v"];
    NSArray* components = [url componentsSeparatedByString:@"."];
    
    //URL is not to a file
    if ([components count] < 2) return NULL;
    NSString * extension = [components lastObject];
    
    //Unrecognized extention
    if(![supportedExtensions containsObject:extension]) return NULL;
    
    NSURL * URL = [NSURL URLWithString:url];
    NSData * data = [NSData dataWithContentsOfURL:URL];
    NSString *name = [[self randomStringWithLength:10] stringByAppendingString:[NSString stringWithFormat:@".%@", extension]];
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* filePath = [paths[0] stringByAppendingPathComponent:name];
    NSError* error;
    [data writeToFile:filePath options:NSDataWritingAtomic error:&error];
    NSArray * cachedFiles = [[NSUserDefaults standardUserDefaults] objectForKey:@"CACHED_MEDIA"];
    NSMutableArray* appendedCache;
    if (cachedFiles) {
        appendedCache = [[NSMutableArray alloc] initWithArray:cachedFiles];
        [appendedCache addObject:name];
    }
    else appendedCache = [[NSMutableArray alloc] initWithObjects:name, nil];
    
    [[NSUserDefaults standardUserDefaults] setObject:appendedCache forKey:@"CACHED_MEDIA"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return name;
}

+(void)clearCachedMedia {
    
    NSArray * cachedFiles = [[NSUserDefaults standardUserDefaults] objectForKey:@"CACHED_MEDIA"];
    if(cachedFiles) {
        
        NSArray * paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        for (NSString* file in cachedFiles) {
            NSString* filePath = [paths[0] stringByAppendingPathComponent:file];
            NSError* error;
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
        }
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CACHED_MEDIA"];
    }
}

+(NSString*)randomStringWithLength:(int)length {
    
    const NSString * letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [[NSMutableString alloc] initWithCapacity:length];
    for(int i = 0; i < length; i++) {
        uint32_t ln = (uint32_t)[letters length];
        uint32_t rand = arc4random_uniform(ln);
        [randomString appendFormat:@"%C", [letters characterAtIndex:rand]];
    }
    return randomString;
}

+ (id)prepareUNNotificationRequest:(NSDictionary *)data :(NSDictionary *)userInfo {
    
    if(!NSClassFromString(@"UNNotificationAction") || !NSClassFromString(@"UNNotificationRequest")) return NULL;
    
    NSMutableArray * actionArray = [[NSMutableArray alloc] init];
    for( NSDictionary* button in data[@"o"]) {
        NSString* title = button[@"n"] != NULL ? button[@"n"] : @"";
        NSString* buttonID = button[@"i"] != NULL ? button[@"i"] : title;
        id action = [NSClassFromString(@"UNNotificationAction") performSelector2:@selector(actionWithIdentifier:title:options:) withObjects:@[buttonID, title, @4]];
        [actionArray addObject:action];
    }
    
    if ([actionArray count] == 2)
        actionArray = (NSMutableArray*)[[actionArray reverseObjectEnumerator] allObjects];
    
    id category = [[NSClassFromString(@"UNNotificationCategory") class] performSelector2:@selector(categoryWithIdentifier:actions:intentIdentifiers:options:) withObjects:@[@"__dynamic__", actionArray, @[], @1]];
    
    NSSet* set = [[NSSet alloc] initWithArray:@[category]];
    
    [[self currentNotificationCenter] performSelector:@selector(setNotificationCategories:) withObject:set];
    
    id content = [[NSClassFromString(@"UNMutableNotificationContent") alloc] init];
    [content setValue:@"__dynamic__" forKey:@"categoryIdentifier"];
    
    if(data[@"m"][@"title"])
        [content setValue:data[@"m"][@"title"] forKey:@"title"];
    
    if(data[@"m"][@"body"])
        [content setValue:data[@"m"][@"body"] forKey:@"body"];
    
    [content setValue:userInfo forKey:@"userInfo"];
    
    if(data[@"s"]) {
        
        id defaultSound = [NSClassFromString(@"UNNotificationSound") performSelector:@selector(soundNamed:) withObject:data[@"s"]];
        [content setValue:defaultSound forKey:@"sound"];
    }
    
    else
        [content setValue:[NSClassFromString(@"UNNotificationSound") performSelector:@selector(defaultSound)] forKey:@"sound"];
    
    [content setValue:data[@"b"] forKey:@"badge"];
    
    //Check if media attached
    //!! TEMP : Until Server implements Media Dict, use additional data dict as key val media
    NSMutableArray *attachments = [NSMutableArray new];
    
    NSDictionary * att = userInfo[@"custom"][@"at"];
    if(!attachments)
        attachments = userInfo[@"os_data"][@"at"];
    
    for(id key in att) {
        NSString * URI = [att valueForKey:key];
        
        /* Remote Object */
        if ([self verifyURL:URI]) {
            /* Synchroneously download file and chache it */
            NSString* name = [OneSignalHelper downloadMediaAndSaveInBundle:URI];
            if (!name) continue;
            NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString*filePath = [paths[0] stringByAppendingPathComponent:name];
            NSURL * url = [NSURL fileURLWithPath:filePath];
            id attachment = [NSClassFromString(@"UNNotificationAttachment") performSelector2:@selector(attachmentWithIdentifier:URL:options:error:) withObjects:@[key, url, @0]];
            if (attachment)
                [attachments addObject:attachment];
        }
        /* Local in bundle resources */
        else {
            NSMutableArray* files = [[NSMutableArray alloc] initWithArray:[URI componentsSeparatedByString:@"."]];
            if ([files count] < 2) continue;
            NSString* extension = [files lastObject];
            [files removeLastObject];
            NSString * name = [files componentsJoinedByString:@"."];
            //Make sure resource exists
            NSURL * url = [[NSBundle mainBundle] URLForResource:name withExtension:extension];
            if (url) {
                NSError *error;
                
                id attachment = [NSClassFromString(@"UNNotificationAttachment") performSelector2:@selector(attachmentWithIdentifier:URL:options:error:) withObjects:@[key, url, @0, error]];
                if (attachment)
                    [attachments addObject:attachment];
            }
        }
    }
    
    [content setValue:[[NSArray alloc] initWithArray:attachments] forKey:@"attachments"];
    
    
    id trigger = [NSClassFromString(@"UNTimeIntervalNotificationTrigger") performSelector2:@selector(triggerWithTimeInterval:repeats:) withObjects: @[@0.25, [NSNumber numberWithBool:NO]]];
    
    return [NSClassFromString(@"UNNotificationRequest") performSelector2:@selector(requestWithIdentifier:content:trigger:) withObjects: @[@"__dynamic__", content, trigger]];
}

+ (BOOL)verifyURL:(NSString *)urlString {
    if (urlString) {
        NSURL* url = [NSURL URLWithString:urlString];
        if (url)
            return YES;
    }
    
    
    return NO;
}

+ (void)enqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    [self enqueueRequest:request onSuccess:successBlock onFailure:failureBlock isSynchronous:false];
}

+ (void)enqueueRequest:(NSURLRequest*)request onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock isSynchronous:(BOOL)isSynchronous {
    
    [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message: [NSString stringWithFormat:@"request.body: %@", [[NSString alloc]initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]]];
    
    if (isSynchronous) {
        NSURLResponse* response = nil;
        NSError* error = nil;
        
        [NSURLConnection sendSynchronousRequest:request
                              returningResponse:&response
                                          error:&error];
        
        [OneSignalHelper handleJSONNSURLResponse:response data:nil error:error onSuccess:successBlock onFailure:failureBlock];
    }
    else {
        [NSURLConnection
         sendAsynchronousRequest:request
         queue:[[NSOperationQueue alloc] init]
         completionHandler:^(NSURLResponse* response,
                             NSData* data,
                             NSError* error) {
             [OneSignalHelper handleJSONNSURLResponse:response data:data error:error onSuccess:successBlock onFailure:failureBlock];
         }];
    }
}

+ (void)handleJSONNSURLResponse:(NSURLResponse*) response data:(NSData*) data error:(NSError*) error onSuccess:(OSResultSuccessBlock)successBlock onFailure:(OSFailureBlock)failureBlock {
    
    NSHTTPURLResponse* HTTPResponse = (NSHTTPURLResponse*)response;
    NSInteger statusCode = [HTTPResponse statusCode];
    NSError* jsonError = nil;
    NSMutableDictionary* innerJson;
    
    if (data != nil && [data length] > 0) {
        innerJson = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
        if (jsonError) {
            if (failureBlock != nil)
                failureBlock([NSError errorWithDomain:@"OneSignal Error" code:statusCode userInfo:@{@"returned" : jsonError}]);
            return;
        }
    }
    
    if (error == nil && statusCode == 200) {
        if (successBlock != nil) {
            if (innerJson != nil)
                successBlock(innerJson);
            else
                successBlock(nil);
        }
    }
    else if (failureBlock != nil) {
        if (innerJson != nil && error == nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"returned" : innerJson}]);
        else if (error != nil)
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:@{@"error" : error}]);
        else
            failureBlock([NSError errorWithDomain:@"OneSignalError" code:statusCode userInfo:nil]);
    }
}

+ (void) displayWebView:(NSURL*)url {
    
    //Check if in-app or safari
    BOOL inAppLaunch = YES;
    if(![[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_INAPP_LAUNCH_URL"]) {
        [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"ONESIGNAL_INAPP_LAUNCH_URL"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    inAppLaunch = [[[NSUserDefaults standardUserDefaults] objectForKey:@"ONESIGNAL_INAPP_LAUNCH_URL"] boolValue];
    
    if(inAppLaunch) {
        if(!webVC)
            webVC = [[OneSignalWebView alloc] init];
        webVC.url = url;
        [webVC showInApp];
    }
    else [[UIApplication sharedApplication] openURL:url];
    
}

#pragma clang diagnostic pop
#pragma clang diagnostic pop
#pragma clang diagnostic pop
@end
