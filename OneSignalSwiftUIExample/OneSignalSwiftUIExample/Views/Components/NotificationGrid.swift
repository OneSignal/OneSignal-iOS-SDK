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

import SwiftUI

/// A grid of notification type buttons
struct NotificationTypeGrid: View {
    let onSelect: (NotificationType) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(NotificationType.allCases) { type in
                NotificationTypeButton(type: type) {
                    onSelect(type)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// A grid of in-app message type buttons
struct InAppMessageTypeGrid: View {
    let onSelect: (InAppMessageType) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(InAppMessageType.allCases) { type in
                InAppMessageTypeButton(type: type) {
                    onSelect(type)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

/// A button for a notification type with icon and label
struct NotificationTypeButton: View {
    let type: NotificationType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// A button for an in-app message type with icon and label
struct InAppMessageTypeButton: View {
    let type: InAppMessageType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("Send Push Notification")
                .font(.headline)
            NotificationTypeGrid(onSelect: { type in
                print("Selected: \(type.rawValue)")
            })
            
            Text("Send In-App Message")
                .font(.headline)
            InAppMessageTypeGrid(onSelect: { type in
                print("Selected: \(type.rawValue)")
            })
        }
        .padding()
    }
}
