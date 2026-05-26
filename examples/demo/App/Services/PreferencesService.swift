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
/// consent flags, IAM paused, location shared, and the last-logged-in external
/// user id. Mirrors the Capacitor demo's `PreferencesService` so the iOS demo
/// re-feeds these into the SDK during initialization.
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
}
