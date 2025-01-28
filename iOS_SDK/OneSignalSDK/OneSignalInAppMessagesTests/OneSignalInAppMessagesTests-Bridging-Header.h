//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "OSInAppMessageInternal.h"
#import "OSMessagingController.h"

// Expose private properties and methods for testing
@interface OSMessagingController (Testing)
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessageInternal *> *messageDisplayQueue;
- (void)presentInAppPreviewMessage:(OSInAppMessageInternal *)message;
@end
