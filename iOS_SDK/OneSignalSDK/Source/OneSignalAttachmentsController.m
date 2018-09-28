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

#import <Foundation/Foundation.h>
#import "OneSignalAttachmentsController.h"
#import "OneSignalCommonDefines.h"
#import "NSString+OneSignal.h"
#import "NSURL+OneSignal.h"
#import "NSURLSession+OneSignal.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation OneSignalAttachmentsController

+ (NSMutableSet<UNNotificationCategory*>*)existingCategories {
    __block NSMutableSet* allCategories;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    [notificationCenter getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *categories) {
        allCategories = [categories mutableCopy];
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return allCategories;
}

+ (void)addActionButtons:(OSNotificationPayload*)payload toNotificationContent:(UNMutableNotificationContent*)content {
    if (!payload.actionButtons || payload.actionButtons.count == 0)
        return;
    
    NSMutableArray<UNNotificationAction *> *actionArray = [NSMutableArray new];
    for(NSDictionary* button in payload.actionButtons) {
        UNNotificationAction *action = [UNNotificationAction actionWithIdentifier:button[@"id"]
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
    NSMutableSet<UNNotificationCategory*> *allCategories = [self existingCategories];
    
    UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:@"__dynamic__"
                                                          actions:finalActionArray
                                                intentIdentifiers:@[]
                                                          options:UNNotificationCategoryOptionCustomDismissAction];
    
    if (allCategories) {
        NSMutableSet<UNNotificationCategory *> *newCategorySet = [NSMutableSet new];
        for(UNNotificationCategory *existingCategory in allCategories) {
            if (![existingCategory.identifier isEqualToString:@"__dynamic__"])
                [newCategorySet addObject:existingCategory];
        }
        
        [newCategorySet addObject:category];
        allCategories = newCategorySet;
    }
    else
        allCategories = [[NSMutableSet alloc] initWithArray:@[category]];
    
    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:allCategories];
    
    content.categoryIdentifier = @"__dynamic__";
}

/*
 Synchroneously downloads an attachment
 On success returns bundle resource name, otherwise returns nil
 The preference order for file type determination is as follows:
 1. File extension in the actual URL
 2. MIME type
 3. URL Query parameter called 'filename', such as test.jpg. The SDK will extract the file extension from it
 */
+ (NSString*)downloadMediaAndSaveInBundle:(NSString*)urlString {
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSString* extension = url.pathExtension;
    
    if ([extension isEqualToString:@""])
        extension = nil;
    
    // Unrecognized extention
    if (extension != nil && ![ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES containsObject:extension])
        return nil;
    
    NSString *name = [NSString randomStringWithLength:10];
    
    if (extension)
        name = [name stringByAppendingString:[NSString stringWithFormat:@".%@", extension]];
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* filePath = [paths[0] stringByAppendingPathComponent:name];
    
    //guard against situations where for example, available storage is too low
    
    @try {
        NSError* error;
        NSString *mimeType = [NSURLSession downloadItemAtURL:url toFile:filePath error:&error];
        
        if (error) {
            NSLog(@"Encountered an error while attempting to download file with URL: %@", error);
            return nil;
        }
        
        if (!extension) {
            NSString *newExtension;
            
            if (mimeType != nil && ![mimeType isEqualToString:@""]) {
                newExtension = mimeType.fileExtensionForMimeType;
            } else {
                newExtension = [[[NSURL URLWithString:urlString] valueFromQueryParameter:@"filename"] supportedFileExtension];
            }
            
            if (!newExtension || ![ONESIGNAL_SUPPORTED_ATTACHMENT_TYPES containsObject:newExtension])
                return nil;
            
            name = [NSString stringWithFormat:@"%@.%@", name, newExtension];
            
            NSString *newPath = [paths[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", name]];
            
            [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:newPath error:&error];
        }
        
        if (error) {
            NSLog(@"Encountered an error while attempting to download file with URL: %@", error);
            return nil;
        }
        
        NSArray* cachedFiles = [[NSUserDefaults standardUserDefaults] objectForKey:@"CACHED_MEDIA"];
        NSMutableArray* appendedCache;
        if (cachedFiles) {
            appendedCache = [[NSMutableArray alloc] initWithArray:cachedFiles];
            [appendedCache addObject:name];
        }
        else
            appendedCache = [[NSMutableArray alloc] initWithObjects:name, nil];
        
        [[NSUserDefaults standardUserDefaults] setObject:appendedCache forKey:@"CACHED_MEDIA"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return name;
    } @catch (NSException *exception) {
        NSLog(@"OneSignal encountered an exception while downloading file (%@), exception: %@", url, exception.description);
        
        return nil;
    }
    
}

+ (void)addAttachments:(OSNotificationPayload*)payload
 toNotificationContent:(UNMutableNotificationContent*)content {
    if (!payload.attachments)
        return;
    
    NSMutableArray *unAttachments = [NSMutableArray new];
    
    for(NSString* key in payload.attachments) {
        NSString *URI = [[payload.attachments valueForKey:key] stringByRemovingWhitespace];
        
        NSURL *nsURL = [NSURL URLWithString:URI];
        
        // Remote media attachment */
        if (nsURL && [nsURL isWWWScheme]) {
            // Synchroneously download file and chache it
            NSString *name = [self downloadMediaAndSaveInBundle:URI];
            
            if (!name)
                continue;
            
            NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            NSString *filePath = [paths[0] stringByAppendingPathComponent:name];
            NSURL *url = [NSURL fileURLWithPath:filePath];
            NSError* error;
            UNNotificationAttachment *attachment = [UNNotificationAttachment
                              attachmentWithIdentifier:key
                              URL:url
                              options:0
                              error:&error];
            if (attachment)
                [unAttachments addObject:attachment];
        }
        // Local in bundle resources
        else {
            NSMutableArray<NSString *> *files = [[NSMutableArray alloc] initWithArray:[URI componentsSeparatedByString:@"."]];
            if (files.count < 2)
                continue;
            
            NSString *extension = [files lastObject];
            [files removeLastObject];
            NSString *name = [files componentsJoinedByString:@"."];
            
            //Make sure resource exists
            NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:extension];
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

@end

#pragma clang diagnostic pop
#pragma clang diagnostic pop
