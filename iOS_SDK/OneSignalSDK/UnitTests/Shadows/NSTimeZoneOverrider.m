#import "NSTimeZoneOverrider.h"
#import "TestHelperFunctions.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation NSTimeZoneOverrider
#pragma clang diagnostic pop
static NSTimeZone *localTimeZone;

+ (NSTimeZone *)overrideLocalTimeZone {
    return localTimeZone;
}

+ (void)setLocalTimeZone:(NSTimeZone *)value {
    localTimeZone = value;
}

+ (void)load {
    injectStaticSelector([NSTimeZoneOverrider class], @selector(overrideLocalTimeZone), [NSTimeZone class], @selector(localTimeZone));

}

@end
