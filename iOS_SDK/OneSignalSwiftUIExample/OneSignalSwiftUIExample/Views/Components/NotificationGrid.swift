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

/// Three full-width push notification buttons matching the Android layout:
/// SIMPLE NOTIFICATION, NOTIFICATION WITH IMAGE, CUSTOM NOTIFICATION
struct SendPushButtons: View {
    let onSimple: () -> Void
    let onWithImage: () -> Void
    let onCustom: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ActionButton(title: "Simple", action: onSimple)
            ActionButton(title: "With Image", action: onWithImage)
            ActionButton(title: "Custom", action: onCustom)
        }
    }
}

/// Four full-width in-app message buttons with trailing icons matching the Android layout
struct SendInAppButtons: View {
    let onSelect: (InAppMessageType) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(InAppMessageType.allCases) { type in
                ActionButtonWithIcon(
                    title: type.rawValue,
                    iconName: type.iconName
                ) {
                    onSelect(type)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("Send Push Notification")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            SendPushButtons(
                onSimple: { print("Simple") },
                onWithImage: { print("With Image") },
                onCustom: { print("Custom") }
            )

            Text("Send In-App Message")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            SendInAppButtons(onSelect: { type in
                print("Selected: \(type.rawValue)")
            })
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
