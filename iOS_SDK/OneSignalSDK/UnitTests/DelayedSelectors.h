//
//  DelayedSelectors.h
//  UnitTests
//
//  Created by Josh Kasten on 11/17/19.
//  Copyright © 2019 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DelayedSelectors : NSObject
- (void)addSelector:(SEL)aSelector onObject:(id)object withObject:(nullable id)anArgument;
- (void)runPendingSelectors;
@end

NS_ASSUME_NONNULL_END
