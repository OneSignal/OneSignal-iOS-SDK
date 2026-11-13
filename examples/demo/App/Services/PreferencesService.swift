/**
 * Modified MIT License
 *
 * Copyright 2024 OneSignal
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

import Foundation

/// `UserDefaults`-backed cache for state the demo restores across cold launches:
/// consent flags, IAM paused, location shared, the last-logged-in external user id,
/// the Identity Verification toggle, and the demo's JWTs. The JWTs are only for the
/// demo's `/users` fetch. The demo never passes them to `login` or `updateUserJwt` on its own.
final class PreferencesService {

    static let shared = PreferencesService()

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let consentRequired = "onesignal.demo.consentRequired"
        static let consentGiven    = "onesignal.demo.consentGiven"
        static let iamPaused       = "onesignal.demo.iamPaused"
        static let locationShared  = "onesignal.demo.locationShared"
        static let externalUserId  = "onesignal.demo.externalUserId"
        static let useIdentityVerification = "onesignal.demo.useIdentityVerification"
        static let jwtTokens = "onesignal.demo.jwtTokens"
        /// The single token the demo kept before `jwtTokens`. Deleted on first read.
        static let legacySessionJwtToken = "onesignal.demo.sessionJwtToken"
        static let language        = "onesignal.demo.language"
    }

    // MARK: - Consent

    func getConsentRequired() -> Bool { defaults.bool(forKey: Key.consentRequired) }
    func setConsentRequired(_ value: Bool) { defaults.set(value, forKey: Key.consentRequired) }

    func getConsentGiven() -> Bool { defaults.bool(forKey: Key.consentGiven) }
    func setConsentGiven(_ value: Bool) { defaults.set(value, forKey: Key.consentGiven) }

    // MARK: - In-App Messages

    func getIamPaused() -> Bool { defaults.bool(forKey: Key.iamPaused) }
    func setIamPaused(_ value: Bool) { defaults.set(value, forKey: Key.iamPaused) }

    // MARK: - Location

    func getLocationShared() -> Bool { defaults.bool(forKey: Key.locationShared) }
    func setLocationShared(_ value: Bool) { defaults.set(value, forKey: Key.locationShared) }

    // MARK: - External user id

    func getExternalUserId() -> String? {
        guard let value = defaults.string(forKey: Key.externalUserId), !value.isEmpty else {
            return nil
        }
        return value
    }

    func setExternalUserId(_ value: String?) {
        if let value = value, !value.isEmpty {
            defaults.set(value, forKey: Key.externalUserId)
        } else {
            defaults.removeObject(forKey: Key.externalUserId)
        }
    }

    // MARK: - Identity Verification (demo REST fetch)

    func getUseIdentityVerification() -> Bool { defaults.bool(forKey: Key.useIdentityVerification) }
    func setUseIdentityVerification(_ value: Bool) { defaults.set(value, forKey: Key.useIdentityVerification) }

    // Every JWT the tester handed the SDK, keyed by external id. Plaintext UserDefaults is fine
    // for a demo and not a pattern for real apps.

    func getJwtToken(externalId: String) -> String? {
        guard let value = jwtTokens()[externalId], !value.isEmpty else {
            return nil
        }
        return value
    }

    func setJwtToken(_ token: String, externalId: String) {
        var tokens = jwtTokens()
        tokens[externalId] = token
        defaults.set(tokens, forKey: Key.jwtTokens)
    }

    func clearJwtTokens() {
        defaults.removeObject(forKey: Key.jwtTokens)
    }

    private func jwtTokens() -> [String: String] {
        defaults.removeObject(forKey: Key.legacySessionJwtToken)
        return defaults.dictionary(forKey: Key.jwtTokens) as? [String: String] ?? [:]
    }

    // MARK: - Language

    func getLanguage() -> String { defaults.string(forKey: Key.language) ?? "" }
    func setLanguage(_ value: String) { defaults.set(value, forKey: Key.language) }
}
