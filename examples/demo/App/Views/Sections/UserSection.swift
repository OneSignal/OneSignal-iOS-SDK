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

/// Login/logout + JWT / Identity Verification controls for manual testing.
struct UserSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @EnvironmentObject var toast: ToastPresenter
    @State private var loginOpen = false
    @State private var updateJwtOpen = false

    var body: some View {
        SectionCard(title: "USER", sectionKey: "user") {
            ToggleRow(
                label: "Identity Verification",
                description: "Use external_id for API calls",
                isOn: Binding(
                    get: { viewModel.useIdentityVerification },
                    set: { viewModel.setUseIdentityVerification($0) }
                ),
                accessibilityID: "identity_verification_toggle"
            )

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

            // Shown instead of auto-feeding the stored token, so the SDK's ask is visible.
            if let askedId = viewModel.jwtAskExternalId {
                VStack(alignment: .leading, spacing: OS.Spacing.cardGap) {
                    Text("The SDK is waiting for a JWT. Requests for this user are parked until one is supplied.")
                        .font(OS.Font.bodySmall)
                        .foregroundColor(OS.Color.bodyText)
                    Text(askedId)
                        .font(OS.Font.mono12)
                        .foregroundColor(OS.Color.bodyText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("jwt_ask_external_id_value")
                    ActionButton(
                        "PROVIDE JWT",
                        style: .outline,
                        accessibilityID: "jwt_ask_provide_button"
                    ) {
                        updateJwtOpen = true
                    }
                }
                .osCard(background: OS.Color.warningBackground)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("jwt_ask_banner")
            }

            ActionButton(
                viewModel.loginButtonTitle,
                accessibilityID: "login_user_button"
            ) {
                loginOpen = true
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

            ActionButton(
                "UPDATE USER JWT",
                style: .outline,
                accessibilityID: "update_user_jwt_button"
            ) {
                updateJwtOpen = true
            }
        }
        .osCenteredDialog(isPresented: $loginOpen) {
            LoginUserDialog(
                onLogin: { externalId, jwt in
                    viewModel.login(externalId: externalId, jwtToken: jwt)
                    loginOpen = false
                },
                onCancel: { loginOpen = false }
            )
        }
        .osCenteredDialog(isPresented: $updateJwtOpen) {
            AddItemDialog(
                itemType: .updateUserJwt,
                initialKey: viewModel.jwtAskExternalId ?? viewModel.externalUserId ?? "",
                onAdd: { externalId, token in
                    viewModel.updateUserJwt(externalId: externalId, token: token)
                    updateJwtOpen = false
                },
                onCancel: { updateJwtOpen = false }
            )
        }
        .onChange(of: viewModel.jwtAskExternalId) { askedId in
            if let askedId = askedId {
                toast.show("SDK asked for a JWT for \(askedId)")
            }
        }
    }
}
