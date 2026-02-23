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

/// Section for sending test push notifications (3 full-width buttons)
struct SendPushSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Send Push Notification", tooltipKey: "sendPushNotification")

            SendPushButtons(
                onSimple: {
                    viewModel.sendSimpleNotification()
                },
                onWithImage: {
                    viewModel.sendNotificationWithImage()
                },
                onCustom: {
                    viewModel.showingCustomNotificationSheet = true
                }
            )
        }
    }
}

/// Section for sending test in-app messages (4 full-width buttons with trailing icons)
struct SendInAppSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Send In-App Message", tooltipKey: "sendInAppMessage")

            SendInAppButtons { type in
                viewModel.sendTestInAppMessage(type)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack {
            SendPushSection()
            SendInAppSection()
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environmentObject(OneSignalViewModel())
}
