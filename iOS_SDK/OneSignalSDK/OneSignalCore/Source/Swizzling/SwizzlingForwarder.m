#import "SwizzlingForwarder.h"

@implementation SwizzlingForwarder {
    id targetObject;
    SEL targetSelector;
}

-(instancetype)initWithTarget:(id)object
             withYourSelector:(SEL)yourSelector
         withOriginalSelector:(SEL)originalSelector {
    self = [super init];

    // If the class had a pre-existing selector
    if ([object respondsToSelector:yourSelector]) {
        targetObject = object;
        targetSelector = yourSelector;
    }
    else {
        id forwardingTarget = [object forwardingTargetForSelector:originalSelector];
        // If there is a forwarding object and ensuring it does have the selector
        // The most common case for this is a SwiftUI app with
        // @UIApplicationDelegateAdaptor
        if (forwardingTarget && [forwardingTarget respondsToSelector:originalSelector]) {
            targetObject = forwardingTarget;
            targetSelector = originalSelector;
        }
    }

    return self;
}

-(BOOL)hasReceiver {
    return targetObject != nil;
}

+(void)callSelector:(SEL)selector
           onObject:(id)object
           withArgs:(NSArray*)args {
    NSMethodSignature *methodSignature = [object methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    [invocation setSelector:selector];
    [invocation setTarget:object];
    for(int i = 0; i < methodSignature.numberOfArguments - 2; i++) {
        id argv = [args objectAtIndex:i];
        [invocation setArgument:&argv atIndex:i + 2];
    }

    [invocation invoke];
}

-(void)invokeWithArgs:(NSArray*)args {
    if (!targetObject)
        return;

    [SwizzlingForwarder
        callSelector:targetSelector
        onObject:targetObject
        withArgs:args];
}
@end
