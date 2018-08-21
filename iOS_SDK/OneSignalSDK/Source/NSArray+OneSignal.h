//
//  NSArray+OneSignal.h
//  OneSignal
//
//  Created by Brad Hesse on 8/20/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (OneSignal)

- (nonnull NSArray *)os_arrayByRemovingNullValues;

@end
