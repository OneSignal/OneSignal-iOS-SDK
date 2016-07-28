//
//  NSString+Hash.h
//  OneSignal
//
//  Created by Joseph Kalash on 7/27/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Hash)

- (NSString*)sha1;
- (NSString*)md5;

@end
