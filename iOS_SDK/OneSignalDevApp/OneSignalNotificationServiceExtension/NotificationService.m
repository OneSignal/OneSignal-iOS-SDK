#import <OneSignal/OneSignal.h>

#import <UIKit/UIKit.h>

#import "NotificationService.h"

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNNotificationRequest *receivedRequest;
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
  /*
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:[NSOperationQueue new] usingBlock:^(NSNotification * _Nonnull note) {
        NSLog(@"Memory warning received");
    }];
    */
    NSLog(@"######## Start NotificationService!");

    self.receivedRequest = request;
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];
    
    NSLog(@"START!!!!!! request.content.userInfo: %@", request.content.userInfo);
    
    [OneSignal didReceiveNotificationExtensionRequest:self.receivedRequest withMutableNotificationContent:self.bestAttemptContent];
    // DEBUGGING: Uncomment the 2 lines below and comment out the one above to ensure this extension is excuting
    //            Note, this extension only runs when mutable-content is set
    //            Setting an attachment or action buttons automatically adds this
    // NSLog(@"Running NotificationServiceExtension");
    // self.bestAttemptContent.body = [@"[Modi6fied] " stringByAppendingString:self.bestAttemptContent.body];
    
    // Uncomment to keep process alive to profile it's RAM usage.
//    while (true) {
//        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
//    }
    
    
//    [NSThread sleepForTimeInterval:25.0f];
    self.contentHandler(self.bestAttemptContent);
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
//        self.contentHandler(self.bestAttemptContent);
//    });
    
    NSLog(@"######## END NotificationService!");
}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    
    [OneSignal serviceExtensionTimeWillExpireRequest:self.receivedRequest withMutableNotificationContent:self.bestAttemptContent];
    
    self.contentHandler(self.bestAttemptContent);
}

@end
