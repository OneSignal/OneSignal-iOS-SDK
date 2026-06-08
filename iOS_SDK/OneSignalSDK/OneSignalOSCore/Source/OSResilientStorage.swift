/*
 Modified MIT License

 Copyright 2026 OneSignal

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

/// File-backed mirror of OneSignal SDK identifiers, written with `NSFileProtectionNone`
/// so it's readable before first unlock, when shared `UserDefaults` reads silently return nil.
///
/// Stored in the App Group container, so it's shared across any targets (main app, NSE, etc.)
/// configured with the same App Group entitlement. Opaque identifiers only: no PII or credentials.
@objc(OSResilientStorage)
public final class OSResilientStorage: NSObject {

    // MARK: - Public key constants

    @objc public static let keyAppId = "app_id"
    @objc public static let keySubscriptionId = "subscription_id"
    /// Needed because the NSE reads this flag from shared UserDefaults while the device may be locked
    /// and the read silently returns the default (NO). Stored as "1" / "0".
    @objc public static let keyReceiveReceiptsEnabled = "receive_receipts_enabled"
    /// Set to `"1"` once `OneSignalUserManagerImpl.start()` has completed at least once on this app
    /// install; cleared on app-id change. Read at startup to distinguish a true fresh install from
    /// a prior session whose UserDefaults isn't readable yet (ie: during iOS prewarm before first unlock).
    @objc public static let keyHasPriorSession = "has_prior_session"

    // MARK: - Internal

    private static let fileName = "onesignal_identity.json"

    /// Serial queue used to serialize all file reads/writes.
    private static let queue = DispatchQueue(label: "com.onesignal.resilient-storage")

    /// Resolve a writable container URL. App Group container is preferred so
    /// the NSE can read the same file. Falls back to the app's private
    /// Application Support directory when no App Group is entitled.
    private static func fileURL() -> URL? {
        let fm = FileManager.default

        let groupName = OneSignalUserDefaults.appGroupName()
        if let container = fm.containerURL(forSecurityApplicationGroupIdentifier: groupName) {
            return container.appendingPathComponent(fileName)
        }

        do {
            let support = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return support.appendingPathComponent(fileName)
        } catch {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSResilientStorage could not resolve a container URL: \(error)")
            return nil
        }
    }

    /// Reads the cache file. Caller is responsible for queue-serialization.
    /// Returns an empty dict if the file is missing or unreadable.
    private static func loadUnsafe() -> [String: String] {
        guard let url = fileURL() else { return [:] }
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }

        do {
            let data = try Data(contentsOf: url)
            if data.isEmpty { return [:] }
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            return (object as? [String: String]) ?? [:]
        } catch {
            OneSignalLog.onesignalLog(.LL_WARN, message: "OSResilientStorage could not read file: \(error)")
            return [:]
        }
    }

    /// Writes the cache file atomically with `.none` file protection.
    /// Caller is responsible for queue-serialization.
    private static func writeUnsafe(_ contents: [String: String]) {
        guard let url = fileURL() else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: contents, options: [])
            try data.write(to: url, options: [.atomic, .noFileProtection])

            // Explicitly re-apply protection class. The atomic write performs a rename which
            // has been observed to reset attributes on some iOS versions.
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.none],
                ofItemAtPath: url.path
            )
        } catch {
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OSResilientStorage write failed: \(error)")
        }
    }

    // MARK: - Public API

    /// Returns the full current contents of the cache. Empty dict if absent.
    @objc public static func snapshot() -> [String: String] {
        return queue.sync { loadUnsafe() }
    }

    /// Reads a single value. Returns nil when missing or unreadable.
    @objc public static func string(forKey key: String) -> String? {
        let dict = snapshot()
        guard let value = dict[key], !value.isEmpty else { return nil }
        return value
    }

    /// Atomically updates a single value. Passing nil or an empty string removes the key.
    @objc public static func setString(_ value: String?, forKey key: String) {
        queue.async {
            var current = loadUnsafe()
            if let value = value, !value.isEmpty {
                current[key] = value
            } else {
                current.removeValue(forKey: key)
            }
            writeUnsafe(current)
        }
    }

    /// Atomically updates multiple values, preserving keys not in `values`.
    /// An empty-string value removes the corresponding key.
    @objc public static func setStrings(_ values: [String: String]) {
        guard !values.isEmpty else { return }
        queue.async {
            var current = loadUnsafe()
            for (key, value) in values {
                if value.isEmpty {
                    current.removeValue(forKey: key)
                } else {
                    current[key] = value
                }
            }
            writeUnsafe(current)
        }
    }
}
