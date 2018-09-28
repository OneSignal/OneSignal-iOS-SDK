//
//  NSDictionary+OneSignal.h
//  OneSignal
//
//  Created by Brad Hesse on 9/26/18.
//  Copyright © 2018 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (OneSignal)
- (BOOL)isOneSignalPayload;
@end

NS_ASSUME_NONNULL_END
