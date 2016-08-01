//
//  OneSignalAlertViewDelegate.h
//  OneSignal
//
//  Created by Joseph Kalash on 7/15/16.
//  Copyright © 2016 Hiptic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OneSignalAlertViewDelegate : NSObject <UIAlertViewDelegate>
- (id)initWithMessageDict:(NSDictionary*)messageDict;
@end
