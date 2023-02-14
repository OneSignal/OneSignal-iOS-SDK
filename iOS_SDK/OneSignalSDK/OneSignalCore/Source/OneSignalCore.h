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
#import <OneSignalCore/OneSignalUserDefaults.h>
#import <OneSignalCore/OneSignalCommonDefines.h>
#import <OneSignalCore/OSNotification.h>
#import <OneSignalCore/OSNotification+Internal.h>
#import <OneSignalCore/OSNotificationClasses.h>
#import <OneSignalCore/OneSignalLog.h>
#import <OneSignalCore/NSURL+OneSignal.h>
#import <OneSignalCore/NSString+OneSignal.h>
#import <OneSignalCore/NSDateFormatter+OneSignal.h>
#import <OneSignalCore/OSRequests.h>
#import <OneSignalCore/OneSignalRequest.h>
#import <OneSignalCore/OneSignalClient.h>
#import <OneSignalCore/OneSignalCoreHelper.h>
#import <OneSignalCore/OneSignalTrackFirebaseAnalytics.h>
#import <OneSignalCore/OSMacros.h>
#import <OneSignalCore/OSJSONHandling.h>
#import <OneSignalCore/OSPrivacyConsentController.h>
#import <OneSignalCore/OSDeviceUtils.h>
#import <OneSignalCore/OSNetworkingUtils.h>
#import <OneSignalCore/OSObservable.h>
#import <OneSignalCore/OSDialogInstanceManager.h>
#import <OneSignalCore/SwizzlingForwarder.h>
#import <OneSignalCore/OneSignalSelectorHelpers.h>
#import <OneSignalCore/OneSignalConfigManager.h>
#import <OneSignalCore/OSRemoteParamController.h>
#import <OneSignalCore/OneSignalMobileProvision.h>
#import <OneSignalCore/OneSignalWrapper.h>
