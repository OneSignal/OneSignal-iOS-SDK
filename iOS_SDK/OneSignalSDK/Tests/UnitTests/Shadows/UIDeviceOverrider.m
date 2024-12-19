#import "UIDeviceOverrider.h"
#import "TestHelperFunctions.h"
#import "OneSignalSelectorHelpers.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation UIDeviceOverrider
#pragma clang diagnostic pop
static NSString *_systemName; // e.g. @"Mac OS X" @"iOS"
static NSString *_model; // e.g. @"iPhone", @"iPod touch"

- (NSString *)overrideSystemName {
    return _systemName;
}

- (NSString *)overrideModel {
    return _model;
}

// used for tests
+ (void)setSystemName:(NSString*) name {
    _systemName = name;
}

+ (void)setModel:(NSString*) model {
    _model = model;
}

+ (void)load {
    injectSelector(
        [UIDevice class],
        @selector(systemName),
        [UIDeviceOverrider class],
        @selector(overrideSystemName)
    );
    injectSelector(
       [UIDevice class],
       @selector(model),
       [UIDeviceOverrider class],
       @selector(overrideModel)
   );
}

+ (void)reset {
    // By default, this is value for tests (Simulator)
    _model = @"iPhone";
    _systemName = @"iOS";
}

@end
