
#import "DelayedSelectors.h"
#import "OneSignalHelper.h"

@interface SelectorToRun : NSObject
@property NSObject* runOn;
@property SEL selector;
@property NSObject* withObject;
@end

@implementation SelectorToRun
@end

@implementation DelayedSelectors {
    NSMutableArray<SelectorToRun*>* selectorsToRun;
}
- (instancetype) init {
    self = [super init];
    selectorsToRun = [NSMutableArray new];
    return self;
}

- (void)addSelector:(SEL)aSelector onObject:(id)object withObject:(nullable id)anArgument {
    let selectorToRun = [SelectorToRun alloc];
    selectorToRun.runOn = object;
    selectorToRun.selector = aSelector;
    selectorToRun.withObject = anArgument;
    @synchronized(selectorsToRun) {
        [selectorsToRun addObject:selectorToRun];
    }
}

- (void)runPendingSelectors {
    @synchronized(selectorsToRun) {
        for(SelectorToRun* selectorToRun in selectorsToRun)
            [selectorToRun.runOn performSelector:selectorToRun.selector withObject:selectorToRun.withObject];
        
        [selectorsToRun removeAllObjects];
    }
}

@end
