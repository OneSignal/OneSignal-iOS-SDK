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
        }
    }

    func get(modelId: String) -> OSIdentityModel? {
        lock.withLock {
            return models[modelId]
        }
    }

    func get(externalId: String) -> OSIdentityModel? {
        lock.withLock {
            return models.values.first { $0.externalId == externalId }
        }
    }

    /**
     Repeated logins as the same user each create an Identity Model, so update them all.
     This can be optimized in the future to re-use an Identity Model if multiple logins are made for the same user.
     */
    func updateJwtToken(externalId: String, token: String) {
        let matchingModels = modelsMatching(externalId: externalId)
        guard !matchingModels.isEmpty else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityModelRepo.updateJwtToken called for unknown external ID \(externalId)")
            return
        }
        for model in matchingModels {
            model.jwtBearerToken = token
        }
    }

    /**
     Invalidates the token on every Identity Model with this external ID, since repeated logins as the
     same user each create one. Returns `true` if any made the transition, so the app is asked once.
     */
    func invalidateJwtToken(externalId: String) -> Bool {
        let matchingModels = modelsMatching(externalId: externalId)
        guard !matchingModels.isEmpty else {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSIdentityModelRepo.invalidateJwtToken called for unknown external ID \(externalId)")
            return false
        }
        return matchingModels.map { $0.invalidateJwtBearerToken() }.contains(true)
    }

    /// Snapshot before touching the tokens: writing one fires the model's change notifier
    /// synchronously into listeners that take locks of their own.
    private func modelsMatching(externalId: String) -> [OSIdentityModel] {
        lock.withLock {
            models.values.filter { $0.externalId == externalId }
        }
    }
}
