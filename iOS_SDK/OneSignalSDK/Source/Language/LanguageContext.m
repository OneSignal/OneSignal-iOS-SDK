#import "LanguageContext.h"
#import "LanguageProvider.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalHelper.h"
#import "LanguageProviderDevice.h"
#import "LanguageProviderAppDefined.h"

@implementation LanguageContext {

    NSObject<LanguageProvider> *strategy;
}

- (instancetype)init {
    self = [super init];
    let languageAppDefined = [OneSignalUserDefaults.initStandard  getSavedStringForKey:OSUD_LANGUAGE defaultValue:nil];
    if (languageAppDefined == nil) {
        strategy = [LanguageProviderDevice new];
    } else {
        strategy = [LanguageProviderAppDefined new];
    }
    return self;
}

- (void)setStrategy:(NSObject<LanguageProvider>*)newStrategy {
    strategy = newStrategy;
}

- (NSString *)language {
    return strategy.language;
}
@end
