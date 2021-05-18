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
    [OneSignalUNUserNotificationCenter registerDelegate];

    // Undo our temp unswizzle by swizzle one more time. Undo our undo :)
    [OneSignalUNUserNotificationCenter swizzleSelectors];
}

// OneSignal auto swizzles UNUserNotificationCenterDelegate when the class is loaded into memory.
// This undoes this affect so we can test setup a pre-loaded OneSignal state.
// Why? This way we can setup a senario where someone else's delegate is assigned before OneSignal get loaded.
+ (void)putIntoPreloadedState {
    // Swizzle to undo the swizzle. (yes, swizzling a 2nd time reverses the swizzling)
    [OneSignalUNUserNotificationCenter swizzleSelectors];
    
    // Unassign OneSignal as the delegate
    UNUserNotificationCenter.currentNotificationCenter.delegate = nil;
}
@end
