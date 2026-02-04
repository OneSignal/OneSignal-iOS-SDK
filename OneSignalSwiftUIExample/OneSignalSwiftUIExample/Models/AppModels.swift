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

// MARK: - Key-Value Item

/// A generic key-value pair used for aliases, tags, and triggers
struct KeyValueItem: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let value: String
}

// MARK: - Notification Type

/// Types of test push notifications that can be sent
enum NotificationType: String, CaseIterable, Identifiable {
    case general = "General"
    case greetings = "Greetings"
    case promotions = "Promotions"
    case breakingNews = "Breaking News"
    case abandonedCart = "Abandoned Cart"
    case newPost = "New Post"
    case reEngagement = "Re-Engagement"
    case rating = "Rating"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .general: return "bell.fill"
        case .greetings: return "hand.wave.fill"
        case .promotions: return "tag.fill"
        case .breakingNews: return "newspaper.fill"
        case .abandonedCart: return "cart.fill"
        case .newPost: return "photo.fill"
        case .reEngagement: return "hand.tap.fill"
        case .rating: return "star.fill"
        }
    }
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
        case .topBanner: return "rectangle.topthird.inset.filled"
        case .bottomBanner: return "rectangle.bottomthird.inset.filled"
        case .centerModal: return "rectangle.center.inset.filled"
        case .fullScreen: return "rectangle.inset.filled"
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
        case .alias: return "Alias Label"
        case .tag: return "Tag Key"
        case .trigger: return "Trigger Key"
        default: return "Key"
        }
    }
    
    var valuePlaceholder: String {
        switch self {
        case .alias: return "Alias ID"
        case .email: return "email@example.com"
        case .sms: return "+1234567890"
        case .tag: return "Tag Value"
        case .trigger: return "Trigger Value"
        case .externalUserId: return "External User ID"
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
