//
//  OneSignalLifecycleObserver.h
//  OneSignal
//
//  Created by Elliot Mawby on 7/30/20.
//  Copyright © 2020 Hiptic. All rights reserved.
//

@interface OneSignalLifecycleObserver: NSObject

+ (OneSignalLifecycleObserver*) sharedInstance;
+ (void)registerLifecycleObserver;
+ (void)removeObserver;
@end
