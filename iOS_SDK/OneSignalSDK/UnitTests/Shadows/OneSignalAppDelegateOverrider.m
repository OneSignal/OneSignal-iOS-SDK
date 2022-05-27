#import "OneSignalAppDelegateOverrider.h"

#import "TestHelperFunctions.h"

#import "OneSignalSelectorHelpers.h"
#import "UIApplicationDelegate+OneSignal.h"

@implementation OneSignalAppDelegateOverrider

static NSMutableDictionary* callCount;

+ (void)load {
    callCount = [NSMutableDictionary new];

    injectStaticSelector(
        [OneSignalAppDelegateOverrider class],
        @selector(overrideTraceCall:),
        [OneSignalAppDelegate class],
        @selector(traceCall:)
    );
}

+ (void)reset {
    callCount = [NSMutableDictionary new];
}

+ (void)overrideTraceCall:(NSString*)selector {
    NSNumber *value = callCount[selector];
    callCount[selector] = [NSNumber numberWithInt:[value intValue] + 1];
}

+ (int)callCountForSelector:(NSString*)selector {
    return [callCount[selector] intValue];
}
@end
