//
//  OSDialogInstanceManager.m
//  OneSignalCore
//
//  Created by Elliot Mawby on 11/2/22.
//  Copyright © 2022 Hiptic. All rights reserved.
//

#import "OSDialogInstanceManager.h"

@implementation OSDialogInstanceManager

static NSObject<OSDialogPresenter> *_sharedInstance;
+ (void)setSharedInstance:(NSObject<OSDialogPresenter> *_Nonnull)instance {
    _sharedInstance = instance;
}

+ (NSObject<OSDialogPresenter> *)sharedInstance {
    return _sharedInstance;
}

@end
