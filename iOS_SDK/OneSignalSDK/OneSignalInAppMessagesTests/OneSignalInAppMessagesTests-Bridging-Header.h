//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "OSInAppMessageInternal.h"
#import "OSMessagingController.h"
#import "OSInAppMessagingRequests.h"

// Expose private properties and methods for testing
@interface OSMessagingController (Testing)
@property (nonatomic) BOOL hasCompletedFirstFetch;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessageInternal *> *messageDisplayQueue;
@property (strong, nonatomic, nonnull) NSMutableSet<NSString *> *earlySessionTriggers;
@property (strong, nonatomic, nonnull) NSMutableDictionary *redisplayedInAppMessages;
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessageInternal *> *messages;
@property (strong, nonatomic, nonnull) OSTriggerController *triggerController;
+ (void)start;
+ (void)removeInstance;
- (void)presentInAppPreviewMessage:(OSInAppMessageInternal *)message;
@end
