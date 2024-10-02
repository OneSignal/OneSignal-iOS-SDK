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

import OneSignalCore
import OneSignalOSCore

extension OneSignalUserManagerImpl: OSLoggable {
    @objc public func logSelf() {
        print("💛 _user: \(String(describing: _user))")
        print(
            """
            💛 identityModel:
                aliases: \(String(describing: _user?.identityModel.aliases))
                jwt: \(String(describing: _user?.identityModel.jwtBearerToken))
                modelId: \(String(describing: _user?.identityModel.modelId))
            """
        )
        print(
            """
            💛 propertiesModel:
                tags: \(String(describing: _user?.propertiesModel.tags))
                language: \(String(describing: _user?.propertiesModel.language))
                modelId: \(String(describing: _user?.propertiesModel.modelId))
            """
        )
        let subscriptionModels = subscriptionModelStore.getModels().values
        for sub in subscriptionModels {
            print(
                """
                💛 subscription model from store
                    addess: \(String(describing: sub.address))
                    subscriptionId: \(String(describing: sub.subscriptionId))
                    enabled: \(sub.enabled)
                    modelId: \(sub.modelId)
                """
            )
        }
        let pushSubModel = pushSubscriptionModelStore.getModel(key: OS_PUSH_SUBSCRIPTION_MODEL_KEY)
        print(
            """
            💛 push sub model from store
                token: \(String(describing: pushSubModel?.address))
                subscriptionId: \(String(describing: pushSubModel?.subscriptionId))
                enabled: \(String(describing: pushSubModel?.enabled))
                notification_types: \(String(describing: pushSubModel?.notificationTypes))
                optedIn: \(String(describing: pushSubModel?.optedIn))
                modelId: \(String(describing: pushSubModel?.modelId))
            """
        )
        operationRepo.logSelf()
        userExecutor?.logSelf()
        identityModelRepo.logSelf()
        print("")
    }
}
