// TODO: Commented out 🧪
//#import "OneSignalUNUserNotificationCenterHelper.h"
//
//#import "UNUserNotificationCenter+OneSignal.h"
//#import "OneSignalHelper.h"
//#import "OneSignalSelectorHelpers.h"
//
//@implementation OneSignalUNUserNotificationCenterHelper
//
//// Call this after you assign UNUserNotificationCenter.currentNotificationCenter.delegate to restore
////   the delegate as well as swizzling effects.
//+ (void)restoreDelegateAsOneSignal {
//    [OneSignalUNUserNotificationCenter setup];
//}
//
//// OneSignal auto swizzles UNUserNotificationCenterDelegate when the class is loaded into memory.
//// This undoes this affect so we can test setup a pre-loaded OneSignal state.
//// Why? This way we can setup a senario where someone else's delegate is assigned before OneSignal get loaded.
//+ (void)putIntoPreloadedState {
//    // Put back original implementation for setDelegat and others first.
//    injectSelector(
//        [UNUserNotificationCenter class],
//        @selector(setOneSignalUNDelegate:),
//        [OneSignalUNUserNotificationCenter class],
//        @selector(setDelegate:)
//    );
//    injectSelector(
//        [UNUserNotificationCenter class],
//        @selector(onesignalRequestAuthorizationWithOptions:completionHandler:),
//        [OneSignalUNUserNotificationCenter class],
//        @selector(requestAuthorizationWithOptions:completionHandler:)
//    );
//    injectSelector(
//        [UNUserNotificationCenter class],
//        @selector(onesignalGetNotificationSettingsWithCompletionHandler:),
//        [OneSignalUNUserNotificationCenter class],
//        @selector(getNotificationSettingsWithCompletionHandler:)
//    );
//
//    // Unassign OneSignal as the delegate
//    UNUserNotificationCenter.currentNotificationCenter.delegate = nil;
//}
//@end
