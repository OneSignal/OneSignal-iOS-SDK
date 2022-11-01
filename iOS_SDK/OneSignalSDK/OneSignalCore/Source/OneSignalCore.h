/**
 * Modified MIT License
 *
 * Copyright 2021 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#pragma clang diagnostic ignored "-Wnullability-completeness"
#import <Foundation/Foundation.h>
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"
#import "OSNotification.h"
#import "OSNotification+Internal.h"
#import "OSNotificationClasses.h"
#import "OneSignalLog.h"
#import "NSURL+OneSignal.h"
#import "NSString+OneSignal.h"
#import "OSRequests.h"
#import "OneSignalRequest.h"
#import "OneSignalClient.h"
#import "OneSignalCoreHelper.h"
#import "OneSignalTrackFirebaseAnalytics.h"
#import "OSMacros.h"
#import "OSJSONHandling.h"
#import "OSPrivacyConsentController.h"
// Should these two files be exposed here?
// The only file currently not here that is used outside Core is SwizzlingForwarder
#import "OSDeviceUtils.h"
#import "OSNetworkingUtils.h"

@interface OneSignalCore : NSObject

@end

