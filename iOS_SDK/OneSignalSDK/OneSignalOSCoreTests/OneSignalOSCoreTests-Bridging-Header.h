//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CrashTestExceptionRaiser : NSObject

/// Returns the exception `block` raised, with the return addresses the runtime captured at the
/// throw. Swift cannot catch an `NSException`, so the `@try` has to live here.
+ (nullable NSException *)exceptionRaisedBy:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
