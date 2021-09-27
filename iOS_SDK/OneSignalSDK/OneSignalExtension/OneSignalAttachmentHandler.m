//
//  OneSignalAttachmentHandler.m
//  OneSignalExtension
//
//  Created by Elliot Mawby on 9/27/21.
//  Copyright © 2021 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSignalAttachmentHandler.h"
#import "OneSignalNotificationCategoryController.h"

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

@implementation OneSignalAttachmentHelper

+ (void)addActionButtons:(OSNotification*)notification
   toNotificationContent:(UNMutableNotificationContent*)content {
    if (!notification.actionButtons || notification.actionButtons.count == 0)
        return;
    
    let actionArray = [NSMutableArray new];
    for(NSDictionary* button in notification.actionButtons) {
        let action = [self createActionForButton:button];
        [actionArray addObject:action];
    }
    
    NSArray* finalActionArray;
    if (actionArray.count == 2)
        finalActionArray = [[actionArray reverseObjectEnumerator] allObjects];
    else
        finalActionArray = actionArray;
    
    // Get a full list of categories so we don't replace any exisiting ones.
    var allCategories = OneSignalNotificationCategoryController.sharedInstance.existingCategories;
    
    let newCategoryIdentifier = [OneSignalNotificationCategoryController.sharedInstance registerNotificationCategoryForNotificationId:notification.notificationId];
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

+ (void)addAttachments:(OSNotification*)notification
 toNotificationContent:(UNMutableNotificationContent*)content {
    if (!notification.attachments)
        return;
    
    let unAttachments = [NSMutableArray new];
    
    for(NSString* key in notification.attachments) {
        let URI = [OneSignalAttachmentHelper trimURLSpacing:[notification.attachments valueForKey:key]];
        
        let nsURL = [NSURL URLWithString:URI];
        
        // Remote media attachment */
        if (nsURL && [self isWWWScheme:nsURL]) {
            // Synchroneously download file and chache it
            let name = [self downloadMediaAndSaveInBundle:URI];
            
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

+ (UNNotificationAction *)createActionForButton:(NSDictionary *)button {
    NSString *buttonId = button[@"id"];
    NSString *buttonText = button[@"text"];
    
    if (@available(iOS 15.0, *)) {
        // Using reflection for Xcode versions lower than 13
        id icon; // UNNotificationActionIcon
        let UNNotificationActionIconClass = NSClassFromString(@"UNNotificationActionIcon");
        if (UNNotificationActionIconClass) {
            if (button[@"systemIcon"]) {
                icon = [UNNotificationActionIconClass performSelector:@selector(iconWithSystemImageName:)
                                                           withObject:button[@"systemIcon"]];
            } else if (button[@"templateIcon"]) {
                icon = [UNNotificationActionIconClass performSelector:@selector(iconWithTemplateImageName:)
                                                           withObject:button[@"templateIcon"]];
            }
        }
        
        // We need to use NSInvocation because performSelector only allows up to 2 arguments
        SEL actionSelector = NSSelectorFromString(@"actionWithIdentifier:title:options:icon:");
        UNNotificationAction * __unsafe_unretained action;
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UNNotificationAction methodSignatureForSelector:actionSelector]];
        [invocation setTarget:[UNNotificationAction class]];
        [invocation setSelector:actionSelector];
        /*
         From Apple's Documentation on NSInvocation:
         Indices 0 and 1 indicate the hidden arguments self and _cmd, respectively;
         you should set these values directly with the target and selector properties.
         Use indices 2 and greater for the arguments normally passed in a message.
        */
        NSUInteger actionOption = UNNotificationActionOptionForeground;
        [invocation setArgument:&buttonId atIndex:2];
        [invocation setArgument:&buttonText atIndex:3];
        [invocation setArgument:&actionOption atIndex:4];
        [invocation setArgument:&icon atIndex:5];
        [invocation invoke];
        [invocation getReturnValue:&action];
        return action;
    } else {
        return [UNNotificationAction actionWithIdentifier:buttonId
                                                    title:buttonText
                                                  options:UNNotificationActionOptionForeground];
    }
}

+ (NSString*)trimURLSpacing:(NSString*)url {
    if (!url)
        return url;
    
    return [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}


/*
 Synchroneously downloads an attachment
 On success returns bundle resource name, otherwise returns nil
*/
+ (NSString *)downloadMediaAndSaveInBundle:(NSString *)urlString {
    
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
            [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error while attempting to download file with URL: %@", error]];
            return nil;
        }

        NSString *extension = [self getSupportedFileExtensionFromURL:url mimeType:mimeType];
        if (!extension || [extension isEqualToString:@""])
            return nil;

        name = [NSString stringWithFormat:@"%@.%@", name, extension];

        let newPath = [paths[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", name]];

        [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newPath error:&error];
        
        if (error) {
            [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Encountered an error while attempting to download file with URL: %@", error]];
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
        [OneSignalLog onesignalLog:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"OneSignal encountered an exception while downloading file (%@), exception: %@", url, exception.description]];
        
        return nil;
    }
}

+ (BOOL)isWWWScheme:(NSURL*)url {
    NSString* urlScheme = [url.scheme lowercaseString];
    return [urlScheme isEqualToString:@"http"] || [urlScheme isEqualToString:@"https"];
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



@end
