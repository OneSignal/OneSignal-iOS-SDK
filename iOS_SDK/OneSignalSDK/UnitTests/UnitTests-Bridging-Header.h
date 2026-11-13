//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "OneSignalFramework.h"
#import "OSOutcomesRequests.h"
#import "OneSignalTracker.h"
#import "UIApplicationOverrider.h"
#import "OSFocusTimeProcessorFactory.h"
#import "NSDateOverrider.h"
#import <OneSignalOutcomes/OneSignalOutcomes.h>

@interface OneSignalTracker (Testing)
+ (void)applicationBackgrounded;
@end

@interface OneSignal (Testing)
+ (void)startNewSessionInternal:(BOOL)deduplicate;
@end

static inline void OSTestRouteSessionEndingToOneSignal(void) {
    [OSSessionManager sharedSessionManager].delegate = (id<SessionStatusDelegate>)[OneSignal class];
}
