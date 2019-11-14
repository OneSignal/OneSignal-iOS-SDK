#import "UIDeviceOverrider.h"
#import "TestHelperFunctions.h"
#import "OneSignalSelectorHelpers.h"


@implementation UIDeviceOverrider

static NSString *_systemName;
static NSString *_model;

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
    injectToProperClass(@selector(overrideSystemName), @selector(systemName), @[], [UIDeviceOverrider class], [UIDevice class]);
    injectToProperClass(@selector(overrideModel), @selector(model), @[], [UIDeviceOverrider class], [UIDevice class]);
}

+ (void)reset {
    // By default, this is value for tests (Simulator)
    _model = @"iPhone";
    _systemName = @"iOS";
}

@end
