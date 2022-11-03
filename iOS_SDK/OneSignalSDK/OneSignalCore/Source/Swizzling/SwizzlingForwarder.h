#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Use this in your swizzled methods implementations to ensure your swizzling
 does not create side effects.
 This is done by checking if there was an existing implementations and also if
 the object has a forwardingTargetForSelector: setup.
 */
@interface SwizzlingForwarder : NSObject
/**
 Constructor to setup this instance so you can call invokeWithArgs latter
 to forward the call onto the correct selector and object so you swizzling does
 create any cause side effects.
 @param object Your object, normally you should pass in self.
 @param yourSelector Your named selector.
 @param originalSelector The original selector, the one you would call if
 swizzling was out of the picture.
 @return Always returns an instance.
 */
-(instancetype)initWithTarget:(id)object
             withYourSelector:(SEL)yourSelector
         withOriginalSelector:(SEL)originalSelector;

/**
 Optionally call before invokeWithArgs to know it will execute anything.
 */
-(BOOL)hasReceiver;

/**
 Must call this to call in your swizzled method somewhere to ensure the
 original code is still run.
 */
-(void)invokeWithArgs:(NSArray*)args;
@end

NS_ASSUME_NONNULL_END
