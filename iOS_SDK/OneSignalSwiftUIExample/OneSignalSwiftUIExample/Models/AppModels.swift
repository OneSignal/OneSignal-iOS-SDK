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

/// A generic key-value pair used for aliases, tags, and triggers
struct KeyValueItem: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let value: String
}

// MARK: - Notification Type

/// Types of test push notifications that can be sent (matching Android: Simple, With Image, Custom)
enum NotificationType: String, CaseIterable, Identifiable {
    case simple = "Simple Notification"
    case withImage = "Notification With Image"
    case custom = "Custom Notification"

    var id: String { rawValue }
}

// MARK: - In-App Message Type

/// Types of in-app messages that can be displayed
enum InAppMessageType: String, CaseIterable, Identifiable {
    case topBanner = "Top Banner"
    case bottomBanner = "Bottom Banner"
    case centerModal = "Center Modal"
    case fullScreen = "Full Screen"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .topBanner: return "arrow.up.to.line"
        case .bottomBanner: return "arrow.down.to.line"
        case .centerModal: return "square"
        case .fullScreen: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

// MARK: - Add Item Type

/// Types of items that can be added via the add sheet
enum AddItemType {
    case alias
    case email
    case sms
    case tag
    case trigger
    case externalUserId
    case customNotification
    case trackEvent

    var title: String {
        switch self {
        case .alias: return "Add Alias"
        case .email: return "Add Email"
        case .sms: return "Add SMS"
        case .tag: return "Add Tag"
        case .trigger: return "Add Trigger"
        case .externalUserId: return "Login User"
        case .customNotification: return "Custom Notification"
        case .trackEvent: return "Track Event"
        }
    }

    var requiresKeyValue: Bool {
        switch self {
        case .alias, .tag, .trigger, .customNotification: return true
        case .email, .sms, .externalUserId, .trackEvent: return false
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .alias: return "Label"
        case .tag: return "Key"
        case .trigger: return "Key"
        case .customNotification: return "Title"
        default: return "Key"
        }
    }

    var valuePlaceholder: String {
        switch self {
        case .alias: return "ID"
        case .email: return "Email"
        case .sms: return "SMS"
        case .tag: return "Value"
        case .trigger: return "Value"
        case .externalUserId: return "External User Id"
        case .customNotification: return "Body"
        case .trackEvent: return "Event Name"
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .email: return .emailAddress
        case .sms: return .phonePad
        default: return .default
        }
    }
}

// MARK: - Multi-Add Item Type

/// Types for the multi-pair add dialog (Add Aliases, Add Tags, Add Triggers)
enum MultiAddItemType: String {
    case aliases = "Add Multiple Aliases"
    case tags = "Add Multiple Tags"
    case triggers = "Add Multiple Triggers"
}

// MARK: - Remove Multi Item Type

/// Types for the remove-multi checkbox dialog
enum RemoveMultiItemType: String {
    case aliases = "Remove Aliases"
    case tags = "Remove Tags"
    case triggers = "Remove Triggers"
}

// MARK: - User Data

/// Model for user data fetched from the OneSignal REST API
struct UserData {
    let aliases: [String: String]
    let tags: [String: String]
    let emails: [String]
    let smsNumbers: [String]
    let externalId: String?
}

// MARK: - Tooltip Models

/// Tooltip content fetched from the shared sdk-shared repo
struct TooltipData {
    let title: String
    let description: String
    let options: [TooltipOption]?
}

/// An individual option within a tooltip
struct TooltipOption {
    let name: String
    let description: String
}
