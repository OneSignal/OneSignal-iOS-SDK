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
import UIKit

// MARK: - Key-Value Item

/// Generic key-value pair used for aliases, tags, and triggers
struct KeyValueItem: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let value: String
}

// MARK: - Notification Type

/// Push notification samples that can be sent from the demo
enum NotificationType: String, CaseIterable, Identifiable {
    case simple = "Simple"
    case withImage = "With Image"
    case withSound = "With Sound"

    var id: String { rawValue }
}

// MARK: - In-App Message Type

/// Sample in-app message layouts triggered by the iam_type trigger
enum InAppMessageType: String, CaseIterable, Identifiable {
    case topBanner = "Top Banner"
    case bottomBanner = "Bottom Banner"
    case centerModal = "Center Modal"
    case fullScreen = "Full Screen"

    var id: String { rawValue }

    /// Trigger value the OneSignal IAM rules listen for
    var triggerValue: String {
        switch self {
        case .topBanner: return "top_banner"
        case .bottomBanner: return "bottom_banner"
        case .centerModal: return "center_modal"
        case .fullScreen: return "full_screen"
        }
    }
}

// MARK: - Add Item Type

/// Single-input add dialog flavors
enum AddItemType {
    case alias
    case email
    case sms
    case tag
    case trigger
    case externalUserId

    var title: String {
        switch self {
        case .alias: return "Add Alias"
        case .email: return "Add Email"
        case .sms: return "Add SMS"
        case .tag: return "Add Tag"
        case .trigger: return "Add Trigger"
        case .externalUserId: return "Login User"
        }
    }

    var requiresKeyValue: Bool {
        switch self {
        case .alias, .tag, .trigger: return true
        case .email, .sms, .externalUserId: return false
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .alias: return "Label"
        case .tag, .trigger: return "Key"
        default: return "Key"
        }
    }

    var valuePlaceholder: String {
        switch self {
        case .alias: return "ID"
        case .email: return "Email Address"
        case .sms: return "Phone Number"
        case .tag, .trigger: return "Value"
        case .externalUserId: return "External User Id"
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .email: return .emailAddress
        case .sms: return .phonePad
        default: return .default
        }
    }

    var confirmLabel: String {
        switch self {
        case .externalUserId: return "Login"
        default: return "Add"
        }
    }

    /// Stable accessibility id prefix shared with the rest of the demo
    var accessibilityKey: String {
        switch self {
        case .alias: return "alias"
        case .email: return "email"
        case .sms: return "sms"
        case .tag: return "tag"
        case .trigger: return "trigger"
        case .externalUserId: return "login_user_id"
        }
    }

    /// Accessibility id for the first text field in two-input dialogs.
    /// Mirrors the shared Appium spec naming (`alias_label_input`,
    /// `tag_key_input`, `trigger_key_input`).
    var keyInputID: String {
        switch self {
        case .alias: return "alias_label_input"
        case .tag: return "tag_key_input"
        case .trigger: return "trigger_key_input"
        default: return "\(accessibilityKey)_key_input"
        }
    }

    /// Accessibility id for the second / single text field.
    /// Mirrors the shared Appium spec naming (`alias_id_input`,
    /// `tag_value_input`, `trigger_value_input`, `email_input`,
    /// `sms_input`, `login_user_id_input`).
    var valueInputID: String {
        switch self {
        case .alias: return "alias_id_input"
        case .tag: return "tag_value_input"
        case .trigger: return "trigger_value_input"
        default: return "\(accessibilityKey)_input"
        }
    }

    /// Two-input flavors share `singlepair_*` buttons; single-input flavors
    /// share `singleinput_*` so the Appium suite can find them by a stable id
    /// regardless of the specific item type.
    var confirmButtonID: String {
        requiresKeyValue ? "singlepair_confirm_button" : "singleinput_confirm_button"
    }

    var cancelButtonID: String {
        requiresKeyValue ? "singlepair_cancel_button" : "singleinput_cancel_button"
    }
}

// MARK: - Multi-Add Item Type

/// Multi-pair add dialog flavors (Add Multiple Aliases / Tags / Triggers)
enum MultiAddItemType: String {
    case aliases = "Add Multiple Aliases"
    case tags = "Add Multiple Tags"
    case triggers = "Add Multiple Triggers"

    var keyPlaceholder: String {
        switch self {
        case .aliases: return "Label"
        case .tags, .triggers: return "Key"
        }
    }

    var valuePlaceholder: String {
        switch self {
        case .aliases: return "ID"
        case .tags, .triggers: return "Value"
        }
    }
}

// MARK: - Remove Multi Item Type

/// Multi-select remove dialog flavors
enum RemoveMultiItemType: String {
    case tags = "Remove Tags"
    case triggers = "Remove Triggers"
}

// MARK: - Outcome Mode

/// Variants supported by the Send Outcome dialog
enum OutcomeMode: String, CaseIterable, Identifiable {
    case normal = "Normal Outcome"
    case unique = "Unique Outcome"
    case value = "Outcome with Value"

    var id: String { rawValue }

    var accessibilityKey: String {
        switch self {
        case .normal: return "normal"
        case .unique: return "unique"
        case .value: return "value"
        }
    }
}

// MARK: - Tooltip Models

/// Tooltip content fetched from sdk-shared (or bundled fallback)
struct TooltipData {
    let title: String
    let description: String
    let options: [TooltipOption]?
}

struct TooltipOption {
    let name: String
    let description: String
}

// MARK: - User Data

/// User payload returned from the OneSignal /users API
struct UserData {
    let aliases: [String: String]
    let tags: [String: String]
    let emails: [String]
    let smsNumbers: [String]
    let externalId: String?
}
