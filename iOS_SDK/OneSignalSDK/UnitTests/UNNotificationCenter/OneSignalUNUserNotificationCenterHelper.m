#import "OneSignalUNUserNotificationCenterHelper.h"

#import "UNUserNotificationCenter+OneSignal.h"
#import "OneSignalHelper.h"

@implementation OneSignalUNUserNotificationCenterHelper

// Call this after you assign UNUserNotificationCenter.currentNotificationCenter.delegate to restore
//   the delegate as well as swizzling effects.
// In a nutshell this swizzles a 2nd time in reverse to swap method implementations back.
+ (void)restoreDelegateAsOneSignal {
    // Undo swizzling of notification events by swizzling again to swap method implementations back.
    [OneSignalUNUserNotificationCenter swizzleSelectorsOnDelegate:UNUserNotificationCenter.currentNotificationCenter.delegate];

    // Temp unswizzle setDelegate, so we can re-assign the delegate below without side-effects.
    [OneSignalUNUserNotificationCenter swizzleSelectors];

    // Clear the delegate and call registerAsUNNotificationCenterDelegate so it assigns OneSignal
    //   as the delegate like it does the first time when it is loaded into memory.
    UNUserNotificationCenter.currentNotificationCenter.delegate = nil;
    [OneSignalHelper registerAsUNNotificationCenterDelegate];

    // Undo our temp unswizzle by swizzle one more time. Undo our undo :)
    [OneSignalUNUserNotificationCenter swizzleSelectors];
}
@end
