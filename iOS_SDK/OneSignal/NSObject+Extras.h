//
//  NSObject+Extras.h
//  OneSignal
//
//  Created by Joseph Kalash on 7/27/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

@interface NSObject (Extras)

// - performSelector version with N arguments
- (id) performSelector2: (SEL) selector withObjects: (NSArray<id>*)objs;

@end
