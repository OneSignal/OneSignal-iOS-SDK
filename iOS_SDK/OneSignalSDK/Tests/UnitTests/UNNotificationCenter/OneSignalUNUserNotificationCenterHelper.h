#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OneSignalUNUserNotificationCenterHelper : NSObject
+ (void)restoreDelegateAsOneSignal;
+ (void)putIntoPreloadedState;
@end

NS_ASSUME_NONNULL_END
