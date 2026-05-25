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

/// Login/logout + status display, mirroring the Capacitor UserSection
struct UserSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        SectionCard(title: "USER", sectionKey: "user") {
            ValueCard(rows: [
                ValueCard.Row(
                    label: "Status",
                    value: viewModel.isLoggedIn ? "Logged In" : "Anonymous",
                    valueAccessibilityID: "user_status_value"
                ),
                ValueCard.Row(
                    label: "External ID",
                    value: viewModel.externalUserId ?? "—",
                    valueAccessibilityID: "user_external_id_value",
                    monospaced: true
                )
            ])

            ActionButton(
                viewModel.loginButtonTitle,
                accessibilityID: "login_user_button"
            ) {
                viewModel.showAddDialog(for: .externalUserId)
            }

            if viewModel.isLoggedIn {
                ActionButton(
                    "LOGOUT USER",
                    style: .outline,
                    accessibilityID: "logout_user_button"
                ) {
                    viewModel.logout()
                }
            }
        }
    }
}
