//
//  Constants.h
//  OneSignal
//
//  Created by Joseph Kalash on 7/5/16.
//  Copyright © 2016 Joseph Kalash. All rights reserved.
//

#ifndef Constants_h
#define Constants_h

typedef NS_ENUM(NSInteger, NotificationType)
{
    Badge = 1,
    Sound = 2,
    Alert = 4,
    All = 7
};

typedef NS_ENUM(NSInteger, ONE_S_LOG_LEVEL)
{
    NONE = 0,
    FATAL = 1,
    ERROR = 2,
    WARN = 3,
    INFO = 4,
    DBG = 5,
    VERBOSE = 6
};

#endif /* Constants_h */
