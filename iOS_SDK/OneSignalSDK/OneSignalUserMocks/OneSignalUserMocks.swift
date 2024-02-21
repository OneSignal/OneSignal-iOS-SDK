/*
 Modified MIT License
 
 Copyright 2024 OneSignal
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import Foundation
import OneSignalOSCore
@testable import OneSignalUser

@objc
public class OneSignalUserMocks: NSObject {

    // TODO: create mocked server responses to user requests

    public static func reset() {
        resetStaticUserExecutor()
        resetUserManager()
    }

    public static func resetStaticUserExecutor() {
        OSUserExecutor.userRequestQueue.removeAll()
        OSUserExecutor.transferSubscriptionRequestQueue.removeAll()
        OSUserExecutor.identityModels.removeAll()
    }

    /** 
     User Manager needs to reset between tests until we dependency inject the User Manager.
     For example, executors it owns may have cached requests or deltas that would have carried over.
     This is adapting as more data needs to be considered and reset...
     */
    public static func resetUserManager() {
        OneSignalUserManagerImpl.sharedInstance.identityModelStore.clearModelsFromStore()
        OneSignalUserManagerImpl.sharedInstance.propertiesModelStore.clearModelsFromStore()
        OneSignalUserManagerImpl.sharedInstance.subscriptionModelStore.clearModelsFromStore()
        OneSignalUserManagerImpl.sharedInstance.pushSubscriptionModelStore.clearModelsFromStore()

        let propertyExecutor = OSPropertyOperationExecutor()
        let identityExecutor = OSIdentityOperationExecutor()
        let subscriptionExecutor = OSSubscriptionOperationExecutor()

        OneSignalUserManagerImpl.sharedInstance.propertyExecutor = propertyExecutor
        OneSignalUserManagerImpl.sharedInstance.identityExecutor = identityExecutor
        OneSignalUserManagerImpl.sharedInstance.subscriptionExecutor = subscriptionExecutor

        // TODO: Reset Operation Repo first
        // OSCoreMocks.resetOperationRepo()

        OSOperationRepo.sharedInstance.addExecutor(identityExecutor)
        OSOperationRepo.sharedInstance.addExecutor(propertyExecutor)
        OSOperationRepo.sharedInstance.addExecutor(subscriptionExecutor)
    }
}
