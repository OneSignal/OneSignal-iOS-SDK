// TODO: Commented out 🧪
#import "OneSignalUNUserNotificationCenterOverrider.h"
//
//#import "TestHelperFunctions.h"
//#import "UNUserNotificationCenter+OneSignal.h"
//
@implementation OneSignalUNUserNotificationCenterOverrider
static NSMutableDictionary* callCount;

//+ (void)load {
//    callCount = [NSMutableDictionary new];
//
//    injectStaticSelector(
//        [OneSignalUNUserNotificationCenterOverrider class],
//        @selector(overrideTraceCall:),
//        [OneSignalUNUserNotificationCenter class],
//        @selector(traceCall:)
//    );
//}

+ (void)reset {
    callCount = [NSMutableDictionary new];
}

//+ (void)overrideTraceCall:(NSString*)selector {
//    NSNumber *value = callCount[selector];
//    callCount[selector] = [NSNumber numberWithInt:[value intValue] + 1];
//}
//
//+ (int)callCountForSelector:(NSString*)selector {
//    return [callCount[selector] intValue];
//}
@end
