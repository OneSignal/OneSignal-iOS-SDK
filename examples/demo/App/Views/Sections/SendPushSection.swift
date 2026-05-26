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

/// Buttons that fire test pushes via the OneSignal REST API
struct SendPushSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var customOpen = false

    var body: some View {
        SectionCard(
            title: "SEND PUSH NOTIFICATION",
            sectionKey: "send_push",
            onInfoTap: { viewModel.showTooltip(for: "sendPushNotification") }
        ) {
            ActionButton("SIMPLE", accessibilityID: "send_simple_button") {
                viewModel.sendNotification(.simple)
            }
            ActionButton("WITH IMAGE", accessibilityID: "send_image_button") {
                viewModel.sendNotification(.withImage)
            }
            ActionButton("WITH SOUND", accessibilityID: "send_sound_button") {
                viewModel.sendNotification(.withSound)
            }
            ActionButton("CUSTOM", accessibilityID: "send_custom_button") {
                customOpen = true
            }
            ActionButton(
                "CLEAR ALL",
                style: .outline,
                accessibilityID: "clear_all_button"
            ) {
                viewModel.clearAllNotifications()
            }
        }
        .osCenteredDialog(isPresented: $customOpen) {
            CustomNotificationDialog(
                onSend: { title, body in
                    viewModel.sendCustomNotification(title: title, body: body)
                    customOpen = false
                },
                onCancel: { customOpen = false }
            )
        }
    }
}
