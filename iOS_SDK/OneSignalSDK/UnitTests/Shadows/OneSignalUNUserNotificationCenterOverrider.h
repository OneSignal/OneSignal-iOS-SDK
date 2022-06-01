#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OneSignalUNUserNotificationCenterOverrider : NSObject
+ (int)callCountForSelector:(NSString*)selector;
+ (void)reset;
@end

NS_ASSUME_NONNULL_END
