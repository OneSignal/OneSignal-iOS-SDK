/*
 Modified MIT License

 Copyright 2022 OneSignal

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

/**
 This is the user interface exposed to the public.
 */
// TODO: Wrong description above? Not exposed to public.
protocol OSUserInternal {
    var isAnonymous: Bool { get }
    var pushSubscriptionModel: OSSubscriptionModel { get }
    var identityModel: OSIdentityModel { get }
    var propertiesModel: OSPropertiesModel { get }
    func update()
    // Aliases
    func addAliases(_ aliases: [String: String])
    func removeAliases(_ labels: [String])
    // Tags
    func addTags(_ tags: [String: String])
    func removeTags(_ tags: [String])
    // Location
    func setLocation(lat: Float, long: Float)
    // Language
    func setLanguage(_ language: String?)
}

/**
 Internal user object that implements the OSUserInternal protocol.
 */
class OSUserInternalImpl: NSObject, OSUserInternal {

    // TODO: Determine if having any alias should return true
    // Is an anon user who has added aliases, still an anon user?
    var isAnonymous: Bool {
        return identityModel.externalId == nil
    }

    var identityModel: OSIdentityModel
    var propertiesModel: OSPropertiesModel
    var pushSubscriptionModel: OSSubscriptionModel

    // Sessions will be outside this?

    init(identityModel: OSIdentityModel, propertiesModel: OSPropertiesModel, pushSubscriptionModel: OSSubscriptionModel) {
        self.identityModel = identityModel
        self.propertiesModel = propertiesModel
        self.pushSubscriptionModel = pushSubscriptionModel
    }

    func update() {
        self.pushSubscriptionModel.update()
        self.propertiesModel.update()
    }

    // MARK: - Aliases

    /**
     Prohibit the use of `onesignal_id` and `external_id`as alias label.
     Prohibit the setting of aliases to the empty string (users should use `removeAlias` methods instead).
     */
    func addAliases(_ aliases: [String: String]) {
        // Decide if the non-offending aliases should still be added.
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.User addAliases called with: \(aliases)")
        guard aliases[OS_ONESIGNAL_ID] == nil,
              aliases[OS_EXTERNAL_ID] == nil,
              !aliases.values.contains("")
        else {
            // log error
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignal.User addAliases error: Cannot use \(OS_ONESIGNAL_ID) or \(OS_EXTERNAL_ID) as a alias label. Or, cannot use empty string as an alias ID.")
            return
        }
        identityModel.addAliases(aliases)
    }

    /**
     Prohibit the removal of `onesignal_id` and `external_id`.
     */
    func removeAliases(_ labels: [String]) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.User removeAliases called with: \(labels)")
        guard !labels.contains(OS_ONESIGNAL_ID),
              !labels.contains(OS_EXTERNAL_ID)
        else {
            // log error
            OneSignalLog.onesignalLog(.LL_ERROR, message: "OneSignal.User removeAliases error: Cannot use \(OS_ONESIGNAL_ID) or \(OS_EXTERNAL_ID) as a alias label.")
            return
        }
        identityModel.removeAliases(labels)
    }

    // MARK: - Tags

    func addTags(_ tags: [String: String]) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.User addTags called with: \(tags)")
        propertiesModel.addTags(tags)
    }

    func removeTags(_ tags: [String]) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.User removeTags called with: \(tags)")

        propertiesModel.removeTags(tags)
    }

    // MARK: - Location

    func setLocation(lat: Float, long: Float) {
        OneSignalLog.onesignalLog(.LL_VERBOSE, message: "OneSignal.User setLocation called with lat: \(lat) long: \(long)")

        propertiesModel.location = OSLocationPoint(lat: lat, long: long)
    }

    // MARK: - Language

    func setLanguage(_ language: String?) {
        propertiesModel.language = language
    }
}
