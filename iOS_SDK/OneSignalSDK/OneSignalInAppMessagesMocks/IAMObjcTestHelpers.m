#import "IAMObjcTestHelpers.h"
#import "OSMessagingController.h"

// The displayMessage method is private, we'll expose it here
@interface OSMessagingController ()
@property (strong, nonatomic, nonnull) NSMutableArray <OSInAppMessageInternal *> *messageDisplayQueue;
@end

@implementation OSMessagingController (Tests)
- (NSMutableArray<OSInAppMessageInternal *> *)getDisplayedMessages {
    return self.messageDisplayQueue;
}
@end

@implementation IAMObjcTestHelpers
+ (NSArray *)messageDisplayQueue {
//    OSInAppMessageInternal *testMessage = [OSInAppMessageInternal instanceWithJson:@{@"hi": @"hello"}];
//    return @[testMessage];
    return [OSMessagingController.sharedInstance getDisplayedMessages];
}
@end
