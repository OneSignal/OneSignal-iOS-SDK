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

#import "OneSignalNotificationCategoryController.h"
#import "OneSignalExtensionBadgeHandler.h"
#import "OneSignalHelper.h"
#import "OneSignalCommonDefines.h"

#define CATEGORY_FORMAT_STRING(notificationId) [NSString stringWithFormat:@"__onesignal__dynamic__%@", notificationId]

@implementation OneSignalNotificationCategoryController

+ (OneSignalNotificationCategoryController *)sharedInstance {
    static OneSignalNotificationCategoryController *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [OneSignalNotificationCategoryController new];
    });
    return sharedInstance;
}

// appends the new category ID to the current saved array of category ID's
// The array is then inherently sorted in ascending order (the ID at index 0 is the oldest)
// we want to run this on the main thread so that the extension service doesn't stop before it finishes
// To prevent the SDK from registering too many categories as time goes by, we will prune the categories
// when more than MAX_CATEGORIES_SIZE have been registered
- (void)saveCategoryId:(NSString *)categoryId {
    let defaults = [[NSUserDefaults alloc] initWithSuiteName:OneSignalExtensionBadgeHandler.appGroupName];
    
    NSMutableArray<NSString *> *mutableExisting = [self.existingRegisteredCategoryIds mutableCopy];
    
    [mutableExisting addObject:categoryId];
    
    // prune array if > max size
    if (mutableExisting.count > MAX_CATEGORIES_SIZE) {
        
        // removes these categories from UNUserNotificationCenter
        [self pruneCategories:mutableExisting];
        
        [mutableExisting removeObjectsInRange:NSMakeRange(0, mutableExisting.count - MAX_CATEGORIES_SIZE)];
    }
    
    
    [defaults setObject:mutableExisting forKey:SHARED_CATEGORY_LIST];
    
    [defaults synchronize];
}

- (NSArray<NSString *> *)existingRegisteredCategoryIds {
    let defaults = [[NSUserDefaults alloc] initWithSuiteName:OneSignalExtensionBadgeHandler.appGroupName];
    
    NSArray<NSString *> *existing = [defaults arrayForKey:SHARED_CATEGORY_LIST] ?: [NSArray new];
    
    return existing;
}

- (void)pruneCategories:(NSMutableArray <NSString *> *)currentCategories {
    NSMutableSet<NSString *> *categoriesToRemove = [NSMutableSet new];
    
    for (int i = (int)currentCategories.count - MAX_CATEGORIES_SIZE; i >= 0; i--)
        [categoriesToRemove addObject:currentCategories[i]];
    
    let existingCategories = self.existingCategories;
    
    NSMutableSet<UNNotificationCategory *> *newCategories = [NSMutableSet new];
    
    for (UNNotificationCategory *category in existingCategories)
        if (![categoriesToRemove containsObject:category.identifier])
            [newCategories addObject:category];
    
    [UNUserNotificationCenter.currentNotificationCenter setNotificationCategories:newCategories];
}

- (NSString *)registerNotificationCategoryForNotificationId:(NSString *)notificationId {
    // if the notificationID is null/empty, just generate a random new UUID
    let categoryId = CATEGORY_FORMAT_STRING(notificationId ?: NSUUID.UUID.UUIDString);
    
    [self saveCategoryId:categoryId];
    
    return categoryId;
}

- (NSMutableSet<UNNotificationCategory*>*)existingCategories {
    __block NSMutableSet* allCategories;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    let notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    [notificationCenter getNotificationCategoriesWithCompletionHandler:^(NSSet<UNNotificationCategory *> *categories) {
        allCategories = [categories mutableCopy];
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return allCategories;
}

@end
