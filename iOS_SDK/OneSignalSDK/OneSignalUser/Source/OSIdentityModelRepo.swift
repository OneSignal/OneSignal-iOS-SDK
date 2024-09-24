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
import OneSignalCore
import OneSignalOSCore

/**
 This class stores all Identity Models that are being used during an app session.
 Its purpose is to manage the instances for all referencing objects.
 The models are built up on each new cold start, so no caching occurs.
 
 When are Identity Models added to this repo?
 1. When the User Manager starts, and the Identity Model is loaded from cache.
 2. When users switch and new Identity Models are created.
 3. Identity Models are added when requests are uncached.
 */
class OSIdentityModelRepo {
    let lock = NSLock()
    var models: [String: OSIdentityModel] = [:]

    func add(model: OSIdentityModel) {
        lock.withLock {
            models[model.modelId] = model
            // listen for changes to model's JWT Token
            model.changeNotifier.subscribe(self, key: OS_IDENTITY_MODEL_REPO)
        }
    }

    func get(modelId: String) -> OSIdentityModel? {
        lock.withLock {
            return models[modelId]
        }
    }

    func get(externalId: String) -> OSIdentityModel? {
        lock.withLock {
            for model in models.values {
                if model.externalId == externalId {
                    return model
                }
            }
            return nil
        }
    }

    /**
     There may be multiple Identity Models with the same external ID, so update them all.
     This can be optimized in the future to re-use an Identity Model if multiple logins are made for the same user.
     */
    func updateJwtToken(externalId: String, token: String) {
        var found = false
        lock.withLock {
            for model in models.values {
                if model.externalId == externalId {
                    model.jwtBearerToken = token
                    found = true
                }
            }
        }
        if !found {
            OneSignalLog.onesignalLog(ONE_S_LOG_LEVEL.LL_ERROR, message: "Update User JWT called for external ID \(externalId) that does not exist")
        }
    }
}

extension OSIdentityModelRepo: OSModelChangedHandler {
    /**
     Listen for updates to the JWT Token and notify the User Manager of this change.
     */
    public func onModelUpdated(args: OSModelChangedArgs, hydrating: Bool) {
        guard
            args.property == OS_JWT_BEARER_TOKEN,
            let model = args.model as? OSIdentityModel,
            let externalId = model.externalId,
            let token = args.newValue as? String,
            token != OS_JWT_TOKEN_INVALID // Don't notify when token is invalidated internally
        else {
            return
        }
        print("❌ OSIdentityModelRepo onModelUpdated for \(externalId): \(token)")
        OneSignalUserManagerImpl.sharedInstance.jwtConfig.onJwtTokenChanged(externalId: externalId, token: token)
    }
}

extension OSIdentityModelRepo: OSLoggable {
    func logSelf() {
        print("OSIdentityModelRepo has the following models: ")
        for model in models.values {
            print("     modelID: \(model.modelId), alises: \(model.aliases) token: \(model.jwtBearerToken ?? "nil")")
        }
    }
}
